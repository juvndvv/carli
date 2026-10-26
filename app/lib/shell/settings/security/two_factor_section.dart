import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/api/api_error.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/current_user.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/badge.dart';
import '../../../ui/button.dart';
import '../../../ui/card.dart';
import '../../../ui/field.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/sheet.dart';
import '../../../ui/toast.dart';
import 'data/security_models.dart';
import 'data/security_repository.dart';
import 'data/text_sharer.dart';
import 'password_prompt_sheet.dart';

const _confirmPasswordTitle = 'Confirma tu contraseña';
const _confirmPasswordMessage = 'Por seguridad, vuelve a introducir tu contraseña para continuar.';
const _monospace = TextStyle(fontFamily: 'Menlo', fontFamilyFallback: ['Courier'], fontSize: 13, height: 1.4);

sealed class _TwoFactorStep {
  const _TwoFactorStep();
}

final class _Idle extends _TwoFactorStep {
  const _Idle();
}

final class _Setup extends _TwoFactorStep {
  const _Setup(this.setup, this.password);

  final TwoFactorSetup setup;
  final String password;
}

final class _Codes extends _TwoFactorStep {
  const _Codes(this.codes);

  final List<String> codes;
}

class TwoFactorCard extends ConsumerStatefulWidget {
  const TwoFactorCard({super.key});

  @override
  ConsumerState<TwoFactorCard> createState() => _TwoFactorCardState();
}

class _TwoFactorCardState extends ConsumerState<TwoFactorCard> {
  final _code = TextEditingController();
  _TwoFactorStep _step = const _Idle();
  var _busy = false;
  String? _codeError;

  SecurityRepository get _repository => ref.read(securityRepositoryProvider);
  ToastController get _toast => ref.read(toastControllerProvider.notifier);

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _refreshUser() => ref.read(authControllerProvider.notifier).refreshUser();

  Future<void> _startSetup() async {
    String? password;
    final setup = await showPasswordPrompt<TwoFactorSetup>(
      context,
      title: _confirmPasswordTitle,
      message: _confirmPasswordMessage,
      confirmLabel: 'Confirmar',
      action: (value) {
        password = value;
        return _repository.enableTwoFactor(value);
      },
    );
    if (setup == null || password == null || !mounted) return;
    _code.clear();
    setState(() {
      _codeError = null;
      _step = _Setup(setup, password!);
    });
    await _refreshUser();
  }

