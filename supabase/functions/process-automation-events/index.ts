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
  providerMessageId?: string
  providerResponse?: unknown
}

type AppointmentPayload = {
  businessName?: string
  professionalName?: string
  professionalPhone?: string
  professionalEmail?: string
  serviceName?: string
  servicePrice?: number
  customerName?: string
  customerPhone?: string
  customerEmail?: string
  startsAt?: string
  endsAt?: string
  localStartsAt?: string
  localEndsAt?: string
  localDate?: string
  localStartTime?: string
  localEndTime?: string
  timeZone?: string
  publicReference?: string
  reminderMinutesBefore?: number
  ownerContacts?: Array<{ name?: string; email?: string }>
}

type ProductPayload = {
  businessName?: string
  businessPhone?: string
  productName?: string
  category?: string
  movementType?: string
  quantity?: number
  unitCost?: number
  stockQuantity?: number
  minStockQuantity?: number
  salePrice?: number
  stockCostValue?: number
  stockSaleValue?: number
  notes?: string
  inventorySummary?: {
    activeProducts?: number
    lowStockProducts?: number
    stockCostValue?: number
    stockSaleValue?: number
    monthProductRevenue?: number
    monthProductCost?: number
    monthProductProfit?: number
  }
  ownerContacts?: Array<{ name?: string; email?: string }>
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
  if (event.aggregate_type === 'product') {
    return processProductNotification(event)
  }

  if (event.aggregate_type !== 'appointment') {
    return [
      {
        channel: 'automation',
        recipient: 'none',
        status: 'skipped',
        reason: 'Unsupported aggregate type',
      },
    ]
  }

  const payload = event.payload as AppointmentPayload
  const results: NotificationResult[] = []

  if (event.event_type === 'appointment.created') {
    results.push(await sendProfessionalAppointmentCreated(payload))
    results.push(await sendProfessionalAppointmentCreatedEmail(payload))
    results.push(...await sendOwnerAppointmentCreatedEmails(payload))
    return results
  }

  if (event.event_type === 'appointment.reminder') {
    results.push(await sendCustomerAppointmentReminder(payload, 'whatsapp'))
    results.push(await sendCustomerAppointmentReminder(payload, 'email'))
    return results
  }

  return [
    {
      channel: 'automation',
      recipient: 'none',
      status: 'skipped',
      reason: `No handler for ${event.event_type}`,
    },
  ]
}

async function processProductNotification(
  event: AutomationEvent,
): Promise<NotificationResult[]> {
  const payload = event.payload as ProductPayload
  if (event.event_type === 'product.low_stock') {
    return sendOwnerProductEmail({
      payload,
      subject: `Alerta de estoque baixo: ${payload.productName ?? 'produto'}`,
      text: [
        `O produto ${payload.productName ?? '-'} está acabando.`,
        `Estoque atual: ${payload.stockQuantity ?? 0}`,
        `Estoque mínimo: ${payload.minStockQuantity ?? 0}`,
        `Estabelecimento: ${payload.businessName ?? '-'}`,
        '',
        productSummaryText(payload),
      ].join('\n'),
    })
  }

  if (event.event_type === 'product.stock_movement') {
    return sendOwnerProductEmail({
      payload,
      subject: `Movimento de estoque: ${payload.productName ?? 'produto'}`,
      text: [
        `Produto: ${payload.productName ?? '-'}`,
        `Tipo: ${payload.movementType ?? '-'}`,
        `Quantidade: ${payload.quantity ?? 0}`,
        `Estoque atual: ${payload.stockQuantity ?? 0}`,
        `Valor em custo no estoque: ${formatMoney(payload.stockCostValue ?? 0)}`,
        `Valor potencial de venda: ${formatMoney(payload.stockSaleValue ?? 0)}`,
        `Observação: ${payload.notes ?? '-'}`,
        '',
        productSummaryText(payload),
      ].join('\n'),
    })
  }

  return [
    {
      channel: 'automation',
      recipient: 'none',
      status: 'skipped',
      reason: `No handler for ${event.event_type}`,
    },
  ]
}

async function sendOwnerProductEmail({
  payload,
  subject,
  text,
}: {
  payload: ProductPayload
  subject: string
  text: string
}): Promise<NotificationResult[]> {
  const owners = Array.isArray(payload.ownerContacts)
    ? payload.ownerContacts
    : []
  const emails = owners
    .map((owner) => normalizeEmail(owner.email))
    .filter((email) => email.length > 0)

  if (emails.length === 0) {
    return [
      {
        channel: 'email',
        recipient: 'owner',
        status: 'skipped',
        reason: 'Owner email is empty',
      },
    ]
  }

  const results: NotificationResult[] = []
  for (const email of emails) {
    results.push(await sendEmail({ to: email, subject, text, recipientLabel: 'owner' }))
  }
  return results
}

