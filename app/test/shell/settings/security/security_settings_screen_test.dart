import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:carli/shell/settings/security/security_settings_screen.dart';
import 'package:carli/ui/button.dart';
import 'package:carli/ui/switch.dart';

import '../../../support/fake_api.dart';
import '../../../support/security_app.dart';

typedef Json = Map<String, dynamic>;

Json userJson({bool enabled = false, bool pending = false}) => {
  ...testUser,
  'two_factor_enabled': enabled,
  'two_factor_pending': pending,
};

const qrUrl = 'otpauth://totp/carli:juanda%40example.com?secret=JBSWY3DPEHPK3PXP&issuer=carli';

Map<String, FakeRoute> securityRoutes({
  Json Function()? me,
  List<Json>? tokens,
  List<Json>? sessions,
  Map<String, FakeRoute> extra = const {},
}) => {
  'GET /v1/me': (_) => (200, {'data': me?.call() ?? userJson()}),
  'GET /v1/me/tokens': (_) => (
    200,
    {
      'data':
          tokens ??
          [
            {
              'id': 1,
              'name': 'carli iOS',
              'last_used_at': '2026-10-26T09:00:00+01:00',
              'created_at': '2026-10-01T09:00:00+02:00',
              'is_current': true,
            },
            {
              'id': 2,
              'name': 'iPad',
              'last_used_at': null,
              'created_at': '2026-10-02T09:00:00+02:00',
              'is_current': false,
            },
          ],
    },
  ),
  'GET /v1/me/sessions': (_) => (
    200,
    {
      'data':
          sessions ??
          [
            {
              'id': 'web-1',
              'device': 'Safari en macOS',
              'browser': 'Safari',
              'platform': 'macOS',
              'is_mobile': false,
              'ip_address': '10.0.0.1',
              'last_active_at': '2026-10-25T10:00:00+02:00',
              'is_current': false,
            },
          ],
    },
  ),
  ...extra,
};

Json bodyOf(FakeApi api, String method, String path) =>
    api.requests.lastWhere((request) => request.method == method && request.path == path).data as Json;

Future<void> enterPassword(WidgetTester tester, String password, String confirmLabel) async {
  final sheet = find.byType(BottomSheet);
  await tester.enterText(find.descendant(of: sheet, matching: find.byType(TextField)), password);
  await tester.pump();
  await tester.tap(find.descendant(of: sheet, matching: find.text(confirmLabel)));
  await tester.pumpAndSettle();
}

Finder revokeButton(String name) =>
    find.byWidgetPredicate((widget) => widget is CarliButton && widget.semanticLabel == 'Cerrar la sesión de $name');

Future<void> finishToasts(WidgetTester tester) => tester.pump(const Duration(seconds: 6));

