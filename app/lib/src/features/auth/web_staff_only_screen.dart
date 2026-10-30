import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/web_staff_notice.dart';
import '../../data/handoff_repository.dart';
import '../../theme/ruhamaa_theme.dart';
import 'account_status_screens.dart';

/// Browser build only: shown for a signed-in account without a staff role.
///
/// It signs the person out right away; the router then returns to the login
/// screen, which repeats the message. If the sign-out call fails the person
/// still sees this screen with an explicit sign-out button, never community
/// screens.
class WebStaffOnlyScreen extends StatefulWidget {
  const WebStaffOnlyScreen({super.key, this.autoSignOut = true});

  /// Disabled in widget tests, which run without a Supabase client.
  final bool autoSignOut;

  @override
  State<WebStaffOnlyScreen> createState() => _WebStaffOnlyScreenState();
}

class _WebStaffOnlyScreenState extends State<WebStaffOnlyScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.autoSignOut) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _signOut());
    }
  }

  Future<void> _signOut() async {
    WebStaffNotice.message.value = WebStaffNotice.notStaffMessage;
    try {
      await Supabase.instance.client.auth.signOut();
      HandoffRepository.clearIssuedPins();
    } catch (error) {
      debugPrint('Ataa web staff-only sign-out failed: ${error.runtimeType}');
      if (signedOutDespiteError()) HandoffRepository.clearIssuedPins();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  size: 64,
                  color: RuhamaaColors.warmGold,
                ),
                const SizedBox(height: 18),
                Text(
                  'هذه البوابة لفريق عطاء فقط',
                  key: const Key('web-staff-only-title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: RuhamaaColors.primaryDark,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 10),
                const Text(
                  WebStaffNotice.notStaffMessage,
                  key: Key('web-staff-only-body'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: RuhamaaColors.textMuted, height: 1.6),
                ),
                const SizedBox(height: 22),
                const SignOutButton(filled: true),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
