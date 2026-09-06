import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/contribution_repository.dart';

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
      return 'تبرعك بالشيء هو الأساس. وإذا استطعت، فمساهمتك في تكلفة استلامه وتوصيله تساعد رحماء على إيصال عطائك، وما يتوفر من المساهمات يدعم توصيلات أخرى لأشخاص لا يستطيعون تحمل التكلفة.';
    }
    if (widget.needId != null) {
      return 'طلبك مستمر سواء ساهمت أم لا. إن كان بإمكانك المساهمة بجزء من تكلفة التوصيل، فأنت تساعد على استمرار الخدمة وتدعم أيضًا وصول احتياجات أخرى لمن لا يستطيعون المساهمة.';
    }
    return 'مساهمتك تساعد رحماء في تغطية تكاليف التوصيل واستمرار إيصال الأشياء إلى مستحقيها، بما في ذلك من لا يستطيعون تحمل تكلفة التوصيل.';
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
            'شكرًا لك. سُجلت رغبتك بالمساهمة بمبلغ $_amount ريال، ويُسلَّم نقدًا لمندوب رحماء $_cashTiming.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر تسجيل المساهمة: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ساهم في وصول الخير')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            _intro,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.payments_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'لا يوجد دفع أو تحويل داخل التطبيق. إذا اخترت المساهمة، سلّم المبلغ نقدًا لمندوب رحماء $_cashTiming. المساهمة اختيارية تمامًا، وعدم القدرة عليها لا يمنع الخدمة ولا يقلل أولوية الاستحقاق.',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'اختر المبلغ الذي يناسبك',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saving || _amount == null ? null : _submit,
            icon: const Icon(Icons.volunteer_activism_outlined),
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
            'المبلغ المختار هو رغبة بالمساهمة وليس شرطًا لإتمام التبرع أو الطلب. يتم اعتماد المساهمة فقط بعد استلامها نقدًا.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}
