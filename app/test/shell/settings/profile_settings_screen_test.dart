import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/core/auth/auth_controller.dart';
import 'package:carli/shell/settings/profile_settings_screen.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';

FakeApi profileApi({(int, Object?) Function(Map<dynamic, dynamic> body)? update}) => FakeApi({
  'GET /v1/me': (_) => (200, {'data': testUser}),
  'PATCH /v1/me': (options) {
    final body = options.data as Map;
    return update?.call(body) ??
        (
          200,
          {
            'data': {...testUser, ...body},
          },
        );
  },
});

Finder nameInput() => find.byType(TextField).at(0);
Finder emailInput() => find.byType(TextField).at(1);

List<Object?> profileWrites(FakeApi api) => [
  for (final request in api.requests)
    if (request.method == 'PATCH') request.data,
];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('validates the name and email', () {
    expect(isValidProfile(name: 'Juanda', email: 'juanda@example.com'), isTrue);
    expect(isValidProfile(name: ' ', email: 'juanda@example.com'), isFalse);
    expect(isValidProfile(name: 'Juanda', email: 'juanda'), isFalse);
  });

  testWidgets('fills the form with the signed in user and keeps saving disabled until a change', (tester) async {
    final api = profileApi();
    await pumpFinance(tester, const ProfileSettingsScreen(), api);

    expect(find.text('Perfil'), findsWidgets);
    expect(find.widgetWithText(TextField, 'Juanda'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'juanda@example.com'), findsOneWidget);

    await tester.tap(find.text('Guardar cambios'));
    await settle(tester);

    expect(profileWrites(api), isEmpty);
  });

  testWidgets('saves the profile and updates the signed in user', (tester) async {
    final api = profileApi();
    final container = await pumpFinance(tester, const ProfileSettingsScreen(), api);

    await tester.enterText(nameInput(), 'Juan Daniel');
    await tester.pump();
    await tester.tap(find.text('Guardar cambios'));
    await settle(tester);

    expect(profileWrites(api), [
      {'name': 'Juan Daniel', 'email': 'juanda@example.com'},
    ]);
    final auth = container.read(authControllerProvider) as SignedIn;
    expect(auth.user?.name, 'Juan Daniel');
    expect(find.text('Perfil actualizado'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('rejects an invalid email without calling the server', (tester) async {
    final api = profileApi();
    await pumpFinance(tester, const ProfileSettingsScreen(), api);

    await tester.enterText(emailInput(), 'juanda');
    await tester.pump();
    await tester.tap(find.text('Guardar cambios'));
    await settle(tester);

    expect(find.text('Revisa el nombre y el email.'), findsOneWidget);
    expect(profileWrites(api), isEmpty);
  });

  testWidgets('shows the server validation message', (tester) async {
    final api = profileApi(
      update: (_) => (
        422,
        {
          'message': 'The email has already been taken.',
          'errors': {
            'email': ['Ese email ya está en uso.'],
          },
        },
      ),
    );
    final container = await pumpFinance(tester, const ProfileSettingsScreen(), api);

    await tester.enterText(emailInput(), 'otra@example.com');
    await tester.pump();
    await tester.tap(find.text('Guardar cambios'));
    await settle(tester);

    expect(find.text('Ese email ya está en uso.'), findsOneWidget);
    final auth = container.read(authControllerProvider) as SignedIn;
    expect(auth.user?.email, 'juanda@example.com');
  });
}
