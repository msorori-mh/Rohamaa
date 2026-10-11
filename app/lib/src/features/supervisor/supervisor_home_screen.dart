import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error.dart';
import '../../data/staff_repository.dart';
import '../admin/staff_widgets.dart';
import '../auth/change_password_screen.dart';
import '../reports/reports_screen.dart';

/// Home of an area supervisor. Server-side a supervisor is only authorised
/// for the scoped report RPCs and for reading their own area assignments, so
/// this screen deliberately offers reports only and no admin tools.
class SupervisorHomeScreen extends StatefulWidget {
  const SupervisorHomeScreen({super.key});

  @override
  State<SupervisorHomeScreen> createState() => _SupervisorHomeScreenState();
}

class _SupervisorHomeScreenState extends State<SupervisorHomeScreen> {
  List<Map<String, dynamic>>? _areas;
  Object? _areasError;
  bool _signingOut = false;

  @override
  void initState() {
    super.initState();
    _fetchAreas();
  }

  Future<void> _fetchAreas() async {
    try {
      final areas =
          await StaffRepository(Supabase.instance.client).myAssignedAreas();
      if (!mounted) return;
      setState(() {
        _areas = areas;
        _areasError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _areasError = error);
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    final confirmed = await confirmAction(
      context,
      title: 'تسجيل الخروج؟',
      message: 'سيتم إنهاء جلسة المشرف على هذا الجهاز.',
      confirmLabel: 'تسجيل الخروج',
    );
    if (!confirmed || !mounted) return;
    setState(() => _signingOut = true);
    try {
      await Supabase.instance.client.auth.signOut();
    } catch (error) {
      if (mounted) showErrorSnack(context, error);
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  Widget _areasCard() {
    final areas = _areas;
    final error = _areasError;
    final Widget body;
    if (error != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(friendlyError(error)),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _fetchAreas,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      );
    } else if (areas == null) {
      body = const LinearProgressIndicator();
    } else if (areas.isEmpty) {
      body = const Text(
        'لم تُسند إلى حسابك أي مدينة أو منطقة بعد، لذلك ستظهر التقارير فارغة. تواصل مع إدارة عطاء لإسناد نطاقك.',
        style: TextStyle(height: 1.5),
      );
    } else {
      body = Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final area in areas)
            Chip(
              avatar: Icon(
                area['kind'] == 'city'
                    ? Icons.location_city_outlined
                    : Icons.place_outlined,
                size: 18,
              ),
              label: Text('${area['name_ar']}'),
            ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'النطاقات المسندة إليك',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            body,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إشراف عطاء'),
        actions: [
          IconButton(
            tooltip: 'تغيير كلمة المرور',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ChangePasswordScreen(
                  role: 'supervisor',
                  requiredChange: false,
                ),
              ),
            ),
            icon: const Icon(Icons.password_outlined),
          ),
          IconButton(
            tooltip: 'تسجيل الخروج',
            onPressed: _signingOut ? null : _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAreas,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'لوحة مشرف المنطقة',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'دورك متابعة أرقام التشغيل ضمن المدينة أو المناطق المسندة إلى حسابك. '
              'المطابقة والإسناد ومراجعة البلاغات تتم من حساب الإدارة.',
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 20),
            _areasCard(),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.analytics_outlined),
                title: const Text('التقارير الأساسية'),
                subtitle: const Text(
                  'الأثر، التوصيل، أداء الموصلين والمصروفات ضمن نطاقك.',
                ),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const ReportsScreen(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
