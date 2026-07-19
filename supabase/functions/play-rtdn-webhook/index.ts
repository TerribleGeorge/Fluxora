import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type, x-fluxora-webhook-secret',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type ServiceAccount = {
  client_email: string
  private_key: string
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const webhookSecret = Deno.env.get('GOOGLE_PLAY_RTDN_WEBHOOK_SECRET')
  const receivedSecret =
    request.headers.get('x-fluxora-webhook-secret') ??
    new URL(request.url).searchParams.get('token') ??
    ''
  if (!webhookSecret || receivedSecret !== webhookSecret) {
    return json({ error: 'Invalid webhook secret' }, 401)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!supabaseUrl || !serviceRoleKey) {
    return json({ error: 'Supabase service role is not configured' }, 500)
  }

  const event = await request.json().catch(() => null)
  const decoded = decodePubSubEvent(event)
  const subscriptionNotification = decoded?.subscriptionNotification
  const purchaseToken = normalizeString(subscriptionNotification?.purchaseToken)
  const productId = normalizeString(subscriptionNotification?.subscriptionId)

  if (!purchaseToken || !productId) {
    return json({ error: 'Missing subscription notification data' }, 400)
  }

  const packageName = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') ?? 'dev.devvoid.fluxora'
  const serviceAccount = getServiceAccount()
  if (!serviceAccount) {
    return json({ error: 'Google Play verification is not configured' }, 503)
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
    console.error('RTDN verification failed', error)
    return json({ error: 'Unable to verify RTDN with Google Play' }, 502)
  }

  const lineItems = Array.isArray(subscription.lineItems)
    ? (subscription.lineItems as Array<Record<string, unknown>>)
    : []
  const matchingLineItem = lineItems.find(
    (item) => normalizeString(item.productId) === productId,
  )
  if (!matchingLineItem) {
    return json({ error: 'Notification does not match a known product' }, 400)
  }

  const tokenHash = await sha256Hex(purchaseToken)
  const state = String(subscription.subscriptionState ?? '')
  const status = statusForSubscriptionState(state)
  const expiryTime = normalizeString(matchingLineItem.expiryTime)
  const orderId =
    normalizeString(subscription.latestOrderId) ||
    normalizeString(matchingLineItem.latestSuccessfulOrderId)

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })
  const { data: existing, error: lookupError } = await adminClient
    .from('business_subscriptions')
    .select('business_id')
    .eq('provider_purchase_token_hash', tokenHash)
    .maybeSingle()

  if (lookupError) {
    console.error('RTDN lookup failed', lookupError.message)
    return json({ error: 'Unable to find subscription' }, 500)
  }

  if (!existing) {
    return json({ processed: false, reason: 'unknown_purchase_token' })
  }

  const { error: updateError } = await adminClient
    .from('business_subscriptions')
    .update({
      plan: 'pro',
      status,
      provider: 'google_play',
      provider_product_id: productId,
      provider_subscription_id: orderId || productId,
      provider_order_id: orderId || null,
      current_period_ends_at: expiryTime || null,
      last_verified_at: new Date().toISOString(),
    })
    .eq('business_id', existing.business_id)

  if (updateError) {
    console.error('RTDN update failed', updateError.message)
    return json({ error: 'Unable to update subscription' }, 500)
  }

  return json({
    processed: true,
    businessId: existing.business_id,
    status,
    subscriptionState: state,
    currentPeriodEndsAt: expiryTime || null,
  })
})

function decodePubSubEvent(event: unknown) {
  if (!event || typeof event !== 'object') return null
  const message = (event as Record<string, unknown>).message
  if (!message || typeof message !== 'object') return null
  const data = normalizeString((message as Record<string, unknown>).data)
  if (!data) return null
  try {
    const bytes = Uint8Array.from(atob(data), (char) => char.charCodeAt(0))
    return JSON.parse(new TextDecoder().decode(bytes)) as Record<string, unknown>
  } catch {
    return null
  }
}

function statusForSubscriptionState(state: string) {
  if (
    state === 'SUBSCRIPTION_STATE_ACTIVE' ||
    state === 'SUBSCRIPTION_STATE_IN_GRACE_PERIOD'
  ) {
    return 'active'
  }
  if (
    state === 'SUBSCRIPTION_STATE_CANCELED' ||
    state === 'SUBSCRIPTION_STATE_EXPIRED'
  ) {
    return 'cancelled'
  }
  return 'pastDue'
}

function normalizeString(value: unknown) {
  return typeof value === 'string' ? value.trim() : ''
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

async function sha256Hex(value: string) {
  const digest = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(value),
  )
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('')
}

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status, headers: corsHeaders })
}
