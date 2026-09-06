import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data/admin_repository.dart';
import 'features/admin/admin_dashboard_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/courier/courier_tasks_screen.dart';
import 'features/donations/create_donation_screen.dart';
import 'features/handoffs/my_handoffs_screen.dart';
import 'features/home/home_screen.dart';
import 'features/needs/create_need_screen.dart';
import 'features/profile/onboarding_screen.dart';

class SanadApp extends StatelessWidget {
  const SanadApp({super.key});

  @override
  Widget build(BuildContext context) {
    final router = GoRouter(
      initialLocation: '/',
      refreshListenable: _AuthRefreshNotifier(),
      redirect: (context, state) {
        final loggedIn = Supabase.instance.client.auth.currentSession != null;
        final isLogin = state.matchedLocation == '/login';
        if (!loggedIn && !isLogin) return '/login';
        if (loggedIn && isLogin) return '/';
        return null;
      },
      routes: [
        GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
        GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
        GoRoute(path: '/donate', builder: (_, __) => const CreateDonationScreen()),
        GoRoute(path: '/need', builder: (_, __) => const CreateNeedScreen()),
        GoRoute(path: '/handoffs', builder: (_, __) => const MyHandoffsScreen()),
        GoRoute(path: '/courier', builder: (_, __) => const _RoleGate(requiredRole: 'courier', child: CourierTasksScreen())),
        GoRoute(path: '/admin', builder: (_, __) => const _RoleGate(requiredRole: 'admin', child: AdminDashboardScreen())),
      ],
    );

    return MaterialApp.router(
      title: 'سند',
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
      routerConfig: router,
    );
  }
}

class _RoleGate extends StatelessWidget {
  const _RoleGate({required this.requiredRole, required this.child});
  final String requiredRole;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: AdminRepository(Supabase.instance.client).myRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        if (snapshot.data != requiredRole) {
          return Scaffold(
            appBar: AppBar(title: const Text('سند')),
            body: const Center(child: Text('ليس لديك صلاحية للوصول إلى هذه الشاشة.')),
          );
        }
        return child;
      },
    );
  }
}

class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier() {
    Supabase.instance.client.auth.onAuthStateChange.listen((_) => notifyListeners());
  }
}
