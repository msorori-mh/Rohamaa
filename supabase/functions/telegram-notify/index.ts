import 'jsr:@supabase/functions-js/edge-runtime.d.ts'

// Receives events from database triggers (through pg_net) and forwards a short
// Arabic message to the operations Telegram chat. Only codes, categories and
// status values are sent: never names, phone numbers, addresses or free text.

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), { status, headers: { 'Content-Type': 'application/json' } })

const ACTIONS: Record<string, string> = {
  create_staff_account: 'إنشاء حساب فريق جديد',
  set_service_partner_status: 'تغيير حالة شريك',
  create_delivery: 'إسناد توصيل جديد',
  reassign_delivery: 'إعادة إسناد توصيل',
  prepare_account_deletion: 'طلب حذف حساب قيد التجهيز',
  complete_account_deletion: 'تنفيذ حذف حساب',
  reject_account_deletion: 'رفض طلب حذف حساب',
  create_service_area: 'إنشاء منطقة خدمة',
  activate_service_area: 'تفعيل منطقة خدمة',
  deactivate_service_area: 'إيقاف منطقة خدمة',
  set_user_role: 'تغيير دور مستخدم',
  suspend_user: 'تجميد أو إلغاء تجميد حساب',
  reject_contribution: 'رفض مساهمة تشغيلية',
  verify_contribution: 'تأكيد مساهمة تشغيلية',
}

// Only these metadata keys are shown, and only as short values.
const SAFE_KEYS = ['status', 'role', 'new_role', 'old_role', 'kind', 'code', 'name_ar', 'suspended']

const clean = (value: unknown) => String(value ?? '—').replace(/[<>&]/g, '').slice(0, 80)

function formatEvent(event: Record<string, unknown>): string | null {
  const now = new Date().toLocaleString('ar-YE', { timeZone: 'Asia/Aden' })
  if (event.source === 'need') {
    return `🙏 طلب احتياج جديد\nالرمز: ${clean(event.public_code)}\nالفئة: ${clean(event.category)}\nالنوع: ${clean(event.item_type)}\n${now}`
  }
  if (event.source === 'donation') {
    return `🎁 تبرع جديد\nالرمز: ${clean(event.public_code)}\nالفئة: ${clean(event.category)}\nالنوع: ${clean(event.item_type)}\n${now}`
  }
  if (event.source === 'audit') {
    const label = ACTIONS[String(event.action)]
    if (!label) return null
    const meta = (event.metadata ?? {}) as Record<string, unknown>
    const details = SAFE_KEYS.filter((k) => meta[k] !== undefined)
      .map((k) => `${k}: ${clean(meta[k])}`)
    return [`🔔 ${label}`, `المرجع: ${clean(event.entity_type)} ${clean(event.entity_id)}`, ...details, now].join('\n')
  }
  return null
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  const expected = Deno.env.get('NOTIFY_SECRET')
  if (!expected || req.headers.get('x-notify-secret') !== expected) {
    return json({ error: 'unauthorized' }, 401)
  }

  const token = Deno.env.get('TELEGRAM_BOT_TOKEN')
  const chatId = Deno.env.get('TELEGRAM_CHAT_ID')
  if (!token || !chatId) return json({ error: 'telegram_not_configured' }, 500)

  let event: Record<string, unknown>
  try {
    event = await req.json()
  } catch {
    return json({ error: 'invalid_json' }, 400)
  }

  const text = formatEvent(event)
  if (!text) return json({ skipped: true })

  const response = await fetch(`https://api.telegram.org/bot${token}/sendMessage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ chat_id: chatId, text, disable_web_page_preview: true }),
  })
  if (!response.ok) return json({ error: 'telegram_failed', status: response.status }, 502)
  return json({ sent: true })
})
