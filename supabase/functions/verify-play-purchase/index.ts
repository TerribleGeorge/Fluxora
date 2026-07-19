import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type ServiceAccount = {
  client_email: string
  private_key: string
}

type VerifyBody = {
  businessId?: string
  productId?: string
  purchaseToken?: string
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase service role is not configured' }, 500)
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const jwt = getBearerToken(request)
  if (!jwt) return json({ error: 'Missing authorization token' }, 401)

  const { data: userData, error: userError } = await adminClient.auth.getUser(jwt)
  if (userError || !userData.user) {
    return json({ error: 'Invalid authorization token' }, 401)
  }

  const body = (await request.json().catch(() => ({}))) as VerifyBody
  const businessId = normalizeString(body.businessId)
  const productId = normalizeString(body.productId)
  const purchaseToken = normalizeString(body.purchaseToken)

  if (!businessId || !productId || !purchaseToken) {
    return json({ error: 'businessId, productId and purchaseToken are required' }, 400)
  }

  const { data: membership, error: membershipError } = await adminClient
    .from('memberships')
    .select('role, active')
    .eq('business_id', businessId)
    .eq('user_id', userData.user.id)
    .eq('active', true)
    .maybeSingle()

  if (membershipError) {
    console.error('membership lookup failed', membershipError.message)
    return json({ error: 'Unable to validate business access' }, 500)
  }

  if (!membership || !['owner', 'manager'].includes(String(membership.role))) {
    return json({ error: 'Only owners and managers can verify purchases' }, 403)
  }

  const allowedProducts = parseCsvEnv('GOOGLE_PLAY_ALLOWED_PRODUCT_IDS')
  if (allowedProducts.length > 0 && !allowedProducts.includes(productId)) {
    return json({ error: 'Product is not allowed for this app' }, 400)
  }

  const packageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') ?? 'dev.devvoid.fluxora'
  const serviceAccount = getServiceAccount()
  if (!serviceAccount) {
    return json(
      {
        error: 'Google Play verification is not configured',
        requiredSecrets: [
          'GOOGLE_PLAY_SERVICE_ACCOUNT_JSON',
          'or GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL + GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY',
        ],
      },
      503,
    )
  }

  let subscription: Record<string, unknown>
  try {
    const accessToken = await createGoogleAccessToken(serviceAccount)
    subscription = await fetchSubscription({
      accessToken,
      packageName,
      purchaseToken,
    })
  } catch (error) {
    console.error('Google Play verification failed', error)
    return json({ error: 'Unable to verify purchase with Google Play' }, 502)
  }

  const lineItems = Array.isArray(subscription.lineItems)
    ? (subscription.lineItems as Array<Record<string, unknown>>)
    : []
  const matchingLineItem = lineItems.find(
    (item) => normalizeString(item.productId) === productId,
  )
  if (!matchingLineItem) {
    return json({ error: 'Purchase token does not belong to this product' }, 400)
  }

  const state = String(subscription.subscriptionState ?? '')
  const hasAccess = [
    'SUBSCRIPTION_STATE_ACTIVE',
    'SUBSCRIPTION_STATE_IN_GRACE_PERIOD',
  ].includes(state)

  const expiryTime = normalizeString(matchingLineItem.expiryTime)
  const orderId =
    normalizeString(subscription.latestOrderId) ||
    normalizeString(matchingLineItem.latestSuccessfulOrderId)

  const update = {
    plan: 'pro',
    status: hasAccess ? 'active' : 'pastDue',
    provider: 'google_play',
    provider_product_id: productId,
    provider_subscription_id: orderId || productId,
    provider_order_id: orderId || null,
    current_period_ends_at: expiryTime || null,
    last_verified_at: new Date().toISOString(),
  }

  const { error: updateError } = await adminClient
    .from('business_subscriptions')
    .update(update)
    .eq('business_id', businessId)

  if (updateError) {
    console.error('subscription update failed', updateError.message)
    return json({ error: 'Unable to update subscription' }, 500)
  }

  return json({
    verified: true,
    hasAccess,
    subscriptionState: state,
    productId,
    currentPeriodEndsAt: expiryTime || null,
  })
})

function getBearerToken(request: Request) {
  const authorization = request.headers.get('authorization') ?? ''
  const match = authorization.match(/^Bearer\s+(.+)$/i)
  return match?.[1] ?? ''
}

function normalizeString(value: unknown) {
  return typeof value === 'string' ? value.trim() : ''
}

function parseCsvEnv(name: string) {
  return (Deno.env.get(name) ?? '')
    .split(',')
    .map((value) => value.trim())
    .filter((value) => value.length > 0)
}

function getServiceAccount(): ServiceAccount | null {
  const rawJson = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON')
  if (rawJson) {
    try {
      const parsed = JSON.parse(rawJson) as Partial<ServiceAccount>
      if (parsed.client_email && parsed.private_key) {
        return {
          client_email: parsed.client_email,
          private_key: parsed.private_key,
        }
      }
    } catch {
      return null
    }
  }

  const clientEmail = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_EMAIL')
  const privateKey = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_PRIVATE_KEY')
  if (!clientEmail || !privateKey) return null
  return {
    client_email: clientEmail,
    private_key: privateKey.replace(/\\n/g, '\n'),
  }
}

async function createGoogleAccessToken(serviceAccount: ServiceAccount) {
  const now = Math.floor(Date.now() / 1000)
  const assertion = await signJwt(
    {
      alg: 'RS256',
      typ: 'JWT',
    },
    {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    serviceAccount.private_key,
  )

  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  })

  const body = await response.json()
  if (!response.ok) {
    throw new Error(`Google OAuth failed: ${response.status} ${JSON.stringify(body)}`)
  }

  const accessToken = normalizeString(body.access_token)
  if (!accessToken) throw new Error('Google OAuth did not return an access token')
  return accessToken
}

async function fetchSubscription({
  accessToken,
  packageName,
  purchaseToken,
}: {
  accessToken: string
  packageName: string
  purchaseToken: string
}) {
  const url =
    `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${encodeURIComponent(packageName)}/purchases/subscriptionsv2/tokens/` +
    encodeURIComponent(purchaseToken)

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${accessToken}` },
  })
  const body = await response.json()
  if (!response.ok) {
    throw new Error(
      `Google Play subscription verification failed: ${response.status} ${JSON.stringify(body)}`,
    )
  }
  return body
}

async function signJwt(
  header: Record<string, unknown>,
  payload: Record<string, unknown>,
  pemPrivateKey: string,
) {
  const unsigned = `${base64UrlEncodeJson(header)}.${base64UrlEncodeJson(payload)}`
  const key = await importPrivateKey(pemPrivateKey)
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  )
  return `${unsigned}.${base64UrlEncodeBytes(new Uint8Array(signature))}`
}

async function importPrivateKey(pemPrivateKey: string) {
  const base64 = pemPrivateKey
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  const binary = Uint8Array.from(atob(base64), (char) => char.charCodeAt(0))
  return crypto.subtle.importKey(
    'pkcs8',
    binary,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  )
}

function base64UrlEncodeJson(value: Record<string, unknown>) {
  return base64UrlEncodeBytes(new TextEncoder().encode(JSON.stringify(value)))
}

function base64UrlEncodeBytes(bytes: Uint8Array) {
  let binary = ''
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '')
}

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status, headers: corsHeaders })
}
