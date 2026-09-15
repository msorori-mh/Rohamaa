import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/contribution_repository.dart';
import '../../theme/ruhamaa_theme.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key, this.donationId, this.needId, this.deliveryId});

  final String? donationId;
  final String? needId;
  final String? deliveryId;

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  int? _amount;
  bool _saving = false;

  static const amounts = [1000, 2000, 3000, 4000, 5000];

  String get _intro {
    if (widget.donationId != null) {
      return 'تبرعك هو الأساس. إن استطعت، تساعد مساهمتك في تكلفة استلامه وتوصيله.';
    }
    if (widget.needId != null) {
      return 'طلبك مستمر سواء ساهمت أم لا. إن استطعت، تساعد مساهمتك في استمرار خدمة التوصيل.';
    }
    return 'مساهمتك تساعد على تغطية تكلفة التوصيل واستمرار الخدمة.';
  }

  String get _cashTiming {
    if (widget.donationId != null) return 'عند استلام التبرع منك';
    if (widget.needId != null) return 'عند توصيل الشيء إليك';
    return 'عند الاستلام أو التوصيل';
  }

  Future<void> _submit() async {
    if (_amount == null) return;
    setState(() => _saving = true);
    try {
      await ContributionRepository(Supabase.instance.client).createContribution(
        amountYer: _amount!,
        donationId: widget.donationId,
        needId: widget.needId,
        deliveryId: widget.deliveryId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'شكرًا لك. سُجلت رغبتك بالمساهمة بمبلغ $_amount ريال، ويُسلَّم نقدًا لموصل رحماء $_cashTiming.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر تسجيل المساهمة. تحقق من اتصالك وحاول مرة أخرى.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('المساهمة في التوصيل')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [RuhamaaColors.warmGoldSoft, RuhamaaColors.softGreen],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: const Column(
              children: [
                Icon(Icons.volunteer_activism_rounded, size: 54, color: RuhamaaColors.primary),
                SizedBox(height: 10),
                Text(
                  'المساهمة اختيارية تمامًا',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: RuhamaaColors.primaryDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'عدم المساهمة لا يمنع الخدمة ولا يغيّر أولوية طلبك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _intro,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.65),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: RuhamaaColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.payments_outlined, color: RuhamaaColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'لا يوجد دفع أو تحويل داخل التطبيق. إذا اخترت المساهمة، سلّم المبلغ نقدًا لموصل رحماء $_cashTiming.',
                    style: const TextStyle(color: RuhamaaColors.primaryDark, height: 1.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'اختر المبلغ الذي يناسبك',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: RuhamaaColors.primaryDark,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: amounts.map((amount) {
              return ChoiceChip(
                label: Text('$amount ريال'),
                selected: _amount == amount,
                onSelected: (_) => setState(() => _amount = amount),
              );
            }).toList(),
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _saving || _amount == null ? null : _submit,
            icon: const Icon(Icons.favorite_outline_rounded),
            label: Text(
              _saving
                  ? 'جارٍ التسجيل...'
                  : _amount == null
                      ? 'اختر مبلغ المساهمة'
                      : 'أسجّل رغبتي بالمساهمة بـ $_amount ريال',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'المساهمة اختيارية، وتُسجّل بعد تسليمها نقدًا للموصل.',
            textAlign: TextAlign.center,
            style: TextStyle(color: RuhamaaColors.textMuted, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}
