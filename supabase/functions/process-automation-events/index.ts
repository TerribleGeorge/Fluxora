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
      // Free first step: keep the event pipeline internal to Supabase.
      // WhatsApp/e-mail providers can be attached here later without changing
      // the app or database trigger contract.
      console.log('automation event processed', {
        id: event.id,
        type: event.event_type,
        aggregate: event.aggregate_type,
        aggregateId: event.aggregate_id,
        businessId: event.business_id,
      })

      const { error: processedError } = await adminClient
        .from('automation_events')
        .update({
          status: 'processed',
          processed_at: new Date().toISOString(),
          last_error: null,
        })
        .eq('id', event.id)

      if (processedError) throw processedError
      results.push({ id: event.id, status: 'processed' })
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
