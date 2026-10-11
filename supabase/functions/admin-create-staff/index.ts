import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

// The only client is the mobile app, so no browser CORS headers are sent.
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const NO_SESSION = { auth: { persistSession: false, autoRefreshToken: false } }
const MAX_AREAS = 20
// bcrypt, used by the auth server, only reads the first 72 bytes.
const MAX_PASSWORD_BYTES = 72

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204 })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)
  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.startsWith('Bearer ')) return json({ error: 'unauthorized' }, 401)

  const url = Deno.env.get('SUPABASE_URL')!
  const authClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, NO_SESSION)
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, NO_SESSION)
  const { data: callerData, error: callerError } = await authClient.auth.getUser(authHeader.slice(7))
  const caller = callerData?.user
  if (callerError || !caller) return json({ error: 'unauthorized' }, 401)
  const { data: callerProfile, error: callerProfileError } = await admin.from('profiles')
    .select('role,is_suspended,force_password_change').eq('id', caller.id).maybeSingle()
  if (callerProfileError) return json({ error: 'profile_lookup_failed' }, 500)
  if (!callerProfile || callerProfile.role !== 'admin' || callerProfile.is_suspended || callerProfile.force_password_change) {
    return json({ error: 'admin_required' }, 403)
  }

  let raw: unknown
  try { raw = await req.json() } catch (_) { return json({ error: 'invalid_json' }, 400) }
  if (typeof raw !== 'object' || raw === null || Array.isArray(raw)) return json({ error: 'invalid_body' }, 400)
  const payload = raw as Record<string, unknown>
  if (typeof payload.email !== 'string' || payload.email.length > 254) return json({ error: 'invalid_email' }, 400)
  if (typeof payload.password !== 'string') return json({ error: 'password_too_short' }, 400)
  if (typeof payload.full_name !== 'string') return json({ error: 'full_name_required' }, 400)
  if (typeof payload.role !== 'string') return json({ error: 'invalid_role' }, 400)
  if (!Array.isArray(payload.area_ids)) return json({ error: 'area_required' }, 400)

  const email = payload.email.trim().toLowerCase()
  const password = payload.password
  const fullName = payload.full_name.trim()
  const role = payload.role
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return json({ error: 'invalid_email' }, 400)
  if (password.length < 8) return json({ error: 'password_too_short' }, 400)
  if (new TextEncoder().encode(password).length > MAX_PASSWORD_BYTES) return json({ error: 'password_too_long' }, 400)
  if (!/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password) || !/[^A-Za-z0-9]/.test(password)) {
    return json({ error: 'password_not_complex' }, 400)
  }
  if (fullName.length < 2) return json({ error: 'full_name_required' }, 400)
  if (fullName.length > 120) return json({ error: 'full_name_too_long' }, 400)
  if (!['courier', 'supervisor'].includes(role)) return json({ error: 'invalid_role' }, 400)
  if (payload.area_ids.length === 0) return json({ error: 'area_required' }, 400)
  if (payload.area_ids.length > MAX_AREAS) return json({ error: 'too_many_areas' }, 400)
  if (!payload.area_ids.every((id) => typeof id === 'string' && UUID.test(id))) return json({ error: 'invalid_area' }, 400)
  const areaIds = [...new Set((payload.area_ids as string[]).map((id) => id.toLowerCase()))]

  // The primary administrator's address is reserved; it is read from the
  // database so no personal address lives in function source. Kept although
  // createUser would normally answer email_exists for it: the check does not
  // depend on staff_email still matching the auth email, and the app shows a
  // dedicated message for reserved_email.
  const { data: primaryAdmins, error: primaryError } = await admin.from('profiles')
    .select('staff_email').eq('is_primary_admin', true)
  if (primaryError) return json({ error: 'profile_lookup_failed' }, 500)
  const reserved = ((primaryAdmins ?? []) as { staff_email?: unknown }[])
    .some((row) => typeof row.staff_email === 'string' && row.staff_email.toLowerCase() === email)
  if (reserved) {
    return json({ error: 'reserved_email' }, 400)
  }

  const { data: areas, error: areasError } = await admin.from('service_areas').select('id').in('id', areaIds).eq('active', true)
  if (areasError) return json({ error: 'area_lookup_failed' }, 500)
  if (!areas || areas.length !== areaIds.length) return json({ error: 'invalid_area' }, 400)

  // Only the provider's machine-readable code is inspected; its message is never returned.
  const passwordFailure = (error: unknown): string =>
    (error as { code?: string } | null)?.code === 'weak_password' ? 'password_not_complex' : 'create_user_failed'

  // The auth user is marked as pending until the profile is finalized, so a
  // retry after a partial failure can find and resume it instead of failing
  // forever with email_exists. app_metadata is writable by the service role only.
  let userId = ''
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email, password, email_confirm: true, user_metadata: { full_name: fullName },
    app_metadata: { pending_staff: true },
  })
  if (createError || !created?.user) {
    const code = (createError as { code?: string } | null)?.code
    if (code !== 'email_exists' && code !== 'user_already_exists') {
      return json({ error: passwordFailure(createError) }, 400)
    }
    // Only an account this function created and never finished is resumed;
    // every other existing address is reported as taken.
    const { data: pendingId, error: pendingError } = await admin.rpc('pending_staff_user_id', { p_email: email })
    if (pendingError) return json({ error: 'profile_lookup_failed' }, 500)
    if (typeof pendingId !== 'string' || !UUID.test(pendingId)) return json({ error: 'email_exists' }, 409)
    // The password of the first attempt may be unknown by now: the new one wins.
    const { error: resumeError } = await admin.auth.admin.updateUserById(pendingId, {
      password, email_confirm: true, user_metadata: { full_name: fullName },
    })
    if (resumeError) return json({ error: passwordFailure(resumeError) }, 400)
    userId = pendingId
  } else {
    userId = created.user.id
  }

  // Profile, areas, courier row and audit entry are written in one transaction.
  const { error: setupError } = await admin.rpc('admin_finalize_staff_account', {
    p_admin_id: caller.id, p_user_id: userId, p_email: email,
    p_full_name: fullName, p_role: role, p_area_ids: areaIds,
  })
  if (setupError) {
    const { error: rollbackError } = await admin.auth.admin.deleteUser(userId)
    if (rollbackError) return json({ error: 'rollback_failed' }, 500)
    return json({ error: 'staff_setup_failed' }, 500)
  }

  // Finalized: clear the marker (one retry). A marker that could not be
  // cleared is harmless, because pending_staff_user_id also requires the
  // profile to still be a plain, never-provisioned user.
  const clearPending = async (): Promise<boolean> => {
    try {
      const { error } = await admin.auth.admin.updateUserById(userId, { app_metadata: { pending_staff: false } })
      return !error
    } catch (_) {
      return false
    }
  }
  if (!(await clearPending())) await clearPending()

  return json({ id: userId, email, role, force_password_change: true }, 201)
})
