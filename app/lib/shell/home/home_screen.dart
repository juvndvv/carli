import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/format/dates.dart';
import '../../core/router/router.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import '../../modules/finance/data/finance_changes.dart';
import '../../modules/finance/data/finance_format.dart';
import '../../modules/finance/data/finance_providers.dart';
import '../../modules/finance/ui/finance_home_card.dart';
import '../../ui/page.dart';

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

    return CarliPage(
      title: firstName == null || firstName.isEmpty ? greeting : '$greeting, $firstName',
      onRefresh: () async {
        ref.read(financeChangesProvider.notifier).refreshAll();
        await ref.read(financeSummaryProvider.future).then((_) {}, onError: (_) {});
      },
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          sliver: SliverList.list(
            children: [
              Text(formatLongDate(moment), style: CarliType.small.copyWith(color: colors.text2)),
              const SizedBox(height: CarliSpace.s16),
              FinanceHomeCard(onTap: () => context.go(Routes.summary)),
            ],
          ),
        ),
      ],
    );
  }
}
