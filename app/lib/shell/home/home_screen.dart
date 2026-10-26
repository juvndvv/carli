import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/format/dates.dart';
import '../../core/notifications/notifications_providers.dart';
import '../../core/pending/pending_providers.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../modules/finance/data/finance_changes.dart';
import '../../modules/finance/data/finance_format.dart';
import '../../modules/finance/data/finance_providers.dart';
import '../../modules/finance/ui/finance_home_card.dart';
import '../../ui/button.dart';
import '../../ui/icon_names.dart';
import '../../ui/page.dart';
import '../notifications/notifications_home_card.dart';
import '../notifications/unread_dot.dart';
import '../pending/pending_home_card.dart';
import 'upcoming_modules_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.now});

  final DateTime? now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final auth = ref.watch(authControllerProvider);
    final firstName = switch (auth) {
      SignedIn(:final user?) => user.name.trim().split(RegExp(r'\s+')).first,
      _ => null,
    };
    final moment = now ?? DateTime.now();
    final greeting = greetingFor(moment.hour);
    final hasNotifications = ref.watch(notificationsProvider).value?.items.isNotEmpty ?? false;

    return CarliPage(
      title: firstName == null || firstName.isEmpty ? greeting : '$greeting, $firstName',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: CarliSpace.s4,
        children: [
          CarliButton.icon(
            icon: carliIconNamed('search'),
            semanticLabel: 'Buscar',
            size: CarliButtonSize.sm,
            onPressed: () => context.push(Routes.search),
          ),
          const NotificationsBellButton(),
        ],
      ),
      onRefresh: () async {
        ref.read(financeChangesProvider.notifier).refreshAll();
        await Future.wait([
          ref.read(financeSummaryProvider.future).then((_) {}, onError: (_) {}),
          ref.read(pendingSummaryProvider.notifier).refresh().then((_) {}, onError: (_) {}),
          ref.read(unreadNotificationsCountProvider.notifier).refresh().then((_) {}, onError: (_) {}),
        ]);
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverList.list(
            children: [
              Text(formatLongDate(moment), style: CarliType.small.copyWith(color: colors.text2)),
              const SizedBox(height: CarliSpace.s16),
              if (hasNotifications) ...[const NotificationsHomeCard(), const SizedBox(height: CarliSpace.s16)],
              PendingHomeCard(
                bottomGap: CarliSpace.s16,
                onOpen: (filter) => context.push(Routes.pendingFor(filter.queryParameters)),
              ),
              FinanceHomeCard(onTap: () => context.go(Routes.summary)),
              const UpcomingModulesCard(),
              if (!hasNotifications) ...[const SizedBox(height: CarliSpace.s16), const NotificationsHomeCard()],
            ],
          ),
        ),
      ],
    );
  }
}
