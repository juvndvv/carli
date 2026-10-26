import 'package:flutter/foundation.dart';

import '../../finance/data/json.dart';

enum TaskStatus {
  open('open'),
  done('done'),
  skipped('skipped');

  const TaskStatus(this.api);

  final String api;

  static TaskStatus of(String? value) => values.firstWhere((status) => status.api == value, orElse: () => open);
}

enum TemplatePolicy {
  replace('replace', 'Sustituir', 'La anterior queda como omitida y solo hay una abierta'),
  accumulate('accumulate', 'Acumular', 'Se quedan todas abiertas hasta que las hagas');

  const TemplatePolicy(this.api, this.label, this.hint);

  final String api;
  final String label;
  final String hint;

  static TemplatePolicy of(String? value) => value == 'accumulate' ? accumulate : replace;
}

@immutable
class TaskListRef {
  const TaskListRef({required this.id, required this.name, this.color, this.isDefault = false});

  factory TaskListRef.fromJson(Json json) => TaskListRef(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    color: json['color'] as String?,
    isDefault: json['is_default'] as bool? ?? false,
  );

  final String id;
  final String name;
  final String? color;
  final bool isDefault;
}

@immutable
class TaskList {
  const TaskList({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.isDefault = false,
    this.archived = false,
    this.openCount = 0,
  });

  factory TaskList.fromJson(Json json) => TaskList(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    icon: json['icon'] as String?,
    color: json['color'] as String?,
    isDefault: json['is_default'] as bool? ?? false,
    archived: json['archived'] as bool? ?? false,
    openCount: intOf(json['open_tasks_count']),
  );

  final String id;
  final String name;
  final String? icon;
  final String? color;
  final bool isDefault;
  final bool archived;
  final int openCount;
}

@immutable
class Subtask {
  const Subtask({required this.id, required this.title, required this.done});

  factory Subtask.fromJson(Json json) =>
      Subtask(id: json['id'] as String, title: json['title'] as String? ?? '', done: json['done'] as bool? ?? false);

  final String id;
  final String title;
  final bool done;
}

@immutable
class TaskTemplateRef {
  const TaskTemplateRef({required this.id, required this.title, required this.frequencyText, this.paused = false});

  factory TaskTemplateRef.fromJson(Json json) => TaskTemplateRef(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    frequencyText: json['frequency_text'] as String? ?? '',
    paused: json['paused'] as bool? ?? false,
  );

  final String id;
  final String title;
  final String frequencyText;
  final bool paused;
}

@immutable
class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.list,
    required this.status,
    this.notes,
    this.dueDate,
    this.dueTime,
    this.overdue = false,
    this.important = false,
    this.completedAt,
    this.template,
    this.occurrenceDate,
    this.subtasks = const [],
  });

  factory TaskItem.fromJson(Json json) => TaskItem(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    notes: json['notes'] as String?,
    list: TaskListRef.fromJson(json['list'] as Json),
    status: TaskStatus.of(json['status'] as String?),
    dueDate: parseIsoDateOrNull(json['due_date']),
    dueTime: json['due_time'] as String?,
    overdue: json['overdue'] as bool? ?? false,
    important: json['important'] as bool? ?? false,
    completedAt: json['completed_at'] is String ? DateTime.parse(json['completed_at'] as String).toLocal() : null,
    template: json['template'] is Map ? TaskTemplateRef.fromJson(json['template'] as Json) : null,
    occurrenceDate: parseIsoDateOrNull(json['occurrence_date']),
    subtasks: parseList(json['subtasks'], Subtask.fromJson),
  );

  final String id;
  final String title;
  final String? notes;
  final TaskListRef list;
  final TaskStatus status;
  final DateTime? dueDate;
  final String? dueTime;
  final bool overdue;
  final bool important;
  final DateTime? completedAt;
  final TaskTemplateRef? template;
  final DateTime? occurrenceDate;
  final List<Subtask> subtasks;

  bool get isDone => status == TaskStatus.done;

  bool get isOpen => status == TaskStatus.open;

  bool get repeats => template != null;

  int get subtasksDone => subtasks.where((subtask) => subtask.done).length;
}

@immutable
class TaskOccurrence {
  const TaskOccurrence({
    required this.templateId,
    required this.date,
    required this.title,
    required this.list,
    required this.frequencyText,
    this.dueTime,
    this.important = false,
  });

  factory TaskOccurrence.fromJson(Json json) => TaskOccurrence(
    templateId: json['template_id'] as String,
    date: parseIsoDate(json['date'] as String),
    title: json['title'] as String? ?? '',
    list: TaskListRef.fromJson(json['list'] as Json),
    frequencyText: json['frequency_text'] as String? ?? '',
    dueTime: json['due_time'] as String?,
    important: json['important'] as bool? ?? false,
  );

  final String templateId;
  final DateTime date;
  final String title;
  final TaskListRef list;
  final String frequencyText;
  final String? dueTime;
  final bool important;
}

@immutable
class TodayView {
  const TodayView({
    required this.date,
    required this.overdue,
    required this.today,
    required this.done,
    required this.doneCount,
    required this.total,
  });

  factory TodayView.fromJson(Json json) {
    final progress = json['progress'] as Json? ?? const {};
    return TodayView(
      date: parseIsoDate(json['date'] as String),
      overdue: parseList(json['overdue'], TaskItem.fromJson),
      today: parseList(json['today'], TaskItem.fromJson),
      done: parseList(json['done'], TaskItem.fromJson),
      doneCount: intOf(progress['done']),
      total: intOf(progress['total']),
    );
  }

