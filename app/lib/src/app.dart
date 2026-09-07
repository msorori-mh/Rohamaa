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
import 'features/donations/create_donation_v2_screen.dart';
import 'features/handoffs/my_handoffs_screen.dart';
import 'features/home/home_screen.dart';
import 'features/intro/intro_screen.dart';
import 'features/legal/legal_screen.dart';
import 'features/needs/create_need_v2_screen.dart';
import 'features/needs/need_discovery_screen.dart';
import 'features/offers/match_offers_screen.dart';
import 'features/profile/account_screen.dart';
import 'features/profile/onboarding_screen.dart';
import 'features/services/create_service_offer_screen.dart';
import 'features/services/create_service_request_screen.dart';
import 'features/services/my_services_screen.dart';
import 'features/supervisor/supervisor_home_screen.dart';
import 'theme/ruhamaa_theme.dart';

class RuhamaaApp extends StatefulWidget {
  const RuhamaaApp({super.key, this.showIntro = false});

  final bool showIntro;

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
      initialLocation: widget.showIntro ? '/intro' : '/',
      refreshListenable: _authRefreshNotifier,
      redirect: (context, state) {
        final loggedIn = Supabase.instance.client.auth.currentSession != null;
        final isLogin = state.matchedLocation == '/login';
        final isIntro = state.matchedLocation == '/intro';
        final isPublicLegal = state.matchedLocation == '/legal';
        if (!loggedIn && !isLogin && !isIntro && !isPublicLegal) return '/login';
        if (loggedIn && isLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/legal', builder: (_, __) => const LegalScreen()),
        GoRoute(path: '/', builder: (_, __) => const SessionLandingScreen()),
        ShellRoute(
          builder: (context, state, child) => _MainNavigationShell(
            location: state.matchedLocation,
            child: child,
          ),
          routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
            GoRoute(path: '/offers', builder: (_, __) => const MatchOffersScreen()),
            GoRoute(path: '/handoffs', builder: (_, __) => const MyHandoffsScreen()),
            GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
          ],
        ),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(
          path: '/donate',
          builder: (_, state) {
            final extra = state.extra;
            final data = extra is Map<String, dynamic> ? extra : const <String, dynamic>{};
            final rawAttributes = data['attributes'];
            final attributes = rawAttributes is Map
                ? rawAttributes.map((key, value) => MapEntry('$key', '$value')).cast<String, String>()
                : null;
            return CreateDonationV2Screen(
              prefillCategory: data['category'] as String?,
              prefillGroup: data['categoryGroup'] as String?,
              prefillItemTypeKey: data['itemTypeKey'] as String?,
              prefillTitle: data['title'] as String?,
              prefillAttributes: attributes,
              inspiredByDiscoveryCardId: data['discoveryCardId'] as String?,
            );
          },
        ),
        GoRoute(path: '/need', builder: (_, __) => const CreateNeedV2Screen()),
        GoRoute(path: '/verified-needs', builder: (_, __) => const NeedDiscoveryScreen()),
        GoRoute(path: '/offer-service', builder: (_, __) => const CreateServiceOfferScreen()),
        GoRoute(path: '/request-service', builder: (_, __) => const CreateServiceRequestScreen()),
        GoRoute(path: '/my-services', builder: (_, __) => const MyServicesScreen()),
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
      theme: RuhamaaTheme.light(),
      routerConfig: _router,
    );
  }
}

class _MainNavigationShell extends StatelessWidget {
  const _MainNavigationShell({required this.location, required this.child});

  final String location;
  final Widget child;

  int get _selectedIndex {
    if (location.startsWith('/offers')) return 1;
    if (location.startsWith('/handoffs')) return 2;
    if (location.startsWith('/account')) return 3;
    return 0;
  }

  void _go(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/offers');
      case 2:
        context.go('/handoffs');
      case 3:
        context.go('/account');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => _go(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_alt_outlined),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: 'المطابقات',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'عملياتي',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'حسابي',
          ),
        ],
      ),
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
