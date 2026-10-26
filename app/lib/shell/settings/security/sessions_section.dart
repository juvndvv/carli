import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/async_view.dart';
import '../../../ui/badge.dart';
import '../../../ui/button.dart';
import '../../../ui/card.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/list_item.dart';
import '../../../ui/sheet.dart';
import '../../../ui/skeleton.dart';
import '../../../ui/toast.dart';
import '../../notifications/time_ago.dart';
import 'data/security_models.dart';
import 'data/security_repository.dart';
import 'password_prompt_sheet.dart';

String appTokenSubtitle(AppToken token, {DateTime? now}) {
  final lastUsed = token.lastUsedAt;
  if (lastUsed != null) return 'App de carli · ${formatTimeAgo(lastUsed, now: now)}';
  final created = token.createdAt;
  return created == null ? 'App de carli' : 'App de carli · ${formatTimeAgo(created, now: now)}';
}

String webSessionSubtitle(WebSession session, {DateTime? now}) =>
    '${session.ipAddress ?? 'IP desconocida'} · ${formatTimeAgo(session.lastActiveAt, now: now)}';

Future<void> logoutOtherSessions(BuildContext context, WidgetRef ref) async {
  final repository = ref.read(securityRepositoryProvider);
  final done = await showPasswordPrompt<bool>(
    context,
    title: 'Cerrar las demás sesiones',
    message: 'Se cerrará la sesión en todos tus otros dispositivos. Confirma con tu contraseña.',
    confirmLabel: 'Cerrar sesiones',
    destructive: true,
    action: (password) async {
      await repository.logoutOthers(password);
      return true;
    },
  );
  if (done != true) return;
  ref.read(toastControllerProvider.notifier).show('Sesiones cerradas en los demás dispositivos');
  ref.invalidate(activeSessionsProvider);
}

class ActiveSessionsCard extends ConsumerWidget {
  const ActiveSessionsCard({super.key});

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref, {
    required String name,
    required Future<void> Function() revoke,
  }) async {
    final confirmed = await confirmCarli(
      context,
      title: 'Cerrar la sesión',
      message: 'Se cerrará la sesión de «$name».',
      confirmLabel: 'Cerrar sesión',
      destructive: true,
    );
    if (!confirmed) return;
    final toast = ref.read(toastControllerProvider.notifier);
    try {
      await revoke();
      toast.show('Sesión cerrada');
    } catch (error) {
      toast.error(apiErrorMessage(error, fallback: 'No se ha podido cerrar la sesión.'));
    }
    ref.invalidate(activeSessionsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.read(securityRepositoryProvider);
    return AsyncView<ActiveSessions>(
      value: ref.watch(activeSessionsProvider),
      errorTitle: 'No se han podido cargar las sesiones',
      onRetry: () => ref.invalidate(activeSessionsProvider),
      loading: const CarliCard(child: CarliSkeleton(height: 56)),
      data: (sessions) {
        final items = [
          for (final token in sessions.tokens)
            CarliListItem(
              key: ValueKey('token-${token.id}'),
              title: token.name,
              subtitle: appTokenSubtitle(token),
              icon: carliIconNamed('smartphone'),
              trailing: token.isCurrent
                  ? const CarliBadge('Este dispositivo', tone: CarliBadgeTone.primary)
                  : _RevokeButton(
                      name: token.name,
                      onPressed: () =>
                          _revoke(context, ref, name: token.name, revoke: () => repository.revokeToken(token.id)),
                    ),
            ),
          for (final session in sessions.webSessions)
            CarliListItem(
              key: ValueKey('session-${session.id}'),
              title: session.device,
              subtitle: webSessionSubtitle(session),
              icon: carliIconNamed(session.isMobile ? 'smartphone' : 'laptop'),
              trailing: session.isCurrent
                  ? const CarliBadge('Este dispositivo', tone: CarliBadgeTone.primary)
                  : _RevokeButton(
                      name: session.device,
                      onPressed: () => _revoke(
                        context,
                        ref,
                        name: session.device,
                        revoke: () => repository.revokeWebSession(session.id),
                      ),
                    ),
            ),
        ];
        return CarliCard(
          padding: const EdgeInsets.symmetric(vertical: CarliSpace.s4),
          child: items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(CarliSpace.s16),
                  child: Text(
                    'No hay información de sesiones.',
                    style: CarliType.small.copyWith(color: context.colors.text3),
                  ),
                )
              : Column(children: items),
        );
      },
    );
  }
}

class _RevokeButton extends StatelessWidget {
  const _RevokeButton({required this.name, required this.onPressed});

  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CarliButton.icon(
    icon: carliIconNamed('log-out'),
    semanticLabel: 'Cerrar la sesión de $name',
    size: CarliButtonSize.sm,
    onPressed: onPressed,
  );
}
