import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pending/pending_providers.dart';
import '../../ui/badge.dart';

String pendingBadgeLabel(int count) => count > 99 ? '99+' : '$count';

class PendingBadge extends ConsumerWidget {
  const PendingBadge({super.key, this.tone = CarliBadgeTone.warning});

  final CarliBadgeTone tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(pendingTotalProvider);
    if (total <= 0) return const SizedBox.shrink();
    return Semantics(
      label: total == 1 ? '1 pendiente' : '$total pendientes',
      excludeSemantics: true,
      child: CarliBadge(pendingBadgeLabel(total), tone: tone),
    );
  }
}
