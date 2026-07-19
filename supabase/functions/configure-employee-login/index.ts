import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

type ConfigureEmployeeLoginBody = {
  businessId?: string
  professionalId?: string
  loginName?: string
  password?: string
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
    return json({ error: 'Server is not configured' }, 500)
  }

  const authorization = request.headers.get('Authorization')
  if (!authorization) return json({ error: 'Unauthorized' }, 401)

  const userClient = createClient(supabaseUrl, publishableKey, {
    global: { headers: { Authorization: authorization } },
  })
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  const {
    data: { user },
    error: userError,
  } = await userClient.auth.getUser()
  if (userError || !user) return json({ error: 'Unauthorized' }, 401)

  const body = (await request.json().catch(() => ({}))) as ConfigureEmployeeLoginBody
  const businessId = normalizeString(body.businessId)
  const professionalId = normalizeString(body.professionalId)
  const loginName = normalizeString(body.loginName)
  const password = typeof body.password === 'string' ? body.password : ''

  if (!businessId || !professionalId || loginName.length < 2) {
    return json({ error: 'businessId, professionalId and loginName are required' }, 400)
  }

  const { data: membership, error: membershipError } = await adminClient
    .from('memberships')
    .select('role, active')
    .eq('business_id', businessId)
    .eq('user_id', user.id)
    .eq('active', true)
    .maybeSingle()

  if (membershipError) {
    console.error('configure-employee-login membership failed', membershipError.message)
    return json({ error: 'Unable to validate business access' }, 500)
  }
  if (!membership || !['owner', 'manager'].includes(String(membership.role))) {
    return json({ error: 'Only owners and managers can configure employee login' }, 403)
  }

  const { data: professional, error: professionalError } = await adminClient
    .from('professionals')
    .select('id, business_id, user_id, name, email, login_email')
    .eq('business_id', businessId)
    .eq('id', professionalId)
    .maybeSingle()

  if (professionalError) {
    console.error('configure-employee-login professional lookup failed', professionalError.message)
    return json({ error: 'Unable to load professional' }, 500)
  }
  if (!professional) return json({ error: 'Professional not found' }, 404)

  const loginEmail =
    normalizeString(professional.login_email) ||
    `employee-${professionalId}@auth.fluxora.dev`
  const existingUserId = normalizeString(professional.user_id)

  if (existingUserId && !normalizeString(professional.login_email)) {
    return json(
      {
        error:
          'This professional is already linked to a regular user. Remove that link before creating an employee login.',
      },
      409,
    )
  }

  if (!existingUserId && password.length < 8) {
    return json({ error: 'Password must have at least 8 characters' }, 400)
  }

  let employeeUserId = existingUserId
  if (employeeUserId) {
    const attributes: Record<string, unknown> = {
      user_metadata: {
        name: loginName,
        role: 'professional',
        businessId,
        professionalId,
      },
    }
    if (password.trim().length > 0) {
      if (password.length < 8) {
        return json({ error: 'Password must have at least 8 characters' }, 400)
      }
      attributes.password = password
    }
    const { error: updateUserError } =
      await adminClient.auth.admin.updateUserById(employeeUserId, attributes)
    if (updateUserError) {
      console.error('configure-employee-login update user failed', updateUserError.message)
      return json({ error: 'Unable to update employee user' }, 500)
    }
  } else {
    const { data: created, error: createUserError } =
      await adminClient.auth.admin.createUser({
        email: loginEmail,
        password,
        email_confirm: true,
        user_metadata: {
          name: loginName,
          role: 'professional',
          businessId,
          professionalId,
        },
      })
    if (createUserError || !created.user) {
      console.error('configure-employee-login create user failed', createUserError?.message)
      return json({ error: 'Unable to create employee user' }, 500)
    }
    employeeUserId = created.user.id
  }

  const { error: profileError } = await adminClient.from('profiles').upsert({
    id: employeeUserId,
    name: loginName,
    email: loginEmail,
  })
  if (profileError) {
    console.error('configure-employee-login profile upsert failed', profileError.message)
    return json({ error: 'Unable to update employee profile' }, 500)
  }

  const { error: membershipUpsertError } = await adminClient
    .from('memberships')
    .upsert({
      business_id: businessId,
      user_id: employeeUserId,
      role: 'professional',
      active: true,
    }, { onConflict: 'business_id,user_id' })
  if (membershipUpsertError) {
    console.error('configure-employee-login membership upsert failed', membershipUpsertError.message)
    return json({ error: 'Unable to link employee to business' }, 500)
  }

  const { error: updateProfessionalError } = await adminClient
    .from('professionals')
    .update({
      user_id: employeeUserId,
      login_enabled: true,
      login_name: loginName,
      login_email: loginEmail,
    })
    .eq('business_id', businessId)
    .eq('id', professionalId)
  if (updateProfessionalError) {
    console.error('configure-employee-login professional update failed', updateProfessionalError.message)
    return json({ error: 'Unable to update professional login' }, 500)
  }

  return json({
    configured: true,
    professionalId,
    loginName,
  })
})

function normalizeString(value: unknown) {
  return typeof value === 'string' ? value.trim() : ''
}

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, { status, headers: corsHeaders })
}
