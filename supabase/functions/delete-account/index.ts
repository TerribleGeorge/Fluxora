import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  if (request.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405)
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const publishableKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')

  if (!supabaseUrl || !publishableKey || !serviceRoleKey) {
    console.error('delete-account missing Supabase environment variables')
    return json({ error: 'Server is not configured' }, 500)
  }

  const authorization = request.headers.get('Authorization')
  if (!authorization) {
    return json({ error: 'Unauthorized' }, 401)
  }

  const userClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
  })

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser()

  if (userError || !user) {
    console.error('delete-account auth validation failed', userError?.message)
    return json({ error: 'Unauthorized' }, 401)
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const { error: businessError } = await adminClient
    .from('businesses')
    .delete()
    .eq('created_by', user.id)

  if (businessError) {
    console.error(
      'delete-account business cleanup failed',
      businessError.message,
    )
    return json({ error: 'Unable to delete business data' }, 500)
  }

  const { error: deleteUserError } =
    await adminClient.auth.admin.deleteUser(user.id)

  if (deleteUserError) {
    console.error('delete-account failed', deleteUserError.message)
    return json({ error: 'Unable to delete account' }, 500)
  }

  return json({ deleted: true })
})

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status, headers: corsHeaders })
}
