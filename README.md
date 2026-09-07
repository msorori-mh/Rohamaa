# Ruhamaa | رحماء

منصة مجتمعية في مدينة مأرب تربط الأشياء المتبرع بها بالاحتياجات المناسبة، مع الحفاظ على خصوصية المتبرع والمستفيد وفصل الطرفين عبر عمليات توصيل تابعة لرحماء.

## Android identity

- Application ID: `com.ruhamaa.app`
- Production domain: `https://ruhamaa.com`
- Local/internal OAuth callback: `com.ruhamaa.app://login-callback`
- Production App Link callback after verification: `https://ruhamaa.com/login-callback`

## V1 Scope

- Google Sign-In عبر Supabase Auth
- حساب مستخدم واحد يمكنه التبرع أو تسجيل احتياج
- عناوين متعددة مع موقع جغرافي
- تسجيل التبرعات والاحتياجات
- مطابقة احتياج ↔ تبرع بنظام قواعد ونقاط
- إخفاء هوية المتبرع والمستفيد عن بعضهما
- Workflow للمندوبين مع PIN للاستلام والتسليم
- مساهمات تشغيلية اختيارية مرتبطة بالعمليات
- Risk Flags ومراجعة يدوية للحالات المشبوهة
- لوحة إدارة وتشغيل ضمن نفس قاعدة البيانات

## Supabase

Project ref: `vclicpejajxadsbuakdw`

لا يتم حفظ مفاتيح Supabase السرية داخل المستودع. استخدم متغيرات البيئة أو `--dart-define` للقيم العميلية المسموح بها.

## Repository structure

```text
app/                 Flutter Android app
supabase/
  migrations/        SQL schema and policies
  functions/         Edge Functions
  seed.sql           development seed data
site/                ruhamaa.com static site
docs/                architecture and release documentation
```

## Core principles

1. الاحتياج أولًا، ولا توجد واجهة Marketplace.
2. المتبرع والمستفيد لا يعرف أحدهما هوية الآخر.
3. Google Auth للمصادقة، وليس كإثبات هوية نهائي.
4. المساهمات التشغيلية اختيارية ولا تعطي أولوية في الاستحقاق.
5. القرارات الحساسة أو عالية الخطورة تمر بمراجعة بشرية.
6. أقل قدر ضروري من البيانات يظهر للمندوب أثناء تنفيذ المهمة.
