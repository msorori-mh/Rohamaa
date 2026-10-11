# Ataa | عطاء

> **الهوية المعتمدة: عطاء (Ataa)** — [دليل الهوية والتوافق وتسليم الفروع القديمة](docs/ATAA_IDENTITY.md). الاسم الظاهر تغيّر؛ معرّفات Android والنطاق والتوقيع الحالية محفوظة للتوافق.

> **الحالة في 11 أكتوبر 2026:** التطبيق في مرحلة تجريبية مغلقة في مأرب و**غير منشور** في Google Play. يضم هذا الفرع السلسلة التي اختُبرت سابقًا (تبسيط العربية، Courier Dispatch V2، الاختبارات المعزولة وترحيل إغلاق الأمان) مع إصلاحات تدقيق أكتوبر 2026. لم يُبنَ بعد AAB موقّع للإنتاج، وقاعدة الإنتاج لم تُطابَق بعد مع كل ترحيلات المستودع. ما تغيّر وما بقي على المالك تنفيذه يدويًا في لوحات التحكم موثّق في [تدقيق أكتوبر 2026](docs/AUDIT_2026-10.md).

منصة مجتمعية في مدينة مأرب تربط الأشياء والوقت والمهارات غير المستغلة بالاحتياجات المناسبة، مع الحفاظ على الخصوصية والكرامة وفصل الأطراف بقدر ما تسمح به طبيعة كل عملية.

## Android identity

- Application ID: `com.ruhamaa.app`
- Production domain: `https://ruhamaa.com`
- OAuth callback used by current builds: `com.ruhamaa.app://login-callback`
- HTTPS App Link callback, only after App Link verification: `https://ruhamaa.com/login-callback/` (the site serves this page as a directory, with the trailing slash; `https` only)

The four names that appear in this repository (Ataa, the `ruhamaa` identifiers, the repository name and the legacy "Sanad" comments) are explained in [docs/NAMING.md](docs/NAMING.md).

## V1 Scope

- Google Sign-In عبر Supabase Auth
- حساب مستخدم واحد يمكنه التبرع، تسجيل احتياج، تقديم وقت/مهارة، أو طلب خدمة
- عنوان افتراضي مع موقع جغرافي يحدده المستخدم
- **Category System V2** للأشياء: فئة رئيسية → قسم → نوع دقيق → خصائص مثل المقاس/العمر/الصف/المادة/الأبعاد
- توافق مع التبرعات والاحتياجات القديمة عبر canonical category mapping
- مطابقة V2 تعطي وزنًا للنوع الدقيق والخصائص مع بقاء العمر/المسافة/الثقة/العدالة ضمن القرار
- عرض محدود ومحجوب الهوية لـ **احتياجات راجعها عطاء** بهدف تحفيز العطاء، وليس إنشاء Marketplace
- زر «أستطيع توفير هذا» يفتح نموذج العطاء بنفس التصنيف والخصائص الدقيقة ولا يضمن توجيه الشيء إلى صاحب البطاقة المعروضة
- مطابقة احتياج ↔ تبرع مع مراجعة بشرية
- مطابقة وقت/مهارة ↔ طلب خدمة مع موافقة الطرفين
- **شركاء عطاء** للمحلات والورش والصالونات والجهات بعد تحقق مستقل قبل السماح بعروض خدمة باسم النشاط
- شركاء V1 يقدمون خدمة مجانية أو عملًا مجانيًا مع المواد/القطع حسب الحالة المراجعة؛ لا أسعار مفتوحة أو مزايدة أو تفاوض
- سعة شهرية للشريك تدخل في التشغيل والترشيح ولا تتحول إلى ترتيب تجاري
- شروط أمان صريحة للشركاء: لا تصوير/تسويق، لا رسوم غير متفق عليها، لا اشتراط شراء خدمة أخرى، ولا استخدام بيانات المستفيد تجاريًا
- بلاغات خدمات خاصة بفريق عطاء بدل التقييمات العامة والنجوم
- إخفاء هوية المتبرع والمستفيد عن بعضهما في عمليات الأشياء
- الخدمات الحضورية تكشف فقط الحد الأدنى الضروري بعد الموافقة والتنسيق
- Courier Dispatch V2: إسناد المهمة كعرض ينتهي بعد 30 دقيقة، قبول أو اعتذار المندوب، ثم استلام وتسليم برمز PIN يصدره الطرف الآخر (صالح 10 دقائق وبحد 5 محاولات)، وبيانات اتصال تظهر للمندوب حسب المرحلة فقط
- مساهمات تشغيلية اختيارية مرتبطة بالعمليات
- Risk Flags ومراجعة يدوية للحالات المشبوهة، بما فيها كثافة طلبات غير اعتيادية دون عقوبة تلقائية
- تقارير أثر تشمل الأشياء المسلمة، تصنيفات V2، الخدمات المكتملة، ساعات الخدمة التقديرية، خدمات الشركاء، أثر بطاقات الاحتياج، وبلاغات السلامة
- لوحة إدارة وتشغيل ضمن نفس قاعدة البيانات
- مركز متابعة موحّد يعرض حالة العطاء والاحتياج والمطابقة والتوصيل والخدمات والخطوة التالية
- تنبيهات خاصة داخل التطبيق تُنشأ من تغيّرات الحالة الموثوقة مع صلاحية المستخدم للقراءة ووضع علامة «مقروء» فقط
- طابور أولوية إداري يرتب المخاطر والتعطل والعمليات المنتظرة دون كشف بيانات المستفيد الشخصية في الملخص
- مسار تأهيل ومخزون للأشياء غير الغذائية وغير الطبية: استلام ومستودع، فحص A–D، تنظيف أو إصلاح، جاهزية للتوزيع أو إعادة تدوير موثقة
- تكاليف التأهيل وعوائد التدوير تظهر للإدارة فقط، بينما يرى المتبرع حالة تشغيلية مختصرة ومحجوبة التفاصيل الداخلية

