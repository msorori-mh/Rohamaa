import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/ruhamaa_theme.dart';

const ruhamaaIntroSeenKey = 'ruhamaa_intro_seen_v2';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _finishing = false;

  static const _pages = <_IntroPageData>[
    _IntroPageData(
      icon: Icons.volunteer_activism_rounded,
      title: 'مرحبًا بك في رحماء',
      body: 'تبرّع بشيء أو بوقتك ومهارتك، أو اطلب ما تحتاجه. يتولى رحماء المراجعة والتنسيق بخصوصية.',
      accent: RuhamaaColors.primary,
      footer: 'ما لا تحتاجه قد ينفع شخصًا آخر.',
    ),
    _IntroPageData(
      icon: Icons.route_rounded,
      title: 'كيف يعمل رحماء؟',
      body: 'أخبرنا بما تقدمه أو تحتاجه، وسنبحث عن العرض المناسب دون عرض بيانات الأشخاص للعامة.',
      accent: RuhamaaColors.warmGold,
      steps: [
        ('1', 'سجّل ما تقدمه أو ما تحتاجه'),
        ('2', 'يراجع الفريق الطلب ويبحث عن عرض مناسب'),
        ('3', 'ننسّق الاستلام والتسليم أو موعد الخدمة'),
      ],
    ),
    _IntroPageData(
      icon: Icons.shield_rounded,
      title: 'الخصوصية أولًا',
      body: 'لا نعرض هويتك أو عنوانك للطرف الآخر. في الخدمات الحضورية نشارك المعلومات الضرورية فقط، وبعد موافقة الطرفين.',
      accent: RuhamaaColors.primaryDark,
      footer: 'لا تظهر طلباتك أو خدماتك للعامة.',
    ),
    _IntroPageData(
      icon: Icons.local_shipping_rounded,
      title: 'المساهمة في التوصيل اختيارية',
      body: 'يمكنك، إن استطعت، المساهمة في تكلفة الاستلام أو التسليم. تساعد مساهمتك على استمرار خدمة التوصيل.',
      accent: RuhamaaColors.warmGold,
      contribution: true,
      footer: 'المساهمة اختيارية ونقدية فقط، ولا تؤثر في قبول طلبك أو أولويته.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(ruhamaaIntroSeenKey, true);
    if (!mounted) return;
    final loggedIn = Supabase.instance.client.auth.currentSession != null;
    context.go(loggedIn ? '/account' : '/login');
  }

  Future<void> _next() async {
    if (_page == _pages.length - 1) {
      await _finish();
      return;
    }
    await _controller.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'رحماء',
                    style: TextStyle(
                      color: RuhamaaColors.primaryDark,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finishing ? null : _finish,
                    child: const Text('تخطي'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _IntroCard(data: _pages[index]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: index == _page ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _page
                              ? RuhamaaColors.primary
                              : RuhamaaColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _finishing ? null : _next,
                    icon: _finishing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(isLast ? Icons.arrow_back_rounded : Icons.chevron_left_rounded),
                    label: Text(
                      _finishing
                          ? 'جارٍ البدء...'
                          : isLast
                              ? 'ابدأ الآن'
                              : 'التالي',
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'يمكنك مراجعة هذه المعلومات لاحقًا من «حسابي».',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: RuhamaaColors.textMuted,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.data});

  final _IntroPageData data;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 12),
      children: [
        Container(
          height: 285,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                data.accent.withValues(alpha: 0.16),
                RuhamaaColors.warmSurface,
              ],
            ),
            border: Border.all(color: RuhamaaColors.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                top: 26,
                right: 26,
                child: Icon(
                  Icons.eco_rounded,
                  color: RuhamaaColors.primary.withValues(alpha: 0.28),
                  size: 74,
                ),
              ),
              Positioned(
                bottom: 24,
                left: 24,
                child: Icon(
                  Icons.favorite_rounded,
                  color: RuhamaaColors.warmGold.withValues(alpha: 0.30),
                  size: 62,
                ),
              ),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.88),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                      color: data.accent.withValues(alpha: 0.12),
                    ),
                  ],
                ),
                child: Icon(data.icon, size: 68, color: data.accent),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: RuhamaaColors.primaryDark,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 12),
        Text(
          data.body,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                height: 1.7,
                color: RuhamaaColors.textMuted,
              ),
        ),
        if (data.steps case final steps?) ...[
          const SizedBox(height: 22),
          ...steps.map(
            (step) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _StepTile(number: step.$1, label: step.$2),
            ),
          ),
        ],
        if (data.contribution) ...[
          const SizedBox(height: 22),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _AmountPill('1000'),
              _AmountPill('2000'),
              _AmountPill('3000'),
              _AmountPill('4000'),
              _AmountPill('5000'),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'ريال يمني — اختر فقط إن رغبت بالمساهمة',
            textAlign: TextAlign.center,
            style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
          ),
        ],
        if (data.footer case final footer?) ...[
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: RuhamaaColors.softGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              footer,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: RuhamaaColors.primaryDark,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RuhamaaColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: RuhamaaColors.softGreen,
            foregroundColor: RuhamaaColors.primaryDark,
            child: Text(number, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _AmountPill extends StatelessWidget {
  const _AmountPill(this.amount);

  final String amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: RuhamaaColors.warmGoldSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: RuhamaaColors.warmGold.withValues(alpha: 0.32)),
      ),
      child: Text(
        amount,
        style: const TextStyle(
          color: RuhamaaColors.primaryDark,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IntroPageData {
  const _IntroPageData({
    required this.icon,
    required this.title,
    required this.body,
    required this.accent,
    this.steps,
    this.footer,
    this.contribution = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color accent;
  final List<(String, String)>? steps;
  final String? footer;
  final bool contribution;
}
