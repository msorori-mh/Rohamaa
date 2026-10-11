import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

// The only client is the mobile app, so no browser CORS headers are sent.
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const NO_SESSION = { auth: { persistSession: false, autoRefreshToken: false } }
// bcrypt, used by the auth server, only reads the first 72 bytes.
const MAX_PASSWORD_BYTES = 72

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response(null, { status: 204 })
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)
  const authHeader = req.headers.get('Authorization') ?? ''
  if (!authHeader.startsWith('Bearer ')) return json({ error: 'unauthorized' }, 401)
  const jwt = authHeader.slice(7)

  const url = Deno.env.get('SUPABASE_URL')!
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')!
  const authClient = createClient(url, anonKey, NO_SESSION)
  const admin = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, NO_SESSION)
  const { data: callerData, error: callerError } = await authClient.auth.getUser(jwt)
  const user = callerData?.user
  if (callerError || !user) return json({ error: 'unauthorized' }, 401)
  const { data: profile, error: profileLookupError } = await admin.from('profiles')
    .select('role,is_suspended,force_password_change,temp_password_expires_at').eq('id', user.id).maybeSingle()
  if (profileLookupError) return json({ error: 'profile_lookup_failed' }, 500)
  if (!profile || profile.is_suspended || !['admin', 'supervisor', 'courier'].includes(profile.role)) {
    return json({ error: 'staff_required' }, 403)
  }

  let payload: unknown
  try { payload = await req.json() } catch (_) { return json({ error: 'invalid_json' }, 400) }
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) return json({ error: 'invalid_body' }, 400)
  const body = payload as Record<string, unknown>
  if (typeof body.password !== 'string') return json({ error: 'password_too_short' }, 400)
  const password = body.password
  if (body.current_password !== undefined && body.current_password !== null && typeof body.current_password !== 'string') {
    return json({ error: 'current_password_invalid' }, 400)
  }
  const currentPassword = typeof body.current_password === 'string' ? body.current_password : ''

  if (password.length < 8) return json({ error: 'password_too_short' }, 400)
  if (new TextEncoder().encode(password).length > MAX_PASSWORD_BYTES) return json({ error: 'password_too_long' }, 400)
  if (!/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password) || !/[^A-Za-z0-9]/.test(password)) {
    return json({ error: 'password_not_complex' }, 400)
  }

  const forced = profile.force_password_change === true
  if (forced && profile.temp_password_expires_at && new Date(profile.temp_password_expires_at).getTime() <= Date.now()) {
    // An expired temporary password can no longer be exchanged; an admin must issue a new one.
    return json({ error: 'temp_password_expired' }, 403)
  }

  // A throwaway client proves knowledge of a password without touching the caller's session.
  const passwordMatches = async (candidate: string): Promise<boolean> => {
    if (!user.email) return false
    const verifier = createClient(url, anonKey, NO_SESSION)
    const { data, error } = await verifier.auth.signInWithPassword({ email: user.email, password: candidate })
    return !error && Boolean(data?.session)
  }

  if (forced) {
    // First sign-in with a temporary password: the session itself is the proof,
    // but the temporary password may not simply be kept.
    if (await passwordMatches(password)) return json({ error: 'password_unchanged' }, 400)
  } else {
    if (currentPassword.length === 0) return json({ error: 'current_password_required' }, 400)
    if (currentPassword.length > 1024) return json({ error: 'current_password_invalid' }, 403)
    if (!(await passwordMatches(currentPassword))) return json({ error: 'current_password_invalid' }, 403)
    if (currentPassword === password) return json({ error: 'password_unchanged' }, 400)
  }

  const { error: updateError } = await admin.auth.admin.updateUserById(user.id, { password })
  if (updateError) return json({ error: 'password_update_failed' }, 400)
  const now = new Date().toISOString()
  const { error: profileError } = await admin.from('profiles')
    .update({ force_password_change: false, password_changed_at: now, temp_password_expires_at: null })
    .eq('id', user.id)
  if (profileError) return json({ error: 'profile_update_failed' }, 500)

  // Every other session (including the verification sign-in above) is revoked; the caller stays signed in.
  const { error: signOutError } = await admin.auth.admin.signOut(jwt, 'others')
  const { error: auditError } = await admin.from('audit_logs').insert({
    actor_id: user.id, action: 'staff_password_changed', entity_type: 'profile', entity_id: user.id,
    metadata: { forced, other_sessions_revoked: !signOutError },
  })
  return json({ ok: true, other_sessions_revoked: !signOutError, audit_logged: !auditError })
})
