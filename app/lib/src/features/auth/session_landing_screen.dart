import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/staff_repository.dart';
import '../admin/admin_home_screen.dart';
import '../courier/courier_tasks_screen.dart';
import '../supervisor/supervisor_home_screen.dart';
import 'change_password_screen.dart';

class SessionLandingScreen extends StatelessWidget {
  const SessionLandingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StaffStatus>(
      future: StaffRepository(Supabase.instance.client).myStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('رحماء')),
            body: Center(child: Text('تعذر التحقق من الحساب: ${snapshot.error}')),
          );
        }
        final status = snapshot.data ?? const StaffStatus(role: 'user', forcePasswordChange: false, isPrimaryAdmin: false);
        if (status.forcePasswordChange && ['admin', 'supervisor', 'courier'].contains(status.role)) {
          return ChangePasswordScreen(role: status.role);
        }
        return switch (status.role) {
          'admin' => const AdminHomeScreen(),
          'supervisor' => const SupervisorHomeScreen(),
          'courier' => const CourierTasksScreen(),
          _ => const _CommunityHomeRedirect(),
        };
      },
    );
  }
}

class _CommunityHomeRedirect extends StatefulWidget {
  const _CommunityHomeRedirect();

  @override
  State<_CommunityHomeRedirect> createState() => _CommunityHomeRedirectState();
}

class _CommunityHomeRedirectState extends State<_CommunityHomeRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.go('/home');
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
