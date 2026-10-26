import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:carli/ui/toast.dart';

void main() {
  test('runs the undo action once and dismisses the toast', () async {
    final container = ProviderContainer.test();
    final toasts = container.read(toastControllerProvider.notifier);
    var undone = 0;

    final id = toasts.withUndo('Movimiento eliminado', () => undone++);
    expect(container.read(toastControllerProvider)?.action?.label, 'Deshacer');

    await toasts.runAction(id);
    await toasts.runAction(id);

    expect(undone, 1);
    expect(container.read(toastControllerProvider), isNull);
  });

  test('queues behind a toast with an action and shows it after', () {
    final container = ProviderContainer.test();
    final toasts = container.read(toastControllerProvider.notifier);

    final first = toasts.withUndo('Movimiento eliminado', () {});
    toasts.enqueue('¿Aplicar a los parecidos?');
    expect(container.read(toastControllerProvider)?.message, 'Movimiento eliminado');

    toasts.dismiss(first);
    expect(container.read(toastControllerProvider)?.message, '¿Aplicar a los parecidos?');
  });

  testWidgets('hides after its duration', (tester) async {
    final container = ProviderContainer.test();
    container.read(toastControllerProvider.notifier).show('Guardado');

    await tester.pump(defaultToastDuration);

    expect(container.read(toastControllerProvider), isNull);
  });
}