## Category System V2

الفئات الرئيسية الحالية:

1. ملابس وأحذية
2. أطفال وأمومة
3. تعليم ومدرسة
4. منزل وأثاث
5. أجهزة وإلكترونيات
6. أدوات ومهن
7. مناسبات وزواج
8. أخرى

أمثلة:

- `ملابس وأحذية → رجالي → ثوب / شمزان → مقاس 52`
- `تعليم ومدرسة → مستلزمات مدرسية → حقيبة مدرسية → الصف السادس`
- `أجهزة وإلكترونيات → أجهزة منزلية → مروحة → حالة التشغيل`
- `أدوات ومهن → خياطة → ماكينة خياطة`

الحقول المنظمة لا تلغي الوصف الحر؛ بل تقلل الغموض وتساعد المطابقة، بينما تبقى ملاحظات الحالة والخصوصية متاحة للفريق.

## Reviewed-needs discovery model

- المستخدم لا يتصفح التبرعات.
- المتبرع يستطيع رؤية بطاقات احتياج محايدة **راجعها فريق عطاء** فقط؛ هذه مراجعة تشغيلية وليست ادعاءً بتحقق مالي أو اجتماعي رسمي.
- لا أسماء، صور أشخاص، أرقام هواتف، عناوين دقيقة أو قصص شخصية حساسة في البطاقات.
- لا مراسلة مباشرة، حجز، مزايدة، أو First-come-first-served.
- استجابة المتبرع للبطاقة تسجّل فقط أن البطاقة ألهمت العطاء؛ المطابقة النهائية تبقى حسب الأولوية والملاءمة.
- بطاقات V2 تحمل التصنيف والنوع والخصائص المنظمة حتى ينتقل المتبرع مباشرة إلى نموذج عطاء دقيق.
- لا يظهر للمستخدم احتياجه هو ضمن شاشة التحفيز.
- بحد أقصى بطاقتان معروضتان في الوقت نفسه لكل حساب.
- البطاقة تختفي بمجرد دخول الاحتياج في عرض مطابقة خاص أو مرحلة تلبية لاحقة.
- أنماط الطلب غير المعتادة تولّد Risk Flags للمراجعة البشرية ولا تقلل الاستحقاق تلقائيًا.

## Verified Partner Services

- النشاط يسجّل ملف **شريك عطاء** منفصلًا عن الحساب الشخصي.
- قبول قواعد الأمان V1 إلزامي ومؤرخ من الخادم.
- فريق عطاء يعتمد أو يرفض أو يوقف الشريك.
- لا يستطيع أي نشاط إنشاء عرض تجاري باسم شريك غير موثّق.
- عروض الشركاء لا تظهر كإعلانات ولا توجد قائمة مستفيدين يتصفحها الشريك.
- الترشيح يراعي نوع الخدمة والمنطقة والوقت والسعة الشهرية المتبقية.
- يمكن لأي طرف في خدمة مطابقة رفع بلاغ خاص إلى فريق عطاء أثناء الخدمة أو بعدها.
- لا تقييمات عامة أو نجوم أو تعليقات تجارية.

