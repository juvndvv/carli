import 'package:flutter/material.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/field.dart';
import '../../../ui/sheet.dart';

typedef PasswordAction<T> = Future<T> Function(String password);

Future<T?> showPasswordPrompt<T>(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required PasswordAction<T> action,
  bool destructive = false,
}) async {
  final outcome = await showCarliSheet<_PromptOutcome<T>>(
    context,
    title: title,
    builder: (context) =>
        PasswordPromptSheet<T>(message: message, confirmLabel: confirmLabel, destructive: destructive, action: action),
  );
  return outcome?.value;
}

class _PromptOutcome<T> {
  const _PromptOutcome(this.value);

  final T value;
}

class PasswordPromptSheet<T> extends StatefulWidget {
  const PasswordPromptSheet({
    super.key,
    required this.message,
    required this.confirmLabel,
    required this.action,
    this.destructive = false,
  });

  final String message;
  final String confirmLabel;
  final PasswordAction<T> action;
  final bool destructive;

  @override
  State<PasswordPromptSheet<T>> createState() => _PasswordPromptSheetState<T>();
}

class _PasswordPromptSheetState<T> extends State<PasswordPromptSheet<T>> {
  final _password = TextEditingController();
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final password = _password.text;
    if (password.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final value = await widget.action(password);
      if (mounted) Navigator.of(context).pop(_PromptOutcome<T>(value));
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(error, fallback: 'Algo ha fallado. Inténtalo de nuevo.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Text(widget.message, style: CarliType.small.copyWith(color: colors.text2)),
          CarliField(
            label: 'Contraseña',
            error: _error,
            child: CarliInput(
              controller: _password,
              obscureText: true,
              autofocus: true,
              invalid: _error != null,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
            ),
          ),
          Row(
            spacing: CarliSpace.s8,
            children: [
              Expanded(
                child: CarliButton(
                  label: 'Cancelar',
                  variant: CarliButtonVariant.ghost,
                  size: CarliButtonSize.md,
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: CarliButton(
                  label: widget.confirmLabel,
                  variant: widget.destructive ? CarliButtonVariant.danger : CarliButtonVariant.primary,
                  size: CarliButtonSize.md,
                  loading: _busy,
                  onPressed: _password.text.isEmpty ? null : _submit,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
