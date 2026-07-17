import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
}

type WebhookEvent = {
  event_kind: string
  message_id?: string
  phone_number_id?: string
  wa_id?: string
  status?: string
  payload: Record<string, unknown>
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method === 'GET') {
    return verifyWebhook(request)
  }

  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('whatsapp-webhook missing Supabase env vars')
    return json({ error: 'Server is not configured' }, 500)
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const body = await request.json().catch(() => null)
  if (!body || typeof body !== 'object') {
    return json({ error: 'Invalid payload' }, 400)
  }

  const events = extractWebhookEvents(body as Record<string, unknown>)
  const rows = events.length > 0
    ? events
    : [
        {
          event_kind: 'raw',
          payload: body as Record<string, unknown>,
        },
      ]

  const { error } = await adminClient.from('whatsapp_webhook_events').insert(rows)

  if (error) {
    console.error('whatsapp webhook log insert failed', error.message)
    return json({ error: 'Unable to log webhook' }, 500)
  }

  return json({ received: true, events: rows.length })
})

function verifyWebhook(request: Request) {
  const url = new URL(request.url)
  const mode = url.searchParams.get('hub.mode')
  const token = url.searchParams.get('hub.verify_token')
  const challenge = url.searchParams.get('hub.challenge')
  const expectedToken = Deno.env.get('WHATSAPP_WEBHOOK_VERIFY_TOKEN')

  if (!expectedToken) {
    console.error('WHATSAPP_WEBHOOK_VERIFY_TOKEN is not configured')
    return new Response('Webhook verify token is not configured', {
      status: 500,
      headers: corsHeaders,
    })
  }

  if (mode === 'subscribe' && token === expectedToken && challenge) {
    return new Response(challenge, {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'text/plain' },
    })
  }

  return new Response('Forbidden', { status: 403, headers: corsHeaders })
}

function extractWebhookEvents(payload: Record<string, unknown>): WebhookEvent[] {
  const events: WebhookEvent[] = []
  const entries = Array.isArray(payload.entry) ? payload.entry : []

  for (const entry of entries) {
    if (!entry || typeof entry !== 'object') continue
    const changes = Array.isArray((entry as Record<string, unknown>).changes)
      ? ((entry as Record<string, unknown>).changes as unknown[])
      : []

    for (const change of changes) {
      if (!change || typeof change !== 'object') continue
      const value = (change as Record<string, unknown>).value
      if (!value || typeof value !== 'object') continue

      const valueRecord = value as Record<string, unknown>
      const metadata = valueRecord.metadata && typeof valueRecord.metadata === 'object'
        ? (valueRecord.metadata as Record<string, unknown>)
        : {}
      const phoneNumberId = stringOrUndefined(metadata.phone_number_id)

      const statuses = Array.isArray(valueRecord.statuses)
        ? valueRecord.statuses
        : []
      for (const status of statuses) {
        if (!status || typeof status !== 'object') continue
        const statusRecord = status as Record<string, unknown>
        events.push({
          event_kind: 'message_status',
          message_id: stringOrUndefined(statusRecord.id),
          phone_number_id: phoneNumberId,
          wa_id: stringOrUndefined(statusRecord.recipient_id),
          status: stringOrUndefined(statusRecord.status),
          payload: statusRecord,
        })
      }

      const messages = Array.isArray(valueRecord.messages)
        ? valueRecord.messages
        : []
      for (const message of messages) {
        if (!message || typeof message !== 'object') continue
        const messageRecord = message as Record<string, unknown>
        events.push({
          event_kind: 'incoming_message',
          message_id: stringOrUndefined(messageRecord.id),
          phone_number_id: phoneNumberId,
          wa_id: stringOrUndefined(messageRecord.from),
          payload: messageRecord,
        })
      }
    }
  }

  return events
}

function stringOrUndefined(value: unknown) {
  return typeof value === 'string' && value.trim() ? value : undefined
}

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status, headers: corsHeaders })
}