async function sendProfessionalAppointmentCreated(
  payload: AppointmentPayload,
): Promise<NotificationResult> {
  if (!whatsAppNotificationsEnabled()) {
    return {
      channel: 'whatsapp',
      recipient: 'professional',
      status: 'skipped',
      reason: 'WhatsApp notifications are disabled',
    }
  }

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

async function sendProfessionalAppointmentCreatedEmail(
  payload: AppointmentPayload,
): Promise<NotificationResult> {
  const email = normalizeEmail(payload.professionalEmail)
  if (!email) {
    return {
      channel: 'email',
      recipient: 'professional',
      status: 'skipped',
      reason: 'Professional email is empty',
    }
  }

  const text = [
    `Novo agendamento no ${payload.businessName ?? 'Fluxora'}`,
    '',
    `Cliente: ${payload.customerName ?? '-'}`,
    `Serviço: ${payload.serviceName ?? '-'}`,
    `Data: ${payload.localDate ?? '-'} às ${payload.localStartTime ?? '-'}`,
    `Referência: ${payload.publicReference ?? '-'}`,
    '',
    'Anexamos um convite de calendário para você adicionar este atendimento à sua agenda.',
  ].join('\n')

  return sendEmail({
    to: email,
    subject: `Novo agendamento: ${payload.serviceName ?? 'atendimento'}`,
    text,
    recipientLabel: 'professional',
    calendar: buildAppointmentCalendarInvite(payload, 'professional'),
  })
}

async function sendOwnerAppointmentCreatedEmails(
  payload: AppointmentPayload,
): Promise<NotificationResult[]> {
  const emails = (payload.ownerContacts ?? [])
    .map((contact) => normalizeEmail(contact.email))
    .filter((email) => email.length > 0)

  if (emails.length === 0) {
    return [
      {
        channel: 'email',
        recipient: 'owner',
        status: 'skipped',
        reason: 'Owner email is empty',
      },
    ]
  }

  const text = [
    `Novo agendamento no ${payload.businessName ?? 'Fluxora'}`,
    '',
    `Cliente: ${payload.customerName ?? '-'}`,
    `Profissional: ${payload.professionalName ?? '-'}`,
    `Serviço: ${payload.serviceName ?? '-'}`,
    `Data: ${payload.localDate ?? '-'} às ${payload.localStartTime ?? '-'}`,
    `Valor do serviço: ${formatMoney(payload.servicePrice ?? 0)}`,
    `Referência: ${payload.publicReference ?? '-'}`,
  ].join('\n')

  const results: NotificationResult[] = []
  for (const email of emails) {
    results.push(
      await sendEmail({
        to: email,
        subject: `Novo agendamento: ${payload.serviceName ?? 'atendimento'}`,
        text,
        recipientLabel: 'owner',
        calendar: buildAppointmentCalendarInvite(payload, 'owner'),
      }),
    )
  }

  return results
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
    if (!whatsAppNotificationsEnabled()) {
      return {
        channel: 'whatsapp',
        recipient: 'customer',
        status: 'skipped',
        reason: 'WhatsApp notifications are disabled',
      }
    }

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
    recipientLabel: 'customer',
    calendar: buildAppointmentCalendarInvite(payload, 'customer'),
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

  const responseBody = await response.json().catch(async () => ({
    raw: await response.text(),
  }))

  if (!response.ok) {
    throw new Error(
      `WhatsApp send failed: ${response.status} ${JSON.stringify(responseBody)}`,
    )
  }

  const messageId =
    Array.isArray(responseBody?.messages) && responseBody.messages.length > 0
      ? responseBody.messages[0]?.id
      : undefined

  return {
    channel: 'whatsapp',
    recipient: recipientLabel,
    status: 'sent',
    providerMessageId: typeof messageId === 'string' ? messageId : undefined,
    providerResponse: responseBody,
  }
}

async function sendEmail({
  to,
  subject,
  text,
  recipientLabel = 'recipient',
  calendar,
}: {
  to: string
  subject: string
  text: string
  recipientLabel?: string
  calendar?: CalendarInvite | null
}): Promise<NotificationResult> {
  const apiKey = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('EMAIL_FROM')

  if (!apiKey || !from) {
    return {
      channel: 'email',
      recipient: recipientLabel,
      status: 'skipped',
      reason: 'Email provider is not configured',
    }
  }

  const attachments = calendar
    ? [
        {
          filename: calendar.filename,
          content: base64Encode(calendar.content),
        },
      ]
    : undefined

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ from, to, subject, text, attachments }),
  })

  const responseBody = await response.json().catch(async () => ({
    raw: await response.text(),
  }))

  if (!response.ok) {
    throw new Error(`Email send failed: ${response.status} ${JSON.stringify(responseBody)}`)
  }

  return {
    channel: 'email',
    recipient: recipientLabel,
    status: 'sent',
    providerResponse: responseBody,
  }
}

