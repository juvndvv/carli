import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:carli/core/auth/current_user.dart';
import 'package:carli/core/theme/theme_preference.dart';
import 'package:carli/shell/settings/appearance_settings_screen.dart';

import '../../support/fake_api.dart';
import '../../support/finance_app.dart';

void main() {
  testWidgets('shows the stored theme and persists a new choice', (tester) async {
    SharedPreferences.setMockInitialValues({themeStorageKey: 'light'});
    final api = FakeApi({
      'GET /v1/me': (_) => (
        200,
        {
          'data': {
            ...testUser,
            'preferences': {'theme': 'light'},
          },
        },
      ),
      'PATCH /v1/me/preferences': (_) => (200, {'data': testUser}),
    });
    final container = await pumpFinance(tester, const AppearanceSettingsScreen(), api);

    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('«Sistema» sigue el modo claro u oscuro de tu dispositivo.'), findsOneWidget);
    for (final label in ['Claro', 'Oscuro', 'Sistema']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(container.read(themePreferenceProvider), ThemePreference.light);

    await tester.tap(find.text('Oscuro'));
    await settle(tester);

    expect(container.read(themePreferenceProvider), ThemePreference.dark);
    expect((await SharedPreferences.getInstance()).getString(themeStorageKey), 'dark');
    final write = api.requests.singleWhere((request) => request.method == 'PATCH');
    expect(write.path, '/v1/me/preferences');
    expect(write.data, {'theme': 'dark'});
  });
}
