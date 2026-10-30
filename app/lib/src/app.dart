import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth_callback_error.dart';
import 'core/main_tab_signal.dart';
import 'data/account_repository.dart';
import 'domain/account_state.dart';
import 'features/admin/admin_home_screen.dart';
import 'features/auth/account_status_screens.dart';
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
import 'features/partners/partner_hub_v2_screen.dart';
import 'features/profile/account_screen.dart';
import 'features/profile/onboarding_screen.dart';
import 'features/services/create_personal_service_offer_screen.dart';
import 'features/services/create_service_request_screen.dart';
import 'features/services/my_services_screen.dart';
import 'features/supervisor/supervisor_home_screen.dart';
import 'theme/ruhamaa_theme.dart';

/// Routes the browser build may show. Everything else (donations, needs,
/// offers, partners, community tabs) redirects away on the web.
const Set<String> _webStaffLocations = <String>{
  '/',
  '/login',
  '/login-callback',
  '/legal',
  '/admin',
  '/supervisor',
  '/courier',
};

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
        // Browser build: staff area only. Community screens are unreachable.
        if (kIsWeb && !_webStaffLocations.contains(state.matchedLocation)) {
          return loggedIn ? '/' : '/login';
        }
        if (!loggedIn && !isLogin && !isIntro && !isPublicLegal) return '/login';
        if (loggedIn && isLogin) return '/';
        return null;
      },
      errorBuilder: (_, __) => const _NotFoundScreen(),
      routes: [
        GoRoute(path: '/intro', builder: (_, __) => const IntroScreen()),
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        // The OAuth deep link (com.ruhamaa.app://login-callback) is consumed
        // by Supabase; the router only needs to land somewhere valid.
        GoRoute(path: '/login-callback', redirect: (_, __) => '/'),
        GoRoute(path: '/legal', builder: (_, __) => const LegalScreen()),
        GoRoute(path: '/', builder: (_, __) => const SessionLandingScreen()),
        // Each bottom-navigation tab keeps its own state while hidden.
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => _MainNavigationShell(
            navigationShell: navigationShell,
          ),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/offers',
                  builder: (_, state) => MatchOffersScreen(
                    initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
                    tabRequestId: state.uri.queryParameters['t'],
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/handoffs',
                  builder: (_, state) => MyHandoffsScreen(
                    initialTab: int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0,
                    tabRequestId: state.uri.queryParameters['t'],
                  ),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/account', builder: (_, __) => const AccountScreen()),
              ],
            ),
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
              prefillTitle: data['title'] as String?,
              prefillAttributes: attributes,
              inspiredByDiscoveryCardId: data['discoveryCardId'] as String?,
            );
          },
        ),
        GoRoute(path: '/need', builder: (_, __) => const CreateNeedV2Screen()),
        GoRoute(path: '/verified-needs', builder: (_, __) => const NeedDiscoveryScreen()),
        GoRoute(path: '/offer-service', builder: (_, __) => const CreatePersonalServiceOfferScreen()),
        GoRoute(path: '/request-service', builder: (_, __) => const CreateServiceRequestScreen()),
        GoRoute(path: '/my-services', builder: (_, __) => const MyServicesScreen()),
        GoRoute(path: '/partners', builder: (_, __) => const PartnerHubV2Screen()),
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
      title: 'عطاء',
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

class _MainNavigationShell extends StatefulWidget {
  const _MainNavigationShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<_MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<_MainNavigationShell> {
  @override
  void initState() {
    super.initState();
    _announceActiveTab();
  }

  @override
  void didUpdateWidget(covariant _MainNavigationShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _announceActiveTab();
  }

  /// Tells the tab screens which tab is visible so the one that just became
  /// active can refresh its data. Deferred: listeners call setState.
  void _announceActiveTab() {
    final index = widget.navigationShell.currentIndex;
    if (MainTabs.active.value == index) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MainTabs.active.value = widget.navigationShell.currentIndex;
    });
  }

  void _go(int index) {
    final shell = widget.navigationShell;
    // Tapping the active tab again returns it to its first screen.
    shell.goBranch(index, initialLocation: index == shell.currentIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFECE6D9))),
        ),
        child: NavigationBar(
          selectedIndex: widget.navigationShell.currentIndex,
          onDestinationSelected: _go,
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.inbox_outlined), selectedIcon: Icon(Icons.inbox_rounded), label: 'العروض'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long_rounded), label: 'المتابعة'),
            NavigationDestination(icon: Icon(Icons.person_outline_rounded), selectedIcon: Icon(Icons.person_rounded), label: 'حسابي'),
          ],
        ),
      ),
    );
  }
}

/// Guards a staff route. Loads the account state once; a network failure
/// shows a retry screen, never a "no permission" message.
class _RoleGate extends StatefulWidget {
  const _RoleGate({required this.requiredRole, required this.child});
  final String requiredRole;
  final Widget child;

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
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
      debugPrint('Ataa role gate load failed: ${error.runtimeType}');
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
    if (state.isBlocked) return AccountBlockedScreen(gate: state.gate);
    if (state.role != widget.requiredRole) return const _NoPermissionScreen();
    if (state.forcePasswordChange) {
      return ChangePasswordScreen(role: state.role, onChanged: _retry);
    }
    return widget.child;
  }
}

class _NoPermissionScreen extends StatelessWidget {
  const _NoPermissionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عطاء')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 48, color: RuhamaaColors.textMuted),
              const SizedBox(height: 12),
              const Text(
                'ليس لديك صلاحية للوصول إلى هذه الشاشة.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('العودة للرئيسية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('عطاء')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 52, color: RuhamaaColors.textMuted),
              const SizedBox(height: 12),
              Text(
                'الصفحة غير موجودة',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: RuhamaaColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'ربما تغيّر الرابط أو لم يعد متاحًا. يمكنك العودة إلى الصفحة الرئيسية.',
                textAlign: TextAlign.center,
                style: TextStyle(color: RuhamaaColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('not-found-go-home'),
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('العودة للرئيسية'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    _loggedIn = Supabase.instance.client.auth.currentSession != null;
    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('Ataa auth event: ${data.event}; session=${data.session != null}');
      final loggedIn = data.session != null;
      if (loggedIn) AuthCallbackError.last.value = null;
      if (loggedIn == _loggedIn) return;
      _loggedIn = loggedIn;
      if (_notificationScheduled) return;
      _notificationScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notificationScheduled = false;
        if (!_disposed) notifyListeners();
      });
    }, onError: (Object error) {
      // A failed OAuth callback arrives here as a stream error. Keep it for
      // the login screen, which may not be on screen yet.
      debugPrint('Ataa auth callback failed: ${error.runtimeType}');
      if (!_disposed) AuthCallbackError.last.value = error;
    });
  }

  late final StreamSubscription<AuthState> _subscription;
  late bool _loggedIn;
  bool _notificationScheduled = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _subscription.cancel();
    super.dispose();
  }
}
