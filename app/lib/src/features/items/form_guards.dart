import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Asks before leaving a form that has entered data.
/// Returns true when the person chose to discard the changes.
Future<bool> confirmDiscardChanges(BuildContext context) async {
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('تجاهل التغييرات؟'),
      content: const Text('ستفقد البيانات التي أدخلتها في هذه الصفحة.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('متابعة التعبئة'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('تجاهل'),
        ),
      ],
    ),
  );
  return discard == true;
}

/// Generic yes/no confirmation. Returns true only when confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'تراجع',
  Key? confirmKey,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          key: confirmKey,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Shows a short message, replacing any snackbar that is still visible.
void showInfoSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Leaves the current form screen. Falls back to the home screen when the
/// form is the only page (opened by a direct link), where there is nothing
/// to pop.
void leaveForm(BuildContext context) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
  } else {
    GoRouter.of(context).go('/home');
  }
}
