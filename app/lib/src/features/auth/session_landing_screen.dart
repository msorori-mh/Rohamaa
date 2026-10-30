import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/account_repository.dart';
import '../../domain/account_state.dart';
import '../admin/admin_home_screen.dart';
import '../courier/courier_tasks_screen.dart';
import '../supervisor/supervisor_home_screen.dart';
import 'account_status_screens.dart';
import 'change_password_screen.dart';
import 'web_staff_only_screen.dart';

/// First screen after sign-in. Loads the account state once and sends the
/// person to the right place: staff screens by role, the forced password
/// change, a dedicated blocked-account screen, or the community home.
class SessionLandingScreen extends StatefulWidget {
  const SessionLandingScreen({super.key});

  @override
  State<SessionLandingScreen> createState() => _SessionLandingScreenState();
}

class _SessionLandingScreenState extends State<SessionLandingScreen> {
  AccountState? _state;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final state = await AccountRepository(Supabase.instance.client).myState();
      if (!mounted) return;
      setState(() {
        _state = state;
        _error = null;
        _loading = false;
      });
    } catch (error) {
      debugPrint('Ataa account state load failed: ${error.runtimeType}');
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _retry() {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final error = _error;
    final state = _state;
    if (error != null || state == null) {
      return AccountLoadErrorScreen(
        error: error ?? StateError('account state unavailable'),
        onRetry: _retry,
      );
    }
    final gate = state.gate;
    // Browser build: only staff may continue; everyone else is signed out.
    if (gate == AccountGate.community &&
        !state.isAllowedOnPlatform(isWeb: kIsWeb)) {
      return const WebStaffOnlyScreen();
    }
    return switch (gate) {
      AccountGate.suspended ||
      AccountGate.deletionProcessing ||
      AccountGate.deleted =>
        AccountBlockedScreen(gate: gate),
      AccountGate.passwordChange =>
        ChangePasswordScreen(role: state.role, onChanged: _retry),
      AccountGate.admin => const AdminHomeScreen(),
      AccountGate.supervisor => const SupervisorHomeScreen(),
      AccountGate.courier => const CourierTasksScreen(),
      AccountGate.community => const _CommunityHomeRedirect(),
    };
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