## Supabase

Project ref: `vclicpejajxadsbuakdw`

لا يتم حفظ مفاتيح Supabase السرية داخل المستودع. استخدم متغيرات البيئة أو `--dart-define` للقيم العميلية المسموح بها.

سلسلة migrations تُفحص في CI للتأكد من عدم تكرار أرقام الإصدارات؛ لا تضف ملفين بنفس البادئة الرقمية. البادئات المقبولة: الشكل التسلسلي القديم `00NN_` أو الطابع الزمني من 14 رقمًا الذي يولده Supabase CLI. الترحيلات الجديدة تستخدم الطابع الزمني.

قاعدة الإنتاج لا تُحدَّث تلقائيًا من المستودع. قبل أي تطبيق: طابق السجل بـ`supabase migration list`، ولا تشغّل `db push` قبل حل الفروق (أرقام الإنتاج التاريخية تختلف عن بادئات الملفات المحلية).

## Release documentation

- [Android release signing and signed AAB](docs/ANDROID_RELEASE.md)
- [Google Play Data Safety source of truth](docs/PLAY_DATA_SAFETY.md)
- [Physical-device UAT for release identity, Category V2, services and partners](docs/UAT_CATEGORY_V2_PARTNERS.md)
- [Operations Center and admin-priority UAT](docs/UAT_OPERATIONS_CENTER.md)
- [Item recovery and inventory UAT](docs/UAT_ITEM_RECOVERY_INVENTORY.md)
- [Public Privacy Policy](site/privacy/index.html)
- [Public Terms of Use](site/terms/index.html)
- [Account deletion page](site/delete-account/index.html)
- `site/.well-known/assetlinks.json.template` is a template only; publish the real `assetlinks.json` after Google Play supplies the App Signing SHA-256.

- [October 2026 audit: what changed and the owner's manual console steps](docs/AUDIT_2026-10.md)
- [Delivery, donation and need state machines](docs/state-machines.md)
- [Time, skills and community resources model](docs/TIME_AND_SKILLS.md)
- [Why four names appear in this repository](docs/NAMING.md)

The manual `Android Release Bundle` workflow builds a signed, obfuscated AAB. It runs only from `main` or a `v*` tag, inside the GitHub Environment `release` (required reviewers), and stops early unless the signing secrets and the `SUPABASE_URL`, `SUPABASE_ANON_KEY` and `AUTH_REDIRECT_URL` variables are set. Signing secrets are never committed, and CI keeps signing passwords in the build environment rather than writing them to a plaintext `key.properties` file. There is no record of a signed production bundle yet.

## Repository structure

```text
app/                 Flutter Android app
supabase/
  migrations/        SQL schema and policies
  functions/         Edge Functions
  seed.sql           development seed data
site/                ruhamaa.com static site
tests/
  e2e/               isolated local-stack API, security and UI tests
  site/              static and browser checks for the site
tools/branding/      display-identity guard and migration tool
docs/                architecture and release documentation
```

## Core principles

1. الاحتياج أولًا، ولا توجد واجهة Marketplace.
2. عرض الاحتياجات للمتبرعين هو طبقة تحفيز من بطاقات راجعها عطاء، وليس وسيلة لاختيار المستفيد.
3. المتبرع والمستفيد لا يعرف أحدهما هوية الآخر في عمليات الأشياء.
4. Google Auth للمصادقة، وليس كإثبات هوية نهائي.
5. المساهمات التشغيلية أو تقديم الأشياء/الوقت/المهارات لا تعطي أولوية في الاستحقاق.
6. الحصول على مساعدة لا ينشئ دينًا أو التزامًا بالمقايضة.
7. الشريك التجاري لا يحصل على مساحة إعلان أو أولوية مقابل خدمته.
8. القرارات الحساسة أو عالية الخطورة تمر بمراجعة بشرية.
9. أقل قدر ضروري من البيانات يظهر للموصل أو مقدم الخدمة أثناء تنفيذ المهمة.
