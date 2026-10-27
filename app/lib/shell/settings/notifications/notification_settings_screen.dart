import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_controller.dart';
import '../../../core/push/push_platform.dart';
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
        await ref.read(pushControllerProvider.notifier).activate().then((_) {}, onError: (_) {});
        await ref.read(notificationPreferencesProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverList.list(
          children: [
            const CarliSection(title: 'En este iPhone', child: PushCard()),
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

class PushCard extends ConsumerWidget {
  const PushCard({super.key});

  Future<void> _activate(WidgetRef ref) async {
    try {
      await ref.read(pushControllerProvider.notifier).activate();
    } on Object {
      ref.read(toastControllerProvider.notifier).error('No se han podido activar las notificaciones');
    }
  }

  Future<void> _sendTest(WidgetRef ref) async {
    final toast = ref.read(toastControllerProvider.notifier);
    try {
      final pushed = await ref.read(pushControllerProvider.notifier).sendTest();
      if (pushed) {
        toast.show('Aviso de prueba enviado');
      } else {
        toast.error('El aviso de prueba solo ha llegado a la bandeja');
      }
    } on Object {
      toast.error('No se ha podido enviar el aviso de prueba');
    }
  }

  String _subtitle(PushState state) => switch (state) {
    PushState(permission: PushPermission.denied) => 'Desactivadas en iOS',
    PushState(permission: PushPermission.notDetermined) => 'Aún no las has permitido',
    PushState(registrationFailed: true) => 'No se ha podido registrar este iPhone',
    PushState(active: true) => 'Activadas en este iPhone',
    PushState(registered: true) => 'El servidor aún no tiene el envío push configurado',
    _ => 'Registrando este iPhone…',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(pushControllerProvider);
    return switch (push) {
      AsyncValue(hasValue: true, value: final PushState state) => CarliCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CarliListItem(
              icon: carliIconNamed(state.permission == PushPermission.denied ? 'bell-off' : 'bell'),
              title: 'Notificaciones push',
              subtitle: _subtitle(state),
            ),
            if (state.permission == PushPermission.denied) const _PermissionHint(),
            Padding(
              padding: const EdgeInsets.fromLTRB(CarliSpace.s16, CarliSpace.s4, CarliSpace.s16, CarliSpace.s16),
              child: switch (state) {
                PushState(permission: PushPermission.notDetermined) ||
                PushState(registrationFailed: true) => CarliButton(
                  label: state.registrationFailed ? 'Reintentar' : 'Activar notificaciones',
                  icon: carliIconNamed('bell'),
                  size: CarliButtonSize.md,
                  onPressed: () => _activate(ref),
                ),
                PushState(registered: true) => CarliButton(
                  label: 'Probar aviso',
                  icon: carliIconNamed('send'),
                  variant: CarliButtonVariant.secondary,
                  size: CarliButtonSize.md,
                  onPressed: () => _sendTest(ref),
                ),
                _ => const SizedBox.shrink(),
              },
            ),
          ],
        ),
      ),
      AsyncValue(hasError: true) => CarliCard(
        child: CarliEmptyState(
          icon: carliIconNamed('circle-alert'),
          title: 'No se han podido comprobar las notificaciones',
          message: 'Inténtalo de nuevo en unos segundos.',
          actionLabel: 'Reintentar',
          onAction: () => ref.invalidate(pushControllerProvider),
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
      ref.read(toastControllerProvider.notifier).error('No se han podido guardar los ajustes de avisos');
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
        'Push llega a este iPhone. El resumen de pendientes sale a las 20:00 si tienes algo por revisar.',
        style: CarliType.small.copyWith(color: context.colors.text3),
      ),
    );
  }
}
