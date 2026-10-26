import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/reminders/daily_reminder_controller.dart';
import '../../../core/reminders/reminder_settings.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/button.dart';
import '../../../ui/card.dart';
import '../../../ui/empty_state.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/list_item.dart';
import '../../../ui/page.dart';
import '../../../ui/sheet.dart';
import '../../../ui/skeleton.dart';
import '../../../ui/switch.dart';
import '../../../ui/toast.dart';
import 'notification_preferences.dart';

class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(notificationPreferencesProvider);
    return CarliPage(
      title: 'Avisos',
      onRefresh: () async {
        ref.invalidate(notificationPreferencesProvider);
        await ref.read(dailyReminderProvider.notifier).activate().then((_) {}, onError: (_) {});
        await ref.read(notificationPreferencesProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverList.list(
          children: [
            const CarliSection(title: 'En este iPhone', child: DailyReminderCard()),
            AsyncView(
              value: preferences,
              errorTitle: 'No se han podido cargar los avisos',
              onRetry: () => ref.invalidate(notificationPreferencesProvider),
              loading: const CarliSection(
                child: CarliCard(
                  child: Column(
                    spacing: CarliSpace.s12,
                    children: [CarliSkeleton(height: 44), CarliSkeleton(height: 44), CarliSkeleton(height: 44)],
                  ),
                ),
              ),
              data: (groups) => groups.every((group) => group.types.isEmpty)
                  ? CarliSection(
                      child: CarliCard(
                        child: CarliEmptyState(
                          icon: carliIconNamed('bell-off'),
                          title: 'No hay tipos de aviso configurables',
                          message: 'Cuando actives módulos con avisos aparecerán aquí.',
                        ),
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final group in groups)
                          if (group.types.isNotEmpty)
                            CarliSection(
                              title: group.name,
                              child: _PreferenceGroupCard(group: group),
                            ),
                        const _PushFootnote(),
                      ],
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class DailyReminderCard extends ConsumerWidget {
  const DailyReminderCard({super.key});

  Future<void> _run(WidgetRef ref, Future<void> Function() action) async {
    try {
      await action();
    } on Object {
      ref.read(toastControllerProvider.notifier).error('No se ha podido actualizar el recordatorio');
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref, ReminderTime current) async {
    final picked = await showCarliSheet<ReminderTime>(
      context,
      title: 'Hora del recordatorio',
      builder: (context) => _TimePickerSheet(initial: current),
    );
    if (picked != null && picked != current) {
      await _run(ref, () => ref.read(dailyReminderProvider.notifier).setTime(picked));
    }
  }

  Future<void> _sendTest(WidgetRef ref) async {
    final toast = ref.read(toastControllerProvider.notifier);
    try {
      final sent = await ref.read(dailyReminderProvider.notifier).sendTest();
      if (sent) {
        toast.show('Aviso de prueba enviado');
      } else {
        toast.error('Permite las notificaciones para recibir avisos');
      }
    } on Object {
      toast.error('No se ha podido enviar el aviso de prueba');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminder = ref.watch(dailyReminderProvider);
    final colors = context.colors;
    return switch (reminder) {
      AsyncValue(hasValue: true, value: final DailyReminderState state) => CarliCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CarliListItem(
              icon: carliIconNamed('bell'),
              title: 'Recordatorio diario',
              subtitle: 'Te avisa de lo que tengas por revisar',
              trailing: CarliSwitch(
                value: state.settings.enabled,
                semanticLabel: 'Recordatorio diario',
                onChanged: (value) => _run(ref, () => ref.read(dailyReminderProvider.notifier).setEnabled(value)),
              ),
            ),
            if (state.settings.enabled) ...[
              Divider(height: 1, indent: CarliSpace.s16, color: colors.border),
              CarliListItem(
                icon: carliIconNamed('clock'),
                title: 'Hora',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: CarliSpace.s4,
                  children: [
                    Text(
                      state.settings.time.label,
                      style: CarliType.money(CarliType.bodyStrong).copyWith(color: colors.text),
                    ),
                    CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
                  ],
                ),
                onTap: () => _pickTime(context, ref, state.settings.time),
              ),
            ],
            if (state.blocked) const _PermissionHint(),
            Padding(
              padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s4, CarliSpace.s16, CarliSpace.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: CarliSpace.s12,
                children: [
                  Text(
                    'Se programa con lo que tengas pendiente al abrir la app.',
                    style: CarliType.small.copyWith(color: colors.text2),
                  ),
                  CarliButton(
                    label: 'Probar aviso',
                    icon: carliIconNamed('send'),
                    variant: CarliButtonVariant.secondary,
                    size: CarliButtonSize.md,
                    onPressed: () => _sendTest(ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      AsyncValue(hasError: true) => CarliCard(
        child: CarliEmptyState(
          icon: carliIconNamed('circle-alert'),
          title: 'No se ha podido cargar el recordatorio',
          message: 'Inténtalo de nuevo en unos segundos.',
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(dailyReminderProvider),
        ),
      ),
      _ => const CarliCard(child: CarliSkeleton(height: 44)),
    };
  }
}

class _PermissionHint extends StatelessWidget {
  const _PermissionHint();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s4, CarliSpace.s16, CarliSpace.s8),
      padding: const EdgeInsets.all(CarliSpace.s12),
      decoration: BoxDecoration(color: colors.warningSoft, borderRadius: BorderRadius.circular(CarliRadius.md)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: CarliSpace.s8,
        children: [
          CarliIcon(carliIconNamed('bell-off'), size: 18, color: colors.warning),
          Expanded(
            child: Text(
              'Las notificaciones están desactivadas. Actívalas en Ajustes de iOS > carli > Notificaciones.',
              style: CarliType.small.copyWith(color: colors.text),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePickerSheet extends StatefulWidget {
  const _TimePickerSheet({required this.initial});

  final ReminderTime initial;

  @override
  State<_TimePickerSheet> createState() => _TimePickerSheetState();
}

class _TimePickerSheetState extends State<_TimePickerSheet> {
  late var _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, 0, CarliSpace.s16, CarliSpace.s16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: CarliSpace.s16,
        children: [
          SizedBox(
            height: 200,
            child: CupertinoTheme(
              data: CupertinoThemeData(
                brightness: Theme.of(context).brightness,
                textTheme: CupertinoTextThemeData(
                  dateTimePickerTextStyle: CarliType.h2.copyWith(fontSize: 22, color: colors.text),
                ),
              ),
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: DateTime(2000, 1, 1, widget.initial.hour, widget.initial.minute),
                onDateTimeChanged: (value) => setState(() => _selected = ReminderTime(value.hour, value.minute)),
              ),
            ),
          ),
          CarliButton(label: 'Guardar', onPressed: () => Navigator.pop(context, _selected)),
        ],
      ),
    );
  }
}

class _PreferenceGroupCard extends ConsumerWidget {
  const _PreferenceGroupCard({required this.group});

  final NotificationPreferenceGroup group;

  Future<void> _toggle(
    WidgetRef ref,
    NotificationPreference preference,
    NotificationChannel channel,
    bool value,
  ) async {
    try {
      await ref.read(notificationPreferencesProvider.notifier).toggle(preference, channel, value);
    } on Object {
      ref.read(toastControllerProvider.notifier).error('No se han podido guardar las preferencias');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return CarliCard(
      padding: const EdgeInsets.symmetric(vertical: CarliSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s4),
            child: ExcludeSemantics(
              child: Row(
                children: [
                  Expanded(
                    child: Text('Aviso', style: CarliType.caption.copyWith(color: colors.text3)),
                  ),
                  _ChannelCell(
                    child: Text('Push', style: CarliType.caption.copyWith(color: colors.text3)),
                  ),
                  _ChannelCell(
                    child: Text('En la app', style: CarliType.caption.copyWith(color: colors.text3)),
                  ),
                ],
              ),
            ),
          ),
          for (final (index, preference) in group.types.indexed) ...[
            if (index > 0) Divider(height: 1, indent: CarliSpace.s16, color: colors.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          preference.label,
                          style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                        ),
                        if (preference.description case final description?)
                          Text(description, style: CarliType.small.copyWith(color: colors.text2)),
                      ],
                    ),
                  ),
                  for (final (channel, name) in const [
                    (NotificationChannel.push, 'Push'),
                    (NotificationChannel.inApp, 'En la app'),
                  ])
                    _ChannelCell(
                      child: CarliSwitch(
                        value: preference.enabledOn(channel),
                        semanticLabel: '$name: ${preference.label}',
                        onChanged: (value) => _toggle(ref, preference, channel, value),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChannelCell extends StatelessWidget {
  const _ChannelCell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(width: 72, child: Center(child: child));
}

class _PushFootnote extends StatelessWidget {
  const _PushFootnote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s12, CarliSpace.s16, 0),
      child: Text(
        'Push llega a los navegadores donde activaste las notificaciones web. En este iPhone te avisa el recordatorio diario.',
        style: CarliType.small.copyWith(color: context.colors.text3),
      ),
    );
  }
}
