import 'package:carli/modules/finance/data/json.dart';

Json taskListRefJson({String id = 'inbox', String name = 'Bandeja', bool isDefault = true}) => {
  'id': id,
  'name': name,
  'color': null,
  'is_default': isDefault,
};

Json taskJson({
  String id = 'task-1',
  String title = 'Sacar la basura',
  String status = 'open',
  String? dueDate = '2026-10-26',
  String? dueTime,
  bool overdue = false,
  bool important = false,
  Json? list,
  Json? template,
  List<Json> subtasks = const [],
}) => {
  'id': id,
  'title': title,
  'notes': null,
  'list_id': (list ?? taskListRefJson())['id'],
  'list': list ?? taskListRefJson(),
  'due_date': dueDate,
  'due_time': dueTime,
  'status': status,
  'skip_reason': null,
  'overdue': overdue,
  'important': important,
  'sort': 0,
  'completed_at': status == 'done' ? '2026-10-26T09:00:00+01:00' : null,
  'template_id': template?['id'],
  'occurrence_date': template == null ? null : dueDate,
  'template': template,
  'subtasks': subtasks,
  'subtasks_done': subtasks.where((subtask) => subtask['done'] == true).length,
};

Json todayJson({List<Json> overdue = const [], List<Json> today = const [], List<Json> done = const []}) => {
  'data': {
    'date': '2026-10-26',
    'overdue': overdue,
    'today': today,
    'done': done,
    'progress': {'done': done.length, 'total': done.length + today.length},
  },
};

Json templateJson({
  String id = 'tpl-1',
  String title = 'Sacar la basura',
  String? rrule = 'FREQ=WEEKLY;BYDAY=MO,TH',
  int? afterDone,
  bool paused = false,
  String? openTaskId,
}) => {
  'id': id,
  'title': title,
  'notes': null,
  'list_id': 'inbox',
  'list': taskListRefJson(),
  'subtasks': <String>[],
  'kind': afterDone == null ? 'schedule' : 'after_done',
  'rrule': rrule,
  'after_done_interval_days': afterDone,
  'dtstart': '2026-10-26',
  'until': null,
  'count': null,
  'policy': 'replace',
  'lead_days': 0,
  'due_time': '21:00',
  'important': false,
  'paused': paused,
  'frequency_text': 'Cada lunes y jueves',
  'ending_text': null,
  'next_date': '2026-10-29',
  'open_task_id': openTaskId,
  'upcoming_dates': ['2026-10-29', '2026-11-02'],
  'skipped_dates': <String>[],
};

Json previewJson({String description = 'Cada lunes y jueves', List<String> dates = const ['2026-10-29']}) => {
  'data': {'description': description, 'ending': null, 'dates': dates},
};
