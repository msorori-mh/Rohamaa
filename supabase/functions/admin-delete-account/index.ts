import 'jsr:@supabase/functions-js/edge-runtime.d.ts'
import { createClient } from 'npm:@supabase/supabase-js@2'

// The only client is the mobile app, so no browser CORS headers are sent.
const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i
const BUCKET = 'donation-images'
const NO_SESSION = { auth: { persistSession: false, autoRefreshToken: false } }

// Database errors are mapped to stable codes; raw messages never leave the function.
const rpcFailure = (message: string | undefined, fallback: string): [string, number] => {
  const text = message ?? ''
  if (text.includes('admin required')) return ['admin_required', 403]
  if (text.includes('deletion request not found')) return ['request_not_found', 404]
  if (text.includes('delivery in progress')) return ['delivery_in_progress', 409]
  if (text.includes('deletion request is not open')) return ['request_not_open', 409]
  if (text.includes('deletion request is not pending')) return ['request_not_pending', 409]
  if (text.includes('deletion request is not being processed')) return ['request_not_processing', 409]
  if (text.includes('deletion request has no account')) return ['request_has_no_account', 409]
  if (text.includes('cannot delete own account')) return ['cannot_delete_self', 409]
  if (text.includes('staff accounts must be managed')) return ['staff_account', 409]
  if (text.includes('storage objects remain')) return ['storage_cleanup_incomplete', 409]
  if (text.includes('note too long')) return ['note_too_long', 400]
  return [fallback, 500]
}

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
  const caller = callerData?.user
  if (callerError || !caller) return json({ error: 'unauthorized' }, 401)
  const { data: callerProfile, error: callerProfileError } = await admin.from('profiles')
    .select('role,is_suspended,force_password_change').eq('id', caller.id).maybeSingle()
  if (callerProfileError) return json({ error: 'profile_lookup_failed' }, 500)
  if (!callerProfile || callerProfile.role !== 'admin' || callerProfile.is_suspended || callerProfile.force_password_change) {
    return json({ error: 'admin_required' }, 403)
  }

  let payload: unknown
  try { payload = await req.json() } catch (_) { return json({ error: 'invalid_json' }, 400) }
  if (typeof payload !== 'object' || payload === null || Array.isArray(payload)) return json({ error: 'invalid_body' }, 400)
  const body = payload as Record<string, unknown>
  const requestId = body.request_id
  const approve = body.approve
  const rawNote = body.note
  if (typeof requestId !== 'string' || !UUID.test(requestId)) return json({ error: 'invalid_request_id' }, 400)
  if (typeof approve !== 'boolean') return json({ error: 'invalid_approve' }, 400)
  if (rawNote !== undefined && rawNote !== null && typeof rawNote !== 'string') return json({ error: 'invalid_note' }, 400)
  const note = typeof rawNote === 'string' && rawNote.trim().length > 0 ? rawNote.trim() : null
  if (note !== null && note.length > 500) return json({ error: 'note_too_long' }, 400)

  // Database steps run with the caller's JWT so auth.uid() is the acting admin
  // and every admin check is re-evaluated by the database itself.
  const asCaller = createClient(url, anonKey, { ...NO_SESSION, global: { headers: { Authorization: `Bearer ${jwt}` } } })

  if (!approve) {
    const { error } = await asCaller.rpc('admin_reject_account_deletion', { p_request_id: requestId, p_note: note })
    if (error) {
      const [code, status] = rpcFailure(error.message, 'reject_failed')
      return json({ error: code }, status)
    }
    return json({ ok: true, status: 'rejected' })
  }

  // 1. Close open work and scrub personal data. Safe to repeat after a partial failure.
  const { data: prepared, error: prepareError } = await asCaller.rpc('admin_prepare_account_deletion', { p_request_id: requestId, p_note: note })
  if (prepareError) {
    const [code, status] = rpcFailure(prepareError.message, 'prepare_failed')
    return json({ error: code }, status)
  }
  const result = (typeof prepared === 'object' && prepared !== null ? prepared : {}) as Record<string, unknown>
  const userId = result.user_id
  if (typeof userId !== 'string' || !UUID.test(userId)) return json({ error: 'prepare_failed' }, 500)
  // Defence in depth: never remove an object outside the deleted user's own folder.
  const paths = (Array.isArray(result.storage_paths) ? result.storage_paths : [])
    .filter((path): path is string => typeof path === 'string' && path.startsWith(`${userId}/`))

  // 2. Remove the user's photos.
  for (let index = 0; index < paths.length; index += 100) {
    const { error: removeError } = await admin.storage.from(BUCKET).remove(paths.slice(index, index + 100))
    if (removeError) return json({ error: 'storage_cleanup_failed' }, 500)
  }

  // 3. Soft-delete the auth user: sign-in identifiers are scrubbed while the
  //    row that operational history references is kept.
  const { error: deleteError } = await admin.auth.admin.deleteUser(userId, true)
  if (deleteError) {
    // A retry after an earlier partial run finds the user already soft-deleted.
    const { data: existing, error: lookupError } = await admin.auth.admin.getUserById(userId)
    const alreadyDeleted = !lookupError && Boolean((existing?.user as { deleted_at?: string | null } | null | undefined)?.deleted_at)
    if (!alreadyDeleted) return json({ error: 'auth_delete_failed' }, 500)
  }

  // 4. Close the request.
  const { error: completeError } = await asCaller.rpc('admin_complete_account_deletion', { p_request_id: requestId })
  if (completeError) {
    const [code, status] = rpcFailure(completeError.message, 'complete_failed')
    return json({ error: code }, status)
  }
  return json({ ok: true, status: 'completed' })
})
