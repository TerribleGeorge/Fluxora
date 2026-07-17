import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type AutomationEvent = {
  id: string
  event_type: string
  aggregate_type: string
  aggregate_id: string
  business_id: string
  payload: Record<string, unknown>
  attempts: number
}

type NotificationResult = {
  channel: string
  recipient: string
  status: 'sent' | 'skipped'
  reason?: string
}

type AppointmentPayload = {
  businessName?: string
  professionalName?: string
  professionalPhone?: string
  professionalEmail?: string
  serviceName?: string
  customerName?: string
  customerPhone?: string
  customerEmail?: string
  localDate?: string
  localStartTime?: string
  localEndTime?: string
  publicReference?: string
  reminderMinutesBefore?: number
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
    console.error('process-automation-events missing Supabase env vars')
    return json({ error: 'Server is not configured' }, 500)
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { data, error } = await adminClient
    .from('automation_events')
    .select('*')
    .eq('status', 'pending')
    .lte('available_at', new Date().toISOString())
    .order('created_at', { ascending: true })
    .limit(25)

  if (error) {
    console.error('automation event fetch failed', error.message)
    return json({ error: 'Unable to load events' }, 500)
  }

  const events = (data ?? []) as AutomationEvent[]
  const results: Array<Record<string, unknown>> = []

  for (const event of events) {
    const started = await markProcessing(adminClient, event)
    if (!started) continue

    try {
      const deliveries = await processNotification(event)

      const { error: processedError } = await adminClient
        .from('automation_events')
        .update({
          status: 'processed',
          processed_at: new Date().toISOString(),
          last_error: null,
          payload: {
            ...event.payload,
            deliveryResults: deliveries,
          },
        })
        .eq('id', event.id)

      if (processedError) throw processedError
      results.push({ id: event.id, status: 'processed', deliveries })
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error)
      console.error('automation event failed', event.id, message)
      await adminClient
        .from('automation_events')
        .update({
          status: 'failed',
          last_error: message,
        })
        .eq('id', event.id)
      results.push({ id: event.id, status: 'failed', error: message })
    }
  }

  return json({ processed: results.length, results })
})

async function processNotification(
  event: AutomationEvent,
): Promise<NotificationResult[]> {
  if (event.aggregate_type !== 'appointment') {
    return [{ channel: 'automation', recipient: 'none', status: 'skipped', reason: 'Unsupported aggregate type' }]
  }

  const payload = event.payload as AppointmentPayload
  const results: NotificationResult[] = []

  if (event.event_type === 'appointment.created') {
    results.push(
      await sendProfessionalAppointmentCreated(payload),
    )
    return results
  }

  if (event.event_type === 'appointment.reminder') {
    results.push(await sendCustomerAppointmentReminder(payload, 'whatsapp'))
    results.push(await sendCustomerAppointmentReminder(payload, 'email'))
    return results
  }

  return [{ channel: 'automation', recipient: 'none', status: 'skipped', reason: `No handler for ${event.event_type}` }]
}

async function sendProfessionalAppointmentCreated(
  payload: AppointmentPayload,
): Promise<NotificationResult> {
  const phone = normalizePhone(payload.professionalPhone)
  if (!phone) {
    return {
      channel: 'whatsapp',
      recipient: 'professional',
      status: 'skipped',
      reason: 'Professional phone is empty',
    }
  }

  const message = [
    `Novo agendamento no ${payload.businessName ?? 'Fluxora'}`,
    `Cliente: ${payload.customerName ?? '-'}`,
    `Serviço: ${payload.serviceName ?? '-'}`,
    `Data: ${payload.localDate ?? '-'} às ${payload.localStartTime ?? '-'}`,
  ].join('\n')

  return sendWhatsApp({
    to: phone,
    recipientLabel: 'professional',
    fallbackText: message,
    templateName: Deno.env.get('WHATSAPP_TEMPLATE_APPOINTMENT_CREATED') ?? '',
    templateParameters: [
      payload.professionalName ?? '',
      payload.customerName ?? '',
      payload.serviceName ?? '',
      payload.localDate ?? '',
      payload.localStartTime ?? '',
      payload.businessName ?? '',
    ],
  })
}

