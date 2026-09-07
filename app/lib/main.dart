import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/app.dart';
import 'src/features/intro/intro_screen.dart';
import 'src/theme/ruhamaa_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabasePublishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabasePublishableKey.isEmpty) {
    runApp(
      const ProviderScope(
        child: _StartupErrorApp(
          message: 'نسخة التطبيق الحالية غير مكتملة الإعداد. أعد تثبيت النسخة المعتمدة من رحماء.',
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
    debugPrint('Ruhamaa startup configuration error: $error');
    debugPrintStack(stackTrace: stackTrace);
    runApp(
      const ProviderScope(
        child: _StartupErrorApp(
          message: 'تعذر بدء رحماء بصورة صحيحة. تحقق من اتصالك ثم أعد فتح التطبيق.',
        ),
      ),
    );
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final introSeen = prefs.getBool(ruhamaaIntroSeenKey) ?? false;

  runApp(
    ProviderScope(
      child: RuhamaaApp(showIntro: !introSeen),
    ),
  );
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رحماء',
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
                      'تعذر بدء رحماء',
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
