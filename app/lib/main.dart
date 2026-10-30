import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/features/intro/intro_screen.dart';
import 'src/theme/ruhamaa_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _installErrorHandlers();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    runApp(
      const ProviderScope(
        child: _StartupErrorApp(
          message: kIsWeb
              ? 'إعداد بوابة فريق عطاء غير مكتمل. تواصل مع مسؤول النظام.'
              : 'نسخة التطبيق الحالية غير مكتملة الإعداد. أعد تثبيت النسخة المعتمدة من عطاء.',
        ),
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: supabaseUrl,
      publishableKey: supabasePublishableKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Ataa startup configuration error: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(
      const ProviderScope(
        child: _StartupErrorApp(
          message: 'تعذر بدء عطاء بصورة صحيحة. تحقق من اتصالك ثم أعد فتح التطبيق.',
        ),
      ),
    );
    return;
  }

  // If local preferences cannot be read, skip the intro rather than block
  // startup; it stays available from the account screen.
  var introSeen = true;
  try {
    final prefs = await SharedPreferences.getInstance();
    introSeen = prefs.getBool(ruhamaaIntroSeenKey) ?? false;
  } catch (error) {
    debugPrint('Ataa preferences unavailable: ${error.runtimeType}');
  }

  runApp(
    ProviderScope(
      child: RuhamaaApp(showIntro: !kIsWeb && !introSeen),
    ),
  );
}

/// Unexpected framework and platform errors are logged only. They are never
/// shown to the person as raw text and never rethrown, so one failing widget
/// or plugin callback cannot put the app into a crash loop.
void _installErrorHandlers() {
  FlutterError.onError = (details) {
    var presented = false;
    assert(() {
      // Full diagnostics in debug builds only.
      FlutterError.presentError(details);
      presented = true;
      return true;
    }());
    if (!presented) {
      debugPrint('Ataa framework error: ${details.exceptionAsString()}');
    }
  };
  ui.PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Ataa uncaught error: ${error.runtimeType}');
    assert(() {
      debugPrint('$error');
      debugPrintStack(stackTrace: stack);
      return true;
    }());
    return true;
  };
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'عطاء',
      debugShowCheckedModeBanner: false,
      theme: RuhamaaTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const RuhamaaBrandMark(size: 92),
                    const SizedBox(height: 22),
                    const Text(
                      'تعذر بدء عطاء',
                      style: TextStyle(
                        color: RuhamaaColors.primaryDark,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: RuhamaaColors.textMuted,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'support@ruhamaa.com',
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        color: RuhamaaColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
