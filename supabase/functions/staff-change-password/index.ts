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
  const user = callerData.user
  if (callerError || !user) return json({ error: 'unauthorized' }, 401)
  const { data: profile } = await admin.from('profiles').select('role,is_suspended').eq('id', user.id).single()
  if (!profile || profile.is_suspended || !['admin','supervisor','courier'].includes(profile.role)) return json({ error: 'staff_required' }, 403)

  let body: Record<string, unknown>
  try { body = await req.json() } catch (_) { return json({ error: 'invalid_json' }, 400) }
  const password = String(body.password ?? '')
  if (password.length < 8) return json({ error: 'password_too_short' }, 400)
  if (!/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password) || !/[^A-Za-z0-9]/.test(password)) return json({ error: 'password_not_complex' }, 400)

  const { error: updateError } = await admin.auth.admin.updateUserById(user.id, { password })
  if (updateError) return json({ error: 'password_update_failed', message: updateError.message }, 400)
  const now = new Date().toISOString()
  const { error: profileError } = await admin.from('profiles').update({ force_password_change: false, password_changed_at: now }).eq('id', user.id)
  if (profileError) return json({ error: 'profile_update_failed' }, 500)
  await admin.from('audit_logs').insert({ actor_id: user.id, action: 'staff_password_changed', entity_type: 'profile', entity_id: user.id, metadata: {} })
  return json({ ok: true })
})
