import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/auth/auth_controller.dart';
import '../../core/auth/auth_repository.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../ui/button.dart';
import '../../ui/field.dart';
import '../../ui/logo.dart';

enum _Step { credentials, twoFactor }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  var _step = _Step.credentials;
  var _useRecovery = false;
  var _busy = false;
  String? _error;
  Credentials? _pending;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submitCredentials() async {
    final email = _email.text.trim();
    if (email.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Introduce tu email y tu contraseña.');
      return;
    }
    final credentials = Credentials(email: email, password: _password.text);
    await _run(credentials, fallback: 'Email o contraseña incorrectos.');
  }

  Future<void> _submitCode() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Introduce el código.');
      return;
    }
    final credentials = _useRecovery ? _pending!.withCode(recoveryCode: code) : _pending!.withCode(code: code);
    await _run(credentials, fallback: 'El código no es válido.');
  }

  Future<void> _run(Credentials credentials, {required String fallback}) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await ref.read(authControllerProvider.notifier).login(credentials);
      if (!mounted) return;
      if (result is TwoFactorRequired) {
        setState(() {
          _pending = credentials;
          _step = _Step.twoFactor;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = apiErrorMessage(error, fallback: fallback));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _backToCredentials() => setState(() {
    _step = _Step.credentials;
    _pending = null;
    _code.clear();
    _error = null;
  });

  void _toggleRecovery() => setState(() {
    _useRecovery = !_useRecovery;
    _code.clear();
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(CarliSpace.s24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: CarliSpace.s24,
                  children: [
                    const _Brand(),
                    if (_step == _Step.credentials) ..._credentialsForm() else ..._twoFactorForm(),
                    if (_error case final error?)
                      Semantics(
                        liveRegion: true,
                        child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
                      ),
                    CarliButton(
                      label: _step == _Step.credentials ? 'Entrar' : 'Verificar',
                      loading: _busy,
                      onPressed: _step == _Step.credentials ? _submitCredentials : _submitCode,
                    ),
                    if (_step == _Step.twoFactor)
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          TextButton(onPressed: _backToCredentials, child: const Text('Volver')),
                          TextButton(
                            onPressed: _toggleRecovery,
                            child: Text(_useRecovery ? 'Usar código de la app' : 'Usar código de recuperación'),
                          ),
                        ],
                      ),
                    if (kDebugMode && _step == _Step.credentials)
                      TextButton(
                        onPressed: () => context.push(Routes.catalog),
                        child: const Text('Catálogo de componentes'),
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

  List<Widget> _credentialsForm() => [
    CarliField(
      label: 'Email',
      child: CarliInput(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.username, AutofillHints.email],
        textInputAction: TextInputAction.next,
        invalid: _error != null,
      ),
    ),
    CarliField(
      label: 'Contraseña',
      child: CarliInput(
        controller: _password,
        obscureText: true,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.go,
        onSubmitted: (_) => _submitCredentials(),
        invalid: _error != null,
      ),
    ),
  ];

  List<Widget> _twoFactorForm() {
    final colors = context.colors;
    return [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s4,
        children: [
          Text('Verificación en dos pasos', style: CarliType.h2.copyWith(color: colors.text)),
          Text(
            _useRecovery
                ? 'Introduce uno de tus códigos de recuperación.'
                : 'Introduce el código de 6 dígitos de tu app de autenticación.',
            style: CarliType.small.copyWith(color: colors.text2),
          ),
        ],
      ),
      CarliField(
        key: ValueKey(_useRecovery),
        label: _useRecovery ? 'Código de recuperación' : 'Código',
        child: CarliInput(
          controller: _code,
          keyboardType: _useRecovery ? TextInputType.text : TextInputType.number,
          autofillHints: _useRecovery ? null : const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submitCode(),
          invalid: _error != null,
          autofocus: true,
        ),
      ),
    ];
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Row(
      spacing: 10,
      children: [
        const CarliLogo(size: 36),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('carli', style: CarliType.wordmark(20).copyWith(color: colors.text)),
            Text('Tu asistente personal', style: CarliType.small.copyWith(color: colors.text3)),
          ],
        ),
      ],
    );
  }
}
