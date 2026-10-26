import 'package:flutter/foundation.dart';

@immutable
class ReminderMessage {
  const ReminderMessage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  bool operator ==(Object other) => other is ReminderMessage && other.title == title && other.body == body;

  @override
  int get hashCode => Object.hash(title, body);

  @override
  String toString() => '$title: $body';
}

const reminderTitle = 'carli';
const genericReminderBody = 'Repasa tus movimientos de hoy';

ReminderMessage reminderMessageFor(int? pendingCount) {
  final body = switch (pendingCount) {
    null || <= 0 => genericReminderBody,
    1 => 'Tienes 1 elemento por revisar',
    final count => 'Tienes $count elementos por revisar',
  };
  return ReminderMessage(title: reminderTitle, body: body);
}
