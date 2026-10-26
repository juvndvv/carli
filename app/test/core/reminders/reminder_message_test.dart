import 'package:flutter_test/flutter_test.dart';

import 'package:carli/core/reminders/reminder_message.dart';

void main() {
  test('uses the pending count when there is something to review', () {
    expect(reminderMessageFor(3), const ReminderMessage(title: 'carli', body: 'Tienes 3 elementos por revisar'));
    expect(reminderMessageFor(1).body, 'Tienes 1 elemento por revisar');
  });

  test('falls back to a generic reminder when the count is unknown or zero', () {
    expect(reminderMessageFor(null).body, 'Repasa tus movimientos de hoy');
    expect(reminderMessageFor(0).body, 'Repasa tus movimientos de hoy');
    expect(reminderMessageFor(-2).body, 'Repasa tus movimientos de hoy');
    expect(reminderMessageFor(null).title, 'carli');
  });
}
