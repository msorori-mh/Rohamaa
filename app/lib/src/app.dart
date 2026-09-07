import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/staff_repository.dart';
import 'features/admin/admin_home_screen.dart';
import 'features/auth/change_password_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/session_landing_screen.dart';
import 'features/courier/courier_tasks_screen.dart';
import 'features/donations/create_donation_screen.dart';
import 'features/handoffs/my_handoffs_screen.dart';
import 'features/home/home_screen.dart';
import 'features/legal/legal_screen.dart';
import 'features/needs/create_need_screen.dart';
import 'features/offers/match_offers_screen.dart';
import 'features/profile/onboarding_screen.dart';
import 'features/supervisor/supervisor_home_screen.dart';

class RuhamaaApp extends StatefulWidget {
  const RuhamaaApp({super.key});

  @override
  State<RuhamaaApp> createState() => _RuhamaaAppState();
}

class _RuhamaaAppState extends State<RuhamaaApp> {
  late final _AuthRefreshNotifier _authRefreshNotifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authRefreshNotifier = _AuthRefreshNotifier();
    _router = GoRouter(
      initialLocation: '/',
      refreshListenable: _authRefreshNotifier,
      redirect: (context, state) {
        final loggedIn = Supabase.instance.client.auth.currentSession != null;
        final isLogin = state.matchedLocation == '/login';
        final isPublicLegal = state.matchedLocation == '/legal';
        if (!loggedIn && !isLogin && !isPublicLegal) return '/login';
        if (loggedIn && isLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/legal', builder: (_, __) => const LegalScreen()),
        GoRoute(path: '/', builder: (_, __) => const SessionLandingScreen()),
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/donate', builder: (_, __) => const CreateDonationScreen()),
        GoRoute(path: '/need', builder: (_, __) => const CreateNeedScreen()),
        GoRoute(path: '/offers', builder: (_, __) => const MatchOffersScreen()),
        GoRoute(path: '/handoffs', builder: (_, __) => const MyHandoffsScreen()),
        GoRoute(path: '/courier', builder: (_, __) => const _RoleGate(requiredRole: 'courier', child: CourierTasksScreen())),
        GoRoute(path: '/supervisor', builder: (_, __) => const _RoleGate(requiredRole: 'supervisor', child: SupervisorHomeScreen())),
        GoRoute(path: '/admin', builder: (_, __) => const _RoleGate(requiredRole: 'admin', child: AdminHomeScreen())),
      ],
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _authRefreshNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'رحماء',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF226B5E),
        scaffoldBackgroundColor: const Color(0xFFF8FAF9),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      routerConfig: _router,
    );
  }
}

class _RoleGate extends StatelessWidget {
  const _RoleGate({required this.requiredRole, required this.child});
  final String requiredRole;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<StaffStatus>(
      future: StaffRepository(Supabase.instance.client).myStatus(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final status = snapshot.data;
        if (status == null || status.role != requiredRole) {
          return Scaffold(
            appBar: AppBar(title: const Text('رحماء')),
            body: const Center(child: Text('ليس لديك صلاحية للوصول إلى هذه الشاشة.')),
          );
        }
        if (status.forcePasswordChange) return ChangePasswordScreen(role: status.role);
        return child;
      },
    );
  }
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('Ruhamaa auth event: ${data.event}; session=${data.session != null}');
      notifyListeners();
    });
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
