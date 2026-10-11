import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

// The only client is the mobile app, so no browser CORS headers are sent.
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const NO_SESSION = { auth: { persistSession: false, autoRefreshToken: false } }
// bcrypt, used by the auth server, only reads the first 72 bytes.
const MAX_PASSWORD_BYTES = 72

// An admin gives a courier or supervisor a new temporary password. The staff
// member must exchange it at the next sign-in (force_password_change).
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
  if (typeof payload.user_id !== 'string' || !UUID.test(payload.user_id)) return json({ error: 'invalid_user' }, 400)
  if (typeof payload.password !== 'string') return json({ error: 'password_too_short' }, 400)
  const userId = payload.user_id.toLowerCase()
  const password = payload.password

  // Same policy and codes as staff creation.
  if (password.length < 8) return json({ error: 'password_too_short' }, 400)
  if (new TextEncoder().encode(password).length > MAX_PASSWORD_BYTES) return json({ error: 'password_too_long' }, 400)
  if (!/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password) || !/[^A-Za-z0-9]/.test(password)) {
    return json({ error: 'password_not_complex' }, 400)
  }

  // Only couriers and supervisors: never an admin, never a regular user.
  const { data: target, error: targetError } = await admin.from('profiles')
    .select('role,is_primary_admin').eq('id', userId).maybeSingle()
  if (targetError) return json({ error: 'profile_lookup_failed' }, 500)
  if (!target) return json({ error: 'invalid_user' }, 404)
  if (target.is_primary_admin || !['courier', 'supervisor'].includes(target.role)) {
    return json({ error: 'not_staff' }, 400)
  }

  const { error: updateError } = await admin.auth.admin.updateUserById(userId, { password })
  if (updateError) {
    // Only the provider's machine-readable code is inspected; its message is never returned.
    const code = (updateError as { code?: string } | null)?.code
    if (code === 'weak_password') return json({ error: 'password_not_complex' }, 400)
    return json({ error: 'password_update_failed' }, 400)
  }

  // Forces the exchange of the temporary password (72 hours) and writes the
  // audit entry in one transaction; the database re-checks admin and target.
  // The password is already changed, so one retry before giving up.
  const markReset = async (): Promise<string | null> => {
    try {
      const { error } = await admin.rpc('admin_mark_staff_password_reset', { p_admin_id: caller.id, p_user_id: userId })
      return error ? (error.message ?? 'failed') : null
    } catch (_) {
      return 'failed'
    }
  }
  let markError = await markReset()
  if (markError !== null) markError = await markReset()
  if (markError !== null) {
    if (markError.includes('active admin required')) return json({ error: 'admin_required' }, 403)
    if (markError.includes('not staff')) return json({ error: 'not_staff' }, 400)
    if (markError.includes('profile not found')) return json({ error: 'invalid_user' }, 404)
    return json({ error: 'profile_update_failed' }, 500)
  }

  // Sessions. admin.auth.admin.signOut needs the target's own JWT, which an
  // admin never has, so it cannot be used here. Protection does not depend on
  // revocation: force_password_change blocks every staff RPC (is_admin,
  // is_courier, is_supervisor, is_active_user) until the temporary password is
  // exchanged. In addition the auth server ends the account's sessions when
  // its password is replaced, and the sessions are removed in the database as
  // a best effort, so an old session cannot be used to exchange the temporary
  // password. A failure of that extra step is reported, not turned into an error.
  let sessionsRevoked = false
  try {
    const { data, error } = await admin.rpc('staff_revoke_sessions', { p_user: userId })
    sessionsRevoked = !error && data === true
  } catch (_) {
    sessionsRevoked = false
  }

  return json({ ok: true, sessions_revoked: sessionsRevoked })
})
