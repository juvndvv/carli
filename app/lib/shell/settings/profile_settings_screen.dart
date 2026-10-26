import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/current_user.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/avatar.dart';
import '../../ui/button.dart';
import '../../ui/card.dart';
import '../../ui/field.dart';
import '../../ui/page.dart';
import '../../ui/toast.dart';
import 'profile_repository.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidProfile({required String name, required String email}) =>
    name.trim().isNotEmpty && _emailPattern.hasMatch(email.trim());

class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth is SignedIn ? auth.user : null;
    return CarliPage(
      title: 'Perfil',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(CarliSpace.s16),
          sliver: SliverToBoxAdapter(
            child: CarliCard(child: user == null ? const _ProfileUnavailable() : ProfileForm(user: user)),
          ),
        ),
      ],
    );
  }
}

class _ProfileUnavailable extends StatelessWidget {
  const _ProfileUnavailable();

  @override
  Widget build(BuildContext context) => Text(
    'No se ha podido cargar tu perfil. Comprueba la conexión.',
    style: CarliType.small.copyWith(color: context.colors.text2),
  );
}

class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, required this.user});

  final CurrentUser user;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  late final _name = TextEditingController(text: widget.user.name);
  late final _email = TextEditingController(text: widget.user.email);
  late var _baseline = (name: widget.user.name, email: widget.user.email);
  var _saving = false;
  String? _error;

  @override
  void didUpdateWidget(ProfileForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dirty && !_saving) _reset(widget.user);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _reset(CurrentUser user) {
    _baseline = (name: user.name, email: user.email);
    _name.text = user.name;
    _email.text = user.email;
  }

  bool get _dirty => _name.text != _baseline.name || _email.text != _baseline.email;

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (!isValidProfile(name: name, email: email)) {
      setState(() => _error = 'Revisa el nombre y el email.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await ref.read(profileRepositoryProvider).update(name: name, email: email);
      if (mounted) setState(() => _reset(user));
      ref.read(authControllerProvider.notifier).updateUser(user);
      ref.read(toastControllerProvider.notifier).show('Perfil actualizado');
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: 'No se ha podido guardar el perfil.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changed(String _) => setState(() => _error = null);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s16,
      children: [
        Row(
          spacing: CarliSpace.s12,
          children: [
            CarliAvatar(name: _name.text.trim().isEmpty ? '?' : _name.text, size: 48),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.user.name, style: CarliType.bodyStrong.copyWith(color: colors.text)),
                  Text(widget.user.email, style: CarliType.small.copyWith(color: colors.text3)),
                ],
              ),
            ),
          ],
        ),
        CarliField(
          label: 'Nombre',
          child: CarliInput(
            controller: _name,
            autofillHints: const [AutofillHints.name],
            textInputAction: TextInputAction.next,
            onChanged: _changed,
          ),
        ),
        CarliField(
          label: 'Email',
          child: CarliInput(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.done,
            onChanged: _changed,
            onSubmitted: (_) => _dirty ? _save() : null,
          ),
        ),
        if (_error case final error?)
          Semantics(
            liveRegion: true,
            child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
          ),
        Align(
          alignment: Alignment.centerRight,
          child: CarliButton(
            label: 'Guardar cambios',
            size: CarliButtonSize.md,
            block: false,
            loading: _saving,
            onPressed: _dirty ? _save : null,
          ),
        ),
      ],
    );
  }
}
