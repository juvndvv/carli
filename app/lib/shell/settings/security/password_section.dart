import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/card.dart';
import '../../../ui/field.dart';
import '../../../ui/toast.dart';
import 'data/security_repository.dart';

const minimumPasswordLength = 8;

String? passwordChangeProblem({required String current, required String password, required String confirmation}) {
  if (current.isEmpty || password.length < minimumPasswordLength || confirmation.isEmpty) {
    return 'Rellena los tres campos; la nueva contraseña debe tener al menos 8 caracteres.';
  }
  if (password != confirmation) return 'Las contraseñas nuevas no coinciden.';
  return null;
}

class ChangePasswordCard extends ConsumerStatefulWidget {
  const ChangePasswordCard({super.key});

  @override
  ConsumerState<ChangePasswordCard> createState() => _ChangePasswordCardState();
}

class _ChangePasswordCardState extends ConsumerState<ChangePasswordCard> {
  final _current = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final problem = passwordChangeProblem(
      current: _current.text,
      password: _password.text,
      confirmation: _confirmation.text,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(securityRepositoryProvider)
          .updatePassword(currentPassword: _current.text, password: _password.text, confirmation: _confirmation.text);
      for (final controller in [_current, _password, _confirmation]) {
        controller.clear();
      }
      ref.read(toastControllerProvider.notifier).show('Contraseña actualizada');
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido cambiar la contraseña.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changed(String _) {
    if (_error != null) setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    return CarliCard(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CarliSpace.s16,
          children: [
            CarliField(
              label: 'Contraseña actual',
              child: CarliInput(
                controller: _current,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                textInputAction: TextInputAction.next,
                onChanged: _changed,
              ),
            ),
            CarliField(
              label: 'Nueva contraseña',
              hint: 'Mínimo 8 caracteres.',
              child: CarliInput(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                onChanged: _changed,
              ),
            ),
            CarliField(
              label: 'Repite la nueva contraseña',
              child: CarliInput(
                controller: _confirmation,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.done,
                onChanged: _changed,
                onSubmitted: (_) => _save(),
              ),
            ),
            if (_error case final error?)
              Semantics(
                liveRegion: true,
                child: Text(error, style: CarliType.small.copyWith(color: context.colors.negative)),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: CarliButton(
                label: 'Cambiar contraseña',
                size: CarliButtonSize.md,
                block: false,
                loading: _saving,
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
