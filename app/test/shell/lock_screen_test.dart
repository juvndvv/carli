import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/theme/theme.dart';
import 'package:carli/shell/lock/lock_screen.dart';

void main() {
  testWidgets('explains how to unlock', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: carliTheme(Brightness.light), home: const LockScreen()),
      ),
    );

    expect(find.text('carli está bloqueada'), findsOneWidget);
    expect(find.text('Usa Face ID para continuar.'), findsOneWidget);
    expect(find.text('Desbloquear'), findsOneWidget);
  });
}