type CalendarInvite = {
  filename: string
  content: string
}

function buildAppointmentCalendarInvite(
  payload: AppointmentPayload,
  recipient: 'customer' | 'professional' | 'owner',
): CalendarInvite | null {
  const startsAt = parseDate(payload.startsAt)
  const endsAt = parseDate(payload.endsAt)
  if (!startsAt || !endsAt) return null

  const summary =
    recipient === 'customer'
      ? `Atendimento: ${payload.serviceName ?? 'Fluxora'}`
      : `Fluxora: ${payload.customerName ?? 'cliente'} - ${payload.serviceName ?? 'atendimento'}`

  const description = [
    `Estabelecimento: ${payload.businessName ?? '-'}`,
    `Cliente: ${payload.customerName ?? '-'}`,
    `Profissional: ${payload.professionalName ?? '-'}`,
    `Serviço: ${payload.serviceName ?? '-'}`,
    `Data local: ${payload.localDate ?? '-'} ${payload.localStartTime ?? '-'}`,
    `Referência: ${payload.publicReference ?? '-'}`,
  ].join('\\n')

  const uid = `${payload.publicReference || crypto.randomUUID()}@fluxora.devvoid.dev`
  const content = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//DevVoid.dev//Fluxora//PT-BR',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    `UID:${escapeIcs(uid)}`,
    `DTSTAMP:${formatIcsDate(new Date())}`,
    `DTSTART:${formatIcsDate(startsAt)}`,
    `DTEND:${formatIcsDate(endsAt)}`,
    `SUMMARY:${escapeIcs(summary)}`,
    `DESCRIPTION:${escapeIcs(description)}`,
    `LOCATION:${escapeIcs(payload.businessName ?? 'Fluxora')}`,
    'BEGIN:VALARM',
    'TRIGGER:-PT30M',
    'ACTION:DISPLAY',
    `DESCRIPTION:${escapeIcs(`Lembrete: ${summary}`)}`,
    'END:VALARM',
    'END:VEVENT',
    'END:VCALENDAR',
    '',
  ].join('\r\n')

  return {
    filename: `fluxora-agendamento-${payload.publicReference || 'atendimento'}.ics`,
    content,
  }
}

function parseDate(value: unknown) {
  if (typeof value !== 'string' || !value.trim()) return null
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? null : date
}

function formatIcsDate(date: Date) {
  return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z')
}

function escapeIcs(value: string) {
  return value
    .replace(/\\/g, '\\\\')
    .replace(/\n/g, '\\n')
    .replace(/;/g, '\\;')
    .replace(/,/g, '\\,')
}

function base64Encode(value: string) {
  const bytes = new TextEncoder().encode(value)
  let binary = ''
  for (const byte of bytes) {
    binary += String.fromCharCode(byte)
  }
  return btoa(binary)
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

function whatsAppNotificationsEnabled() {
  return Deno.env.get('WHATSAPP_NOTIFICATIONS_ENABLED') === 'true'
}

function normalizeEmail(value: unknown) {
  const email = String(value ?? '').trim().toLowerCase()
  return email.includes('@') ? email : ''
}

function formatMoney(value: number) {
  return new Intl.NumberFormat('pt-BR', {
    style: 'currency',
    currency: 'BRL',
  }).format(value)
}

function productSummaryText(payload: ProductPayload) {
  const summary = payload.inventorySummary
  if (!summary) return 'Resumo do estoque indisponível.'
  return [
    'Resumo em tempo real:',
    `Produtos ativos: ${summary.activeProducts ?? 0}`,
    `Produtos em alerta: ${summary.lowStockProducts ?? 0}`,
    `Valor em custo no estoque: ${formatMoney(summary.stockCostValue ?? 0)}`,
    `Valor potencial de venda: ${formatMoney(summary.stockSaleValue ?? 0)}`,
    `Receita de produtos no mês: ${formatMoney(summary.monthProductRevenue ?? 0)}`,
    `Custo dos produtos vendidos no mês: ${formatMoney(summary.monthProductCost ?? 0)}`,
    `Lucro bruto de produtos no mês: ${formatMoney(summary.monthProductProfit ?? 0)}`,
  ].join('\n')
}