  final DateTime date;
  final List<TaskItem> overdue;
  final List<TaskItem> today;
  final List<TaskItem> done;
  final int doneCount;
  final int total;
}

@immutable
class UpcomingDay {
  const UpcomingDay({required this.date, required this.tasks, required this.occurrences});

  factory UpcomingDay.fromJson(Json json) => UpcomingDay(
    date: parseIsoDate(json['date'] as String),
    tasks: parseList(json['tasks'], TaskItem.fromJson),
    occurrences: parseList(json['occurrences'], TaskOccurrence.fromJson),
  );

  final DateTime date;
  final List<TaskItem> tasks;
  final List<TaskOccurrence> occurrences;

  bool get isEmpty => tasks.isEmpty && occurrences.isEmpty;
}

@immutable
class TaskTemplate {
  const TaskTemplate({
    required this.id,
    required this.title,
    required this.list,
    required this.dtstart,
    required this.policy,
    required this.frequencyText,
    this.notes,
    this.subtasks = const [],
    this.rrule,
    this.afterDoneIntervalDays,
    this.until,
    this.count,
    this.leadDays = 0,
    this.dueTime,
    this.important = false,
    this.paused = false,
    this.endingText,
    this.nextDate,
    this.openTaskId,
    this.upcomingDates = const [],
    this.skippedDates = const [],
  });

  factory TaskTemplate.fromJson(Json json) => TaskTemplate(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    notes: json['notes'] as String?,
    list: TaskListRef.fromJson(json['list'] as Json),
    subtasks: [for (final item in (json['subtasks'] as List? ?? const [])) '$item'],
    rrule: json['rrule'] as String?,
    afterDoneIntervalDays: intOrNull(json['after_done_interval_days']),
    dtstart: parseIsoDate(json['dtstart'] as String),
    until: parseIsoDateOrNull(json['until']),
    count: intOrNull(json['count']),
    policy: TemplatePolicy.of(json['policy'] as String?),
    leadDays: intOf(json['lead_days']),
    dueTime: json['due_time'] as String?,
    important: json['important'] as bool? ?? false,
    paused: json['paused'] as bool? ?? false,
    frequencyText: json['frequency_text'] as String? ?? '',
    endingText: json['ending_text'] as String?,
    nextDate: parseIsoDateOrNull(json['next_date']),
    openTaskId: json['open_task_id'] as String?,
    upcomingDates: [for (final date in (json['upcoming_dates'] as List? ?? const [])) parseIsoDate('$date')],
    skippedDates: [for (final date in (json['skipped_dates'] as List? ?? const [])) parseIsoDate('$date')],
  );

  final String id;
  final String title;
  final String? notes;
  final TaskListRef list;
  final List<String> subtasks;
  final String? rrule;
  final int? afterDoneIntervalDays;
  final DateTime dtstart;
  final DateTime? until;
  final int? count;
  final TemplatePolicy policy;
  final int leadDays;
  final String? dueTime;
  final bool important;
  final bool paused;
  final String frequencyText;
  final String? endingText;
  final DateTime? nextDate;
  final String? openTaskId;
  final List<DateTime> upcomingDates;
  final List<DateTime> skippedDates;

  bool get afterDone => afterDoneIntervalDays != null;
}

@immutable
class TemplateHistoryEntry {
  const TemplateHistoryEntry({required this.taskId, required this.date, required this.status, this.skipReason});

  factory TemplateHistoryEntry.fromJson(Json json) => TemplateHistoryEntry(
    taskId: json['task_id'] as String,
    date: parseIsoDate(json['date'] as String),
    status: TaskStatus.of(json['status'] as String?),
    skipReason: json['skip_reason'] as String?,
  );

  final String taskId;
  final DateTime date;
  final TaskStatus status;
  final String? skipReason;
}

@immutable
class TemplateHistory {
  const TemplateHistory({required this.items, required this.done, required this.window});

  factory TemplateHistory.fromJson(Json json) => TemplateHistory(
    items: parseList(json['items'], TemplateHistoryEntry.fromJson),
    done: intOf(json['done']),
    window: intOf(json['window']),
  );

  final List<TemplateHistoryEntry> items;
  final int done;
  final int window;

  String? get streakLabel => window == 0 ? null : 'Hecha $done de las últimas $window';
}

@immutable
class FrequencyPreview {
  const FrequencyPreview({required this.description, required this.dates, this.ending});

  factory FrequencyPreview.fromJson(Json json) => FrequencyPreview(
    description: json['description'] as String? ?? '',
    ending: json['ending'] as String?,
    dates: [for (final date in (json['dates'] as List? ?? const [])) parseIsoDate('$date')],
  );

  final String description;
  final String? ending;
  final List<DateTime> dates;
}

@immutable
class TasksSettings {
  const TasksSettings({this.defaultListId, this.defaultPolicy = TemplatePolicy.replace, this.showDoneInToday = true});

  factory TasksSettings.fromJson(Map<String, dynamic> json) => TasksSettings(
    defaultListId: json['default_list_id'] as String?,
    defaultPolicy: TemplatePolicy.of(json['default_policy'] as String?),
    showDoneInToday: json['show_done_in_today'] as bool? ?? true,
  );

  final String? defaultListId;
  final TemplatePolicy defaultPolicy;
  final bool showDoneInToday;
}