void main() {
  group('password', () {
    testWidgets('validates the fields before calling the api', (tester) async {
      final api = FakeApi(securityRoutes());
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pump();

      expect(
        find.text('Rellena los tres campos; la nueva contraseña debe tener al menos 8 caracteres.'),
        findsOneWidget,
      );

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'password');
      await tester.enterText(fields.at(1), 'new-secret-42');
      await tester.enterText(fields.at(2), 'different-42');
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pump();

      expect(find.text('Las contraseñas nuevas no coinciden.'), findsOneWidget);
      expect(api.requests.where((request) => request.path == '/v1/me/password'), isEmpty);
    });

    testWidgets('changes the password', (tester) async {
      final api = FakeApi(securityRoutes(extra: {'PUT /v1/me/password': (_) => (204, null)}));
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'password');
      await tester.enterText(fields.at(1), 'new-secret-42');
      await tester.enterText(fields.at(2), 'new-secret-42');
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();

      expect(bodyOf(api, 'PUT', '/v1/me/password'), {
        'current_password': 'password',
        'password': 'new-secret-42',
        'password_confirmation': 'new-secret-42',
      });
      expect(find.text('Contraseña actualizada'), findsOneWidget);
      expect(tester.widget<TextField>(fields.at(0)).controller!.text, isEmpty);
      await finishToasts(tester);
    });

    testWidgets('shows the server validation message', (tester) async {
      final api = FakeApi(
        securityRoutes(
          extra: {
            'PUT /v1/me/password': (_) => (
              422,
              {
                'message': 'La contraseña no coincide con tu contraseña actual.',
                'errors': {
                  'current_password': ['La contraseña no coincide con tu contraseña actual.'],
                },
              },
            ),
          },
        ),
      );
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), 'wrong');
      await tester.enterText(fields.at(1), 'new-secret-42');
      await tester.enterText(fields.at(2), 'new-secret-42');
      await tester.tap(find.text('Cambiar contraseña'));
      await tester.pumpAndSettle();

      expect(find.text('La contraseña no coincide con tu contraseña actual.'), findsOneWidget);
    });
  });

  group('two factor authentication', () {
    testWidgets('enables, confirms and shows the recovery codes', (tester) async {
      var user = userJson();
      final sharer = RecordingTextSharer();
      final api = FakeApi(
        securityRoutes(
          me: () => user,
          extra: {
            'POST /v1/me/two-factor': (_) {
              user = userJson(pending: true);
              return (200, {'secret_key': 'JBSWY3DPEHPK3PXP', 'qr_code_url': qrUrl, 'qr_code_svg': '<svg/>'});
            },
            'POST /v1/me/two-factor/confirm': (_) {
              user = userJson(enabled: true);
              return (
                200,
                {
                  'recovery_codes': ['alpha-one', 'bravo-two'],
                },
              );
            },
          },
        ),
      );
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api, sharer: sharer);

      expect(find.text('Inactiva'), findsOneWidget);

      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();
      expect(find.text('Confirma tu contraseña'), findsOneWidget);

      await enterPassword(tester, 'password', 'Confirmar');

      expect(bodyOf(api, 'POST', '/v1/me/two-factor'), {'password': 'password'});
      expect(tester.widget<QrImageView>(find.byType(QrImageView)), isNotNull);
      expect(find.textContaining('JBSWY3DPEHPK3PXP', findRichText: true), findsOneWidget);
      expect(find.text('Pendiente'), findsOneWidget);

      await tester.tap(find.text('Confirmar'));
      await tester.pump();
      expect(find.text('Introduce el código.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(Column, 'Código de 6 dígitos').last, '123456');
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(bodyOf(api, 'POST', '/v1/me/two-factor/confirm'), {'code': '123456'});
      expect(find.text('alpha-one'), findsOneWidget);
      expect(find.text('bravo-two'), findsOneWidget);
      expect(find.text('Activa'), findsOneWidget);

      await tester.tap(find.text('Compartir'));
      await tester.pump();
      expect(sharer.shared, ['alpha-one\nbravo-two']);

      await tester.tap(find.text('Hecho'));
      await tester.pumpAndSettle();
      expect(find.text('Códigos de recuperación'), findsOneWidget);
      await finishToasts(tester);
    });

    testWidgets('keeps the prompt open with the error for a wrong password', (tester) async {
      final api = FakeApi(
        securityRoutes(
          extra: {
            'POST /v1/me/two-factor': (_) => (
              422,
              {
                'message': 'La contraseña no es correcta.',
                'errors': {
                  'password': ['La contraseña no es correcta.'],
                },
              },
            ),
          },
        ),
      );
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();
      await enterPassword(tester, 'wrong', 'Confirmar');

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.text('La contraseña no es correcta.'), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
    });

    testWidgets('cancels an unfinished setup with the confirmed password', (tester) async {
      var user = userJson();
      final api = FakeApi(
        securityRoutes(
          me: () => user,
          extra: {
            'POST /v1/me/two-factor': (_) {
              user = userJson(pending: true);
              return (200, {'secret_key': 'JBSWY3DPEHPK3PXP', 'qr_code_url': qrUrl});
            },
            'DELETE /v1/me/two-factor': (_) {
              user = userJson();
              return (204, null);
            },
          },
        ),
      );
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      await tester.tap(find.text('Activar'));
      await tester.pumpAndSettle();
      await enterPassword(tester, 'password', 'Confirmar');
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(bodyOf(api, 'DELETE', '/v1/me/two-factor'), {'password': 'password'});
      expect(find.byType(QrImageView), findsNothing);
      expect(find.text('Inactiva'), findsOneWidget);
    });

    testWidgets('offers to resume a pending activation', (tester) async {
      final api = FakeApi(
        securityRoutes(
          me: () => userJson(pending: true),
          extra: {
            'POST /v1/me/two-factor': (_) => (200, {'secret_key': 'JBSWY3DPEHPK3PXP', 'qr_code_url': qrUrl}),
          },
        ),
      );
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      expect(find.text('Pendiente'), findsOneWidget);
      expect(find.text('Continuar la activación'), findsOneWidget);

      await tester.tap(find.text('Continuar la activación'));
      await tester.pumpAndSettle();
      await enterPassword(tester, 'password', 'Confirmar');

      expect(find.byType(QrImageView), findsOneWidget);
    });

    testWidgets('shows and regenerates the recovery codes', (tester) async {
      final api = FakeApi(
        securityRoutes(
          me: () => userJson(enabled: true),
          extra: {
            'POST /v1/me/two-factor/recovery-codes': (_) => (
              200,
              {
                'recovery_codes': ['old-one', 'old-two'],
              },
            ),
            'POST /v1/me/two-factor/recovery-codes/regenerate': (_) => (
              200,
              {
                'recovery_codes': ['new-one', 'new-two'],
              },
            ),
          },
        ),
      );
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      expect(find.text('Activa'), findsOneWidget);
      await tester.tap(find.text('Códigos de recuperación'));
      await tester.pumpAndSettle();
      await enterPassword(tester, 'password', 'Confirmar');

      expect(bodyOf(api, 'POST', '/v1/me/two-factor/recovery-codes'), {'password': 'password'});
      expect(find.text('old-one'), findsOneWidget);

      await tester.tap(find.text('Regenerar'));
      await tester.pumpAndSettle();
      await enterPassword(tester, 'password', 'Regenerar');

      expect(find.text('new-one'), findsOneWidget);
      expect(find.text('old-one'), findsNothing);
      await finishToasts(tester);
    });

    testWidgets('disables after confirming the dialog and the password', (tester) async {
      var user = userJson(enabled: true);
      final api = FakeApi(
        securityRoutes(
          me: () => user,
          extra: {
            'DELETE /v1/me/two-factor': (_) {
              user = userJson();
              return (204, null);
            },
          },
        ),
      );
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();
      expect(find.text('Tu cuenta quedará protegida solo con la contraseña.'), findsOneWidget);

      await tester.tap(find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.text('Desactivar')));
      await tester.pumpAndSettle();
      await enterPassword(tester, 'password', 'Desactivar');

      expect(bodyOf(api, 'DELETE', '/v1/me/two-factor'), {'password': 'password'});
      expect(find.text('Verificación en dos pasos desactivada'), findsOneWidget);
      expect(find.text('Inactiva'), findsOneWidget);
      await finishToasts(tester);
    });
  });

  group('biometric lock', () {
    testWidgets('enables the lock after authenticating', (tester) async {
      final localAuth = FakeLocalAuthentication();
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), FakeApi(securityRoutes()), localAuth: localAuth);

      expect(find.text('Bloqueo con Face ID'), findsOneWidget);

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      expect(localAuth.authentications, 1);
      expect(tester.widget<CarliSwitch>(find.byType(CarliSwitch)).value, isTrue);
      expect(find.text('Bloqueo activado'), findsOneWidget);
      await finishToasts(tester);
    });

    testWidgets('keeps the lock off when authentication fails', (tester) async {
      final localAuth = FakeLocalAuthentication(passes: false);
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), FakeApi(securityRoutes()), localAuth: localAuth);

      await tester.tap(find.byType(CupertinoSwitch));
      await tester.pumpAndSettle();

      expect(tester.widget<CarliSwitch>(find.byType(CarliSwitch)).value, isFalse);
      expect(find.text('Bloqueo activado'), findsNothing);
    });

    testWidgets('explains how to set it up when biometrics are unavailable', (tester) async {
      await pumpSecurityScreen(
        tester,
        const SecuritySettingsScreen(),
        FakeApi(securityRoutes()),
        localAuth: FakeLocalAuthentication(supported: false),
      );

      expect(
        find.text('Configura Face ID o Touch ID en los Ajustes del iPhone para poder bloquear carli.'),
        findsOneWidget,
      );
      expect(find.byType(CarliSwitch), findsNothing);
    });
  });

  group('active sessions', () {
    testWidgets('lists the app tokens and the web sessions', (tester) async {
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), FakeApi(securityRoutes()));

      expect(find.text('carli iOS'), findsOneWidget);
      expect(find.text('Este dispositivo'), findsOneWidget);
      expect(find.text('iPad'), findsOneWidget);
      expect(find.text('Safari en macOS'), findsOneWidget);
      expect(find.textContaining('10.0.0.1 · '), findsOneWidget);
      expect(revokeButton('carli iOS'), findsNothing);
      expect(revokeButton('iPad'), findsOneWidget);
    });

    testWidgets('revokes another app token and a web session', (tester) async {
      final api = FakeApi(
        securityRoutes(
          extra: {'DELETE /v1/me/tokens/2': (_) => (204, null), 'DELETE /v1/me/sessions/web-1': (_) => (204, null)},
        ),
      );
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      await tester.tap(revokeButton('iPad'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.text('Cerrar sesión')));
      await tester.pumpAndSettle();

      expect(
        api.requests.where((request) => request.method == 'DELETE' && request.path == '/v1/me/tokens/2'),
        hasLength(1),
      );
      expect(find.text('Sesión cerrada'), findsOneWidget);

      await tester.tap(revokeButton('Safari en macOS'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(CupertinoAlertDialog), matching: find.text('Cerrar sesión')));
      await tester.pumpAndSettle();

      expect(
        api.requests.where((request) => request.method == 'DELETE' && request.path == '/v1/me/sessions/web-1'),
        hasLength(1),
      );
      expect(api.requests.where((request) => request.path == '/v1/me/tokens').length, greaterThanOrEqualTo(3));
      await finishToasts(tester);
    });

    testWidgets('logs out the other devices with the password', (tester) async {
      final api = FakeApi(
        securityRoutes(
          extra: {
            'POST /v1/me/tokens/logout-others': (_) => (200, {'revoked_tokens': 1, 'revoked_sessions': 1}),
          },
        ),
      );
      await pumpSecurityScreen(tester, const SecuritySettingsScreen(), api);

      await tester.tap(find.text('Cerrar las demás'));
      await tester.pumpAndSettle();
      expect(find.text('Cerrar las demás sesiones'), findsOneWidget);

      await enterPassword(tester, 'password', 'Cerrar sesiones');

      expect(bodyOf(api, 'POST', '/v1/me/tokens/logout-others'), {'password': 'password'});
      expect(find.text('Sesiones cerradas en los demás dispositivos'), findsOneWidget);
      await finishToasts(tester);
    });
  });
}
