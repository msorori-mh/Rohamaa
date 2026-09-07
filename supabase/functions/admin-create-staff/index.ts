import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const json = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } })

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)
  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.startsWith('Bearer ')) return json({ error: 'unauthorized' }, 401)

  const url = Deno.env.get('SUPABASE_URL')!
  const authClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!)
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, { auth: { persistSession: false, autoRefreshToken: false } })
  const { data: callerData, error: callerError } = await authClient.auth.getUser(authHeader.slice(7))
  const caller = callerData.user
  if (callerError || !caller) return json({ error: 'unauthorized' }, 401)
  const { data: callerProfile } = await admin.from('profiles').select('role,is_suspended').eq('id', caller.id).single()
  if (!callerProfile || callerProfile.role !== 'admin' || callerProfile.is_suspended) return json({ error: 'admin_required' }, 403)

  let payload: Record<string, unknown>
  try { payload = await req.json() } catch (_) { return json({ error: 'invalid_json' }, 400) }
  const email = String(payload.email ?? '').trim().toLowerCase()
  const password = String(payload.password ?? '')
  const fullName = String(payload.full_name ?? '').trim()
  const role = String(payload.role ?? '')
  const areaIds = Array.isArray(payload.area_ids) ? [...new Set(payload.area_ids.map(String))] : []
  if (!/^\S+@\S+\.\S+$/.test(email)) return json({ error: 'invalid_email' }, 400)
  if (password.length < 8) return json({ error: 'password_too_short' }, 400)
  if (!/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password) || !/[^A-Za-z0-9]/.test(password)) return json({ error: 'password_not_complex' }, 400)
  if (fullName.length < 2) return json({ error: 'full_name_required' }, 400)
  if (!['courier', 'supervisor'].includes(role)) return json({ error: 'invalid_role' }, 400)
  if (areaIds.length === 0) return json({ error: 'area_required' }, 400)
  if (email === 'msorori201201@gmail.com') return json({ error: 'reserved_email' }, 400)

  const { data: areas } = await admin.from('service_areas').select('id').in('id', areaIds).eq('active', true)
  if (!areas || areas.length !== areaIds.length) return json({ error: 'invalid_area' }, 400)

  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email, password, email_confirm: true,
    user_metadata: { full_name: fullName }, app_metadata: { sanad_role: role },
  })
  if (createError || !created.user) return json({ error: 'create_user_failed', message: createError?.message }, 400)
  const userId = created.user.id

  try {
    const { error: updateError } = await admin.from('profiles').update({
      full_name: fullName, staff_email: email, role, force_password_change: true,
      password_changed_at: null, staff_created_by: caller.id, is_suspended: false,
    }).eq('id', userId)
    if (updateError) throw updateError
    const { error: assignmentError } = await admin.from('staff_area_assignments').insert(areaIds.map((areaId, index) => ({ user_id: userId, area_id: areaId, is_primary: index === 0, created_by: caller.id })))
    if (assignmentError) throw assignmentError
    if (role === 'courier') {
      const { error: courierError } = await admin.from('couriers').upsert({ user_id: userId, active: true })
      if (courierError) throw courierError
    }
    await admin.from('audit_logs').insert({ actor_id: caller.id, action: 'create_staff_account', entity_type: 'profile', entity_id: userId, metadata: { role, email, area_ids: areaIds } })
    return json({ id: userId, email, role, force_password_change: true }, 201)
  } catch (error) {
    await admin.auth.admin.deleteUser(userId)
    return json({ error: 'staff_setup_failed', message: error instanceof Error ? error.message : String(error) }, 500)
  }
})
