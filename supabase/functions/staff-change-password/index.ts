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

  // The password is compared with the stored hash inside the database. No
  // sign-in happens, so no extra session is created and the shared per-IP
  // sign-in rate limit of the auth server is not consumed.
  // 'match' / 'mismatch' / 'error' -- an error is never treated as either answer.
  const verifyPassword = async (candidate: string): Promise<'match' | 'mismatch' | 'error'> => {
    try {
      const { data, error } = await admin.rpc('staff_verify_password', { p_user: user.id, p_password: candidate })
      if (error || typeof data !== 'boolean') return 'error'
      return data ? 'match' : 'mismatch'
    } catch (_) {
      return 'error'
    }
  }

  if (forced) {
    // First sign-in with a temporary password: the session itself is the proof,
    // but the temporary password may not simply be kept. A verifier failure
    // fails closed.
    const sameAsTemporary = await verifyPassword(password)
    if (sameAsTemporary === 'error') return json({ error: 'verification_failed' }, 500)
    if (sameAsTemporary === 'match') return json({ error: 'password_unchanged' }, 400)
  } else {
    if (currentPassword.length === 0) return json({ error: 'current_password_required' }, 400)
    if (currentPassword.length > 1024) return json({ error: 'current_password_invalid' }, 403)
    // Decided before any verification, so it reveals nothing about the stored password.
    if (currentPassword === password) return json({ error: 'password_unchanged' }, 400)

    // Five wrong current passwords within 15 minutes lock further attempts.
    const { data: locked, error: lockError } = await admin.rpc('staff_password_is_locked', { p_user: user.id })
    if (lockError || typeof locked !== 'boolean') return json({ error: 'verification_failed' }, 500)
    if (locked) return json({ error: 'too_many_attempts' }, 429)

    const current = await verifyPassword(currentPassword)
    if (current === 'error') return json({ error: 'verification_failed' }, 500)
    if (current === 'mismatch') {
      const { error: countError } = await admin.rpc('staff_password_register_failure', { p_user: user.id })
      // Without a recorded failure the lock could be bypassed, so that is an error too.
      if (countError) return json({ error: 'verification_failed' }, 500)
      return json({ error: 'current_password_invalid' }, 403)
    }
  }

  const { error: updateError } = await admin.auth.admin.updateUserById(user.id, { password })
  if (updateError) return json({ error: 'password_update_failed' }, 400)

  // The password has changed, so the flag must follow; one retry before giving up.
  const clearFlag = async (): Promise<boolean> => {
    try {
      const { error } = await admin.from('profiles')
        .update({ force_password_change: false, password_changed_at: new Date().toISOString(), temp_password_expires_at: null })
        .eq('id', user.id)
      return !error
    } catch (_) {
      return false
    }
  }
  if (!(await clearFlag()) && !(await clearFlag())) return json({ error: 'profile_update_failed' }, 500)

  // Best effort from here on: the password is already changed.
  try { await admin.rpc('staff_password_reset_attempts', { p_user: user.id }) } catch (_) { /* counters expire on their own */ }

  // Every other session (for example a thief's) is ended after the change.
  // The auth server may already have ended all sessions of this account as
  // part of the password update, including the caller's; the database
  // fallback covers that case. A failure here never fails the request.
  let sessionsRevoked = false
  try {
    const { error } = await admin.auth.admin.signOut(jwt, 'others')
    sessionsRevoked = !error
  } catch (_) {
    sessionsRevoked = false
  }
  if (!sessionsRevoked) {
    try {
      const { data, error } = await admin.rpc('staff_revoke_sessions', { p_user: user.id })
      sessionsRevoked = !error && data === true
    } catch (_) {
      sessionsRevoked = false
    }
  }

  // A failed audit write is reported, not turned into an error.
  const { error: auditError } = await admin.from('audit_logs').insert({
    actor_id: user.id, action: 'staff_password_changed', entity_type: 'profile', entity_id: user.id,
    metadata: { forced },
  })
  return json({ ok: true, audit_logged: !auditError, sessions_revoked: sessionsRevoked })
})