  Future<void> _confirm(_Setup setup) async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _codeError = 'Introduce el código.');
      return;
    }
    setState(() {
      _busy = true;
      _codeError = null;
    });
    try {
      final codes = await _repository.confirmTwoFactor(code);
      _code.clear();
      if (mounted) setState(() => _step = _Codes(codes));
      _toast.show('Verificación en dos pasos activada');
      await _refreshUser();
    } catch (error) {
      if (mounted) setState(() => _codeError = apiErrorMessage(error, fallback: 'El código no es válido.'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelSetup(_Setup setup) async {
    setState(() {
      _busy = true;
      _step = const _Idle();
    });
    try {
      await _repository.disableTwoFactor(setup.password);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _refreshUser();
  }

  Future<void> _abandonPending() async {
    final cancelled = await showPasswordPrompt<bool>(
      context,
      title: 'Cancelar la activación',
      message: 'Se descartará el código QR que generaste. Confirma con tu contraseña.',
      confirmLabel: 'Cancelar activación',
      destructive: true,
      action: (password) async {
        await _repository.disableTwoFactor(password);
        return true;
      },
    );
    if (cancelled != true) return;
    _toast.show('Activación cancelada');
    await _refreshUser();
  }

  Future<void> _showCodes() async {
    final codes = await showPasswordPrompt<List<String>>(
      context,
      title: _confirmPasswordTitle,
      message: _confirmPasswordMessage,
      confirmLabel: 'Confirmar',
      action: _repository.recoveryCodes,
    );
    if (codes != null && mounted) setState(() => _step = _Codes(codes));
  }

  Future<void> _regenerateCodes() async {
    final codes = await showPasswordPrompt<List<String>>(
      context,
      title: 'Regenerar los códigos',
      message: 'Los códigos actuales dejarán de funcionar. Confirma con tu contraseña.',
      confirmLabel: 'Regenerar',
      action: _repository.regenerateRecoveryCodes,
    );
    if (codes == null || !mounted) return;
    setState(() => _step = _Codes(codes));
    _toast.show('Códigos regenerados');
  }

  Future<void> _disable() async {
    final confirmed = await confirmCarli(
      context,
      title: 'Desactivar la verificación en dos pasos',
      message: 'Tu cuenta quedará protegida solo con la contraseña.',
      confirmLabel: 'Desactivar',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final disabled = await showPasswordPrompt<bool>(
      context,
      title: _confirmPasswordTitle,
      message: _confirmPasswordMessage,
      confirmLabel: 'Desactivar',
      destructive: true,
      action: (password) async {
        await _repository.disableTwoFactor(password);
        return true;
      },
    );
    if (disabled != true) return;
    if (mounted) setState(() => _step = const _Idle());
    _toast.show('Verificación en dos pasos desactivada');
    await _refreshUser();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth is SignedIn ? auth.user : null;
    final colors = context.colors;
    return CarliCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: CarliSpace.s12,
            children: [
              Expanded(
                child: Text(
                  'Protege tu cuenta con un código de una app de autenticación (TOTP) al iniciar sesión.',
                  style: CarliType.small.copyWith(color: colors.text2),
                ),
              ),
              _StatusBadge(user: user),
            ],
          ),
          switch (_step) {
            _Setup() && final setup => _SetupView(
              setup: setup.setup,
              code: _code,
              error: _codeError,
              busy: _busy,
              onCodeChanged: () => setState(() => _codeError = null),
              onConfirm: () => _confirm(setup),
              onCancel: () => _cancelSetup(setup),
            ),
            _Codes(:final codes) => RecoveryCodesView(
              codes: codes,
              onRegenerate: _regenerateCodes,
              onDone: () => setState(() => _step = const _Idle()),
            ),
            _Idle() => _IdleActions(
              user: user,
              busy: _busy,
              onEnable: _startSetup,
              onAbandon: _abandonPending,
              onShowCodes: _showCodes,
              onDisable: _disable,
            ),
          },
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.user});

  final CurrentUser? user;

  @override
  Widget build(BuildContext context) {
    if (user?.twoFactorEnabled ?? false) {
      return CarliBadge('Activa', tone: CarliBadgeTone.positive, icon: carliIconNamed('check'));
    }
    if (user?.twoFactorPending ?? false) return const CarliBadge('Pendiente', tone: CarliBadgeTone.warning);
    return const CarliBadge('Inactiva');
  }
}

class _IdleActions extends StatelessWidget {
  const _IdleActions({
    required this.user,
    required this.busy,
    required this.onEnable,
    required this.onAbandon,
    required this.onShowCodes,
    required this.onDisable,
  });

  final CurrentUser? user;
  final bool busy;
  final VoidCallback onEnable;
  final VoidCallback onAbandon;
  final VoidCallback onShowCodes;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final user = this.user;
    if (user == null) {
      return Text(
        'No se ha podido cargar el estado de tu cuenta. Comprueba la conexión.',
        style: CarliType.small.copyWith(color: context.colors.text3),
      );
    }
    if (user.twoFactorEnabled) {
      return Wrap(
        spacing: CarliSpace.s8,
        runSpacing: CarliSpace.s8,
        children: [
          CarliButton(
            label: 'Códigos de recuperación',
            icon: carliIconNamed('key-round'),
            variant: CarliButtonVariant.secondary,
            size: CarliButtonSize.md,
            block: false,
            onPressed: onShowCodes,
          ),
          CarliButton(
            label: 'Desactivar',
            variant: CarliButtonVariant.ghost,
            size: CarliButtonSize.md,
            block: false,
            onPressed: onDisable,
          ),
        ],
      );
    }
    if (user.twoFactorPending) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s12,
        children: [
          Text(
            'Empezaste a activarla pero falta confirmar el código. Continúa para volver a ver el código QR.',
            style: CarliType.small.copyWith(color: context.colors.text2),
          ),
          Wrap(
            spacing: CarliSpace.s8,
            runSpacing: CarliSpace.s8,
            children: [
              CarliButton(
                label: 'Continuar la activación',
                icon: carliIconNamed('shield-check'),
                size: CarliButtonSize.md,
                block: false,
                loading: busy,
                onPressed: onEnable,
              ),
              CarliButton(
                label: 'Cancelar',
                variant: CarliButtonVariant.ghost,
                size: CarliButtonSize.md,
                block: false,
                onPressed: busy ? null : onAbandon,
              ),
            ],
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: CarliButton(
        label: 'Activar',
        icon: carliIconNamed('shield-check'),
        size: CarliButtonSize.md,
        block: false,
        loading: busy,
        onPressed: onEnable,
      ),
    );
  }
}

class _SetupView extends ConsumerWidget {
  const _SetupView({
    required this.setup,
    required this.code,
    required this.error,
    required this.busy,
    required this.onCodeChanged,
    required this.onConfirm,
    required this.onCancel,
  });

  final TwoFactorSetup setup;
  final TextEditingController code;
  final String? error;
  final bool busy;
  final VoidCallback onCodeChanged;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  Future<void> _copySecret(WidgetRef ref, String secret) async {
    await Clipboard.setData(ClipboardData(text: secret));
    ref.read(toastControllerProvider.notifier).show('Clave copiada');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s16,
      children: [
        Text(
          'Escanea este código con tu app de autenticación y escribe el código que te muestre.',
          style: CarliType.small.copyWith(color: colors.text),
        ),
        Center(
          child: Container(
            width: 208,
            height: 208,
            padding: const EdgeInsets.all(CarliSpace.s8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFFFF),
              borderRadius: BorderRadius.circular(CarliRadius.md),
            ),
            child: QrImageView(
              data: setup.qrCodeUrl,
              padding: EdgeInsets.zero,
              semanticsLabel: 'Código QR para tu app de autenticación',
            ),
          ),
        ),
        if (setup.secretKey case final secret?)
          Row(
            spacing: CarliSpace.s8,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Clave manual: ',
                    style: CarliType.small.copyWith(color: colors.text3),
                    children: [
                      TextSpan(
                        text: secret,
                        style: _monospace.copyWith(color: colors.text),
                      ),
                    ],
                  ),
                ),
              ),
              CarliButton.icon(
                icon: carliIconNamed('copy'),
                semanticLabel: 'Copiar clave',
                size: CarliButtonSize.sm,
                onPressed: () => _copySecret(ref, secret),
              ),
            ],
          ),
        CarliField(
          label: 'Código de 6 dígitos',
          error: error,
          child: CarliInput(
            controller: code,
            keyboardType: TextInputType.number,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            invalid: error != null,
            textInputAction: TextInputAction.done,
            onChanged: (_) => onCodeChanged(),
            onSubmitted: (_) => onConfirm(),
          ),
        ),
        Row(
          spacing: CarliSpace.s8,
          children: [
            CarliButton(
              label: 'Confirmar',
              size: CarliButtonSize.md,
              block: false,
              loading: busy,
              onPressed: onConfirm,
            ),
            CarliButton(
              label: 'Cancelar',
              variant: CarliButtonVariant.ghost,
              size: CarliButtonSize.md,
              block: false,
              onPressed: busy ? null : onCancel,
            ),
          ],
        ),
      ],
    );
  }
}

