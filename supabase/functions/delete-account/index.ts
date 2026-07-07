import { withSupabase } from 'npm:@supabase/server'

export default {
  fetch: withSupabase({ auth: 'user' }, async (_request, context) => {
    const userId = context.userClaims?.sub
    if (!userId) {
      return Response.json({ error: 'Unauthorized' }, { status: 401 })
    }

    const { error: businessError } = await context.supabaseAdmin
      .from('businesses')
      .delete()
      .eq('created_by', userId)
    if (businessError) {
      console.error('delete-account business cleanup failed', businessError.message)
      return Response.json({ error: 'Unable to delete business data' }, { status: 500 })
    }

    const { error } = await context.supabaseAdmin.auth.admin.deleteUser(userId)
    if (error) {
      console.error('delete-account failed', error.message)
      return Response.json({ error: 'Unable to delete account' }, { status: 500 })
    }

    return Response.json({ deleted: true })
  }),
}
