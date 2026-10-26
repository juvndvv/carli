import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/format/dates.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/button.dart';
import '../../../ui/chip.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/toast.dart';
import '../../finance/data/json.dart';
import '../data/quick_dates.dart';
import '../data/task_actions.dart';
import '../data/tasks_models.dart';
import '../data/tasks_providers.dart';
import '../ui/pickers.dart';
import '../ui/postpone_sheet.dart';
import '../ui/tasks_routes.dart';
import 'template_editor_screen.dart';

Future<void> showNewTaskSheet(BuildContext context, {String? listId, DateTime? date}) => showModalBottomSheet<void>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (context) => NewTaskSheet(listId: listId, date: date ?? today()),
);

const _whenChips = [QuickDate.today, QuickDate.tomorrow, QuickDate.weekend, QuickDate.none];

class NewTaskSheet extends ConsumerStatefulWidget {
  const NewTaskSheet({super.key, this.listId, this.date});

  final String? listId;
  final DateTime? date;

  @override
  ConsumerState<NewTaskSheet> createState() => _NewTaskSheetState();
}

class _NewTaskSheetState extends ConsumerState<NewTaskSheet> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  late DateTime? _date = widget.date;
  late String? _listId = widget.listId;
  String? _time;
  var _important = false;
  var _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  bool get _canSave => _title.text.trim().isNotEmpty && !_saving;

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final created = await ref.read(taskActionsProvider).create({
      'title': _title.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
      'list_id': ?_listId,
      'due_date': _date == null ? null : isoDate(_date!),
      if (_date != null) 'due_time': _time,
      'important': _important,
    });
    if (!mounted) return;
    if (created == null) {
      setState(() => _saving = false);
      return;
    }
    ref.read(toastControllerProvider.notifier).show('Tarea añadida');
    Navigator.pop(context);
  }

  Future<void> _pickDate() async {
    final picked = await pickTaskDate(context, initial: _date);
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickList(List<TaskList> lists) async {
    final picked = await pickTaskList(context, lists: lists, current: _listId ?? _defaultListId(lists));
    if (picked != null) setState(() => _listId = picked);
  }

  Future<void> _pickTime() async {
    final picked = await pickTaskTime(context, initial: _time);
    if (picked == null) return;
    setState(() {
      _time = picked.$1;
      if (_time != null) _date ??= today();
    });
  }

  void _repeat() {
    final router = GoRouter.of(context);
    Navigator.pop(context);
    router.push(
      TasksRoutes.newTemplate,
      extra: TemplateSeed(
        title: _title.text.trim(),
        notes: _notes.text.trim(),
        listId: _listId,
        dueTime: _time,
        important: _important,
        start: _date,
      ),
    );
  }

  String? _defaultListId(List<TaskList> lists) =>
      ref.read(tasksSettingsProvider).defaultListId ?? lists.where((list) => list.isDefault).firstOrNull?.id;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lists = ref.watch(taskListsProvider).value ?? const <TaskList>[];
    final listId = _listId ?? _defaultListId(lists);
    final listName = lists.where((list) => list.id == listId).firstOrNull?.name ?? 'Bandeja';
    final quick = quickDateOf(_date);
    final custom = quick == null || !_whenChips.contains(quick);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: CarliSpace.s16,
          children: [
            Semantics(
              header: true,
              child: Text(
                'Nueva tarea',
                textAlign: TextAlign.center,
                style: CarliType.h2.copyWith(color: colors.text),
              ),
            ),
            TextField(
              controller: _title,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _save(),
              style: CarliType.title2.copyWith(color: colors.text),
              decoration: const InputDecoration(
                hintText: '¿Qué hay que hacer?',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            TextField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              style: CarliType.body.copyWith(color: colors.text),
              decoration: const InputDecoration(
                hintText: 'Notas',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            Text('CUÁNDO', style: CarliType.eyebrow.copyWith(color: colors.text2)),
            Wrap(
              spacing: CarliSpace.s8,
              runSpacing: CarliSpace.s8,
              children: [
                for (final option in _whenChips)
                  CarliChip(
                    label: option.label,
                    selected: !custom && quick == option,
                    onTap: () => setState(() {
                      _date = option.resolve();
                      if (_date == null) _time = null;
                    }),
                  ),
                CarliChip(
                  icon: carliIconNamed('calendar'),
                  label: custom && _date != null ? weekdayShortDate(_date!) : 'Elegir…',
                  selected: custom && _date != null,
                  onTap: _pickDate,
                ),
              ],
            ),
            Wrap(
              spacing: CarliSpace.s8,
              runSpacing: CarliSpace.s8,
              children: [
                CarliChip(icon: carliIconNamed('list'), label: listName, onTap: () => _pickList(lists)),
                CarliChip(
                  icon: carliIconNamed('clock'),
                  label: _time ?? 'Hora',
                  selected: _time != null,
                  onTap: _pickTime,
                ),
                CarliChip(icon: carliIconNamed('repeat'), label: 'Repetir', onTap: _repeat),
                CarliChip(
                  icon: carliIconNamed('flag'),
                  selected: _important,
                  semanticLabel: _important ? 'Importante, activado' : 'Marcar como importante',
                  onTap: () => setState(() => _important = !_important),
                ),
              ],
            ),
            CarliButton(label: 'Añadir', loading: _saving, onPressed: _canSave ? _save : null),
          ],
        ),
      ),
    );
  }
}