class RecoveryCodesView extends ConsumerWidget {
  const RecoveryCodesView({super.key, required this.codes, required this.onRegenerate, required this.onDone});

  final List<String> codes;
  final VoidCallback onRegenerate;
  final VoidCallback onDone;

  Future<void> _copy(WidgetRef ref) async {
    await Clipboard.setData(ClipboardData(text: codes.join('\n')));
    ref.read(toastControllerProvider.notifier).show('Códigos copiados');
  }

  Future<void> _share(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final origin = box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      await ref
          .read(textSharerProvider)
          .share(codes.join('\n'), subject: 'Códigos de recuperación de carli', origin: origin);
    } catch (_) {
      ref.read(toastControllerProvider.notifier).error('No se han podido compartir los códigos.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s16,
      children: [
        Text(
          'Guarda estos códigos de recuperación en un lugar seguro. Cada uno sirve una sola vez.',
          style: CarliType.small.copyWith(color: colors.text),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
          decoration: BoxDecoration(color: colors.surface2, borderRadius: BorderRadius.circular(CarliRadius.md)),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 5,
            mainAxisSpacing: CarliSpace.s4,
            crossAxisSpacing: CarliSpace.s16,
            children: [
              for (final code in codes)
                Align(
                  alignment: Alignment.centerLeft,
                  child: SelectableText(code, style: _monospace.copyWith(color: colors.text)),
                ),
            ],
          ),
        ),
        Wrap(
          spacing: CarliSpace.s8,
          runSpacing: CarliSpace.s8,
          children: [
            CarliButton(
              label: 'Copiar',
              icon: carliIconNamed('copy'),
              variant: CarliButtonVariant.secondary,
              size: CarliButtonSize.md,
              block: false,
              onPressed: () => _copy(ref),
            ),
            Builder(
              builder: (context) => CarliButton(
                label: 'Compartir',
                icon: carliIconNamed('share'),
                variant: CarliButtonVariant.secondary,
                size: CarliButtonSize.md,
                block: false,
                onPressed: () => _share(context, ref),
              ),
            ),
            CarliButton(
              label: 'Regenerar',
              icon: carliIconNamed('refresh-cw'),
              variant: CarliButtonVariant.ghost,
              size: CarliButtonSize.md,
              block: false,
              onPressed: onRegenerate,
            ),
            CarliButton(
              label: 'Hecho',
              variant: CarliButtonVariant.ghost,
              size: CarliButtonSize.md,
              block: false,
              onPressed: onDone,
            ),
          ],
        ),
      ],
    );
  }
}