async function sendCustomerAppointmentReminder(
  payload: AppointmentPayload,
  channel: 'whatsapp' | 'email',
): Promise<NotificationResult> {
  const minutes = payload.reminderMinutesBefore ?? 30
  const text = [
    `Lembrete do seu atendimento no ${payload.businessName ?? 'estabelecimento'}`,
    `Serviço: ${payload.serviceName ?? '-'}`,
    `Profissional: ${payload.professionalName ?? '-'}`,
    `Hoje às ${payload.localStartTime ?? '-'}`,
    `Referência: ${payload.publicReference ?? '-'}`,
  ].join('\n')

  if (channel === 'whatsapp') {
    const phone = normalizePhone(payload.customerPhone)
    if (!phone) {
      return {
        channel: 'whatsapp',
        recipient: 'customer',
        status: 'skipped',
        reason: 'Customer phone is empty',
      }
    }
    return sendWhatsApp({
      to: phone,
      recipientLabel: 'customer',
      fallbackText: text,
      templateName: Deno.env.get('WHATSAPP_TEMPLATE_APPOINTMENT_REMINDER') ?? '',
      templateParameters: [
        payload.customerName ?? '',
        payload.businessName ?? '',
        payload.serviceName ?? '',
        payload.professionalName ?? '',
        payload.localStartTime ?? '',
        String(minutes),
      ],
    })
  }

  const email = normalizeEmail(payload.customerEmail)
  if (!email) {
    return {
      channel: 'email',
      recipient: 'customer',
      status: 'skipped',
      reason: 'Customer email is empty',
    }
  }

  return sendEmail({
    to: email,
    subject: `Lembrete: atendimento em ${minutes} minutos`,
    text,
  })
}

async function sendWhatsApp({
  to,
  recipientLabel,
  fallbackText,
  templateName,
  templateParameters,
}: {
  to: string
  recipientLabel: string
  fallbackText: string
  templateName: string
  templateParameters: string[]
}): Promise<NotificationResult> {
  const token = Deno.env.get('WHATSAPP_ACCESS_TOKEN')
  const phoneNumberId = Deno.env.get('WHATSAPP_PHONE_NUMBER_ID')
  const languageCode = Deno.env.get('WHATSAPP_TEMPLATE_LANGUAGE') ?? 'pt_BR'
  const apiVersion = Deno.env.get('WHATSAPP_GRAPH_API_VERSION') ?? 'v22.0'
  const allowFreeform = Deno.env.get('WHATSAPP_ALLOW_FREEFORM_TEXT') === 'true'

  if (!token || !phoneNumberId) {
    return {
      channel: 'whatsapp',
      recipient: recipientLabel,
      status: 'skipped',
      reason: 'WhatsApp provider is not configured',
    }
  }

  const body = templateName
    ? {
        messaging_product: 'whatsapp',
        to,
        type: 'template',
        template: {
          name: templateName,
          language: { code: languageCode },
          components: [
            {
              type: 'body',
              parameters: templateParameters.map((value) => ({
                type: 'text',
                text: value || '-',
              })),
            },
          ],
        },
      }
    : allowFreeform
    ? {
        messaging_product: 'whatsapp',
        to,
        type: 'text',
        text: { preview_url: false, body: fallbackText },
      }
    : null

  if (!body) {
    return {
      channel: 'whatsapp',
      recipient: recipientLabel,
      status: 'skipped',
      reason: 'WhatsApp template is not configured',
    }
  }

  const response = await fetch(
    `https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`,
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
    },
  )

  if (!response.ok) {
    throw new Error(`WhatsApp send failed: ${response.status} ${await response.text()}`)
  }

  return { channel: 'whatsapp', recipient: recipientLabel, status: 'sent' }
}

async function sendEmail({
  to,
  subject,
  text,
}: {
  to: string
  subject: string
  text: string
}): Promise<NotificationResult> {
  const apiKey = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('EMAIL_FROM')

  if (!apiKey || !from) {
    return {
      channel: 'email',
      recipient: 'customer',
      status: 'skipped',
      reason: 'Email provider is not configured',
    }
  }

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from, to, subject, text }),
  })

  if (!response.ok) {
    throw new Error(`Email send failed: ${response.status} ${await response.text()}`)
  }

  return { channel: 'email', recipient: 'customer', status: 'sent' }
}

async function markProcessing(
  adminClient: ReturnType<typeof createClient>,
  event: AutomationEvent,
) {
  const { error } = await adminClient
    .from('automation_events')
    .update({
      status: 'processing',
      attempts: event.attempts + 1,
    })
    .eq('id', event.id)
    .eq('status', 'pending')

  return !error
}

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status, headers: corsHeaders })
}

function normalizePhone(value: unknown) {
  const digits = String(value ?? '').replace(/\D/g, '')
  if (digits.length < 10) return ''
  return digits.startsWith('55') ? digits : `55${digits}`
}

function normalizeEmail(value: unknown) {
  const email = String(value ?? '').trim().toLowerCase()
  return email.includes('@') ? email : ''
}
