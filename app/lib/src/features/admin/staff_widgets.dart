import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_error.dart';
import '../../theme/ruhamaa_theme.dart';

// Shared building blocks for the staff screens (admin, courier, supervisor,
// reports): a refreshable async body, a validated text dialog that owns its
// controllers, and small confirm/snack helpers.

/// Body for a screen backed by one future.
///
/// The [RefreshIndicator] stays mounted in every state, so pull-to-refresh
/// works on the empty and error states too, and a refresh keeps showing the
/// previous data instead of flashing a spinner. Load failures render as an
/// [ErrorRetry], never as an empty list.
class RefreshableFuture<T> extends StatelessWidget {
  const RefreshableFuture({
    super.key,
    required this.future,
    required this.onRefresh,
    required this.builder,
    this.isEmpty,
    this.emptyText = 'لا توجد بيانات لعرضها.',
  });

  final Future<T> future;

  /// Must not throw: reload, swap the future with `setState`, and swallow the
  /// error (this widget renders it).
  final Future<void> Function() onRefresh;

  /// Builds the loaded content; should return a scrollable widget.
  final Widget Function(BuildContext context, T data) builder;
  final bool Function(T data)? isEmpty;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: FutureBuilder<T>(
        future: future,
        builder: (context, snapshot) {
          final waiting = snapshot.connectionState != ConnectionState.done;
          if (waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!waiting && snapshot.hasError) {
            return ErrorRetry(
              error: snapshot.error!,
              onRetry: () {
                onRefresh();
              },
            );
          }
          final data = snapshot.data as T;
          final empty = isEmpty;
          if (empty != null && empty(data)) {
            return ScrollableEmpty(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  emptyText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: RuhamaaColors.textMuted,
                    height: 1.5,
                  ),
                ),
              ),
            );
          }
          return builder(context, data);
        },
      ),
    );
  }
}

/// Note shown under a list that was cut at the server-side limit.
class QueueLimitNote extends StatelessWidget {
  const QueueLimitNote({super.key, required this.limit});

  final int limit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Text(
        'تُعرض أقدم $limit عملية فقط. أنجز المعروض ثم حدّث القائمة لرؤية البقية.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: RuhamaaColors.textMuted, fontSize: 12),
      ),
    );
  }
}

/// One text input of a [TextFieldsDialog].
class DialogField {
  const DialogField({
    required this.id,
    required this.label,
    this.hint,
    this.helper,
    this.initialValue = '',
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.digitsOnly = false,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
    this.visible,
  });

  final String id;
  final String label;
  final String? hint;
  final String? helper;
  final String initialValue;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool digitsOnly;
  final TextCapitalization textCapitalization;

  /// Receives the trimmed text; returns an inline Arabic message or null.
  final String? Function(String value)? validator;

  /// When given and false, the field is hidden and not validated.
  final bool Function()? visible;
}

/// Dialog with validated text fields. It owns its controllers and disposes
/// them in [State.dispose], after the route has finished animating out, and
/// it shows validation messages inline instead of silently ignoring short
/// input. Pops with the trimmed values keyed by [DialogField.id].
class TextFieldsDialog extends StatefulWidget {
  const TextFieldsDialog({
    super.key,
    required this.title,
    required this.fields,
    this.intro,
    this.confirmLabel = 'تأكيد',
    this.cancelLabel = 'إلغاء',
    this.headerBuilder,
  });

  final String title;
  final List<DialogField> fields;
  final String? intro;
  final String confirmLabel;
  final String cancelLabel;

  /// Extra non-text inputs (dropdowns, segmented buttons) shown above the
  /// fields. Call the given setter to rebuild the dialog after a change.
  final Widget Function(BuildContext context, StateSetter setDialogState)?
      headerBuilder;

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String title,
    required List<DialogField> fields,
    String? intro,
    String confirmLabel = 'تأكيد',
    String cancelLabel = 'إلغاء',
    Widget Function(BuildContext context, StateSetter setDialogState)?
        headerBuilder,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => TextFieldsDialog(
        title: title,
        fields: fields,
        intro: intro,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        headerBuilder: headerBuilder,
      ),
    );
  }

  @override
  State<TextFieldsDialog> createState() => _TextFieldsDialogState();
}

class _TextFieldsDialogState extends State<TextFieldsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        field.id: TextEditingController(text: field.initialValue),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  bool _isVisible(DialogField field) {
    final visible = field.visible;
    return visible == null || visible();
  }

  void _rebuild(VoidCallback fn) {
    if (mounted) setState(fn);
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;
    Navigator.pop(context, {
      for (final entry in _controllers.entries)
        entry.key: entry.value.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.headerBuilder;
    final intro = widget.intro;
    final visibleFields = widget.fields.where(_isVisible).toList();
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (intro != null) ...[
                  Text(
                    intro,
                    style: const TextStyle(
                      color: RuhamaaColors.textMuted,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (header != null) ...[
                  header(context, _rebuild),
                  const SizedBox(height: 12),
                ],
                for (var i = 0; i < visibleFields.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  _buildField(visibleFields[i]),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.cancelLabel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  Widget _buildField(DialogField field) {
    final validator = field.validator;
    return TextFormField(
      controller: _controllers[field.id],
      maxLines: field.maxLines,
      maxLength: field.maxLength,
      keyboardType: field.keyboardType,
      textCapitalization: field.textCapitalization,
      inputFormatters: field.digitsOnly
          ? [FilteringTextInputFormatter.digitsOnly]
          : null,
      decoration: InputDecoration(
        labelText: field.label,
        hintText: field.hint,
        helperText: field.helper,
        helperMaxLines: 3,
        errorMaxLines: 3,
      ),
      validator: validator == null
          ? null
          : (value) => validator((value ?? '').trim()),
    );
  }
}

/// Validator for a required free-text reason/decision.
String? Function(String value) requiredText({
  int min = 3,
  String message = 'اكتب 3 أحرف على الأقل.',
}) {
  return (value) => value.length < min ? message : null;
}

/// Validator for an optional non-negative whole number.
String? optionalAmount(String value) {
  if (value.isEmpty) return null;
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) return 'أدخل رقمًا صحيحًا.';
  return null;
}

/// Asks for confirmation; resolves to true only on an explicit confirm.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'إلغاء',
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(cancelLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Shows a short success/info message when [context] is still mounted.
void showInfoSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Small spinner sized for buttons and list tiles.
class InlineSpinner extends StatelessWidget {
  const InlineSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
