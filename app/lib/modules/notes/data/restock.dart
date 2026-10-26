import 'package:uuid/uuid.dart';

import '../../../core/format/dates.dart';
import 'models.dart';

const restockNamespace = '6f0b5c3e-2d4a-5b8e-9c1f-7a3d2e1b0c9d';

String restockCycleKey(String productId, DateTime lastBoughtAt) =>
    '$productId:${lastBoughtAt.millisecondsSinceEpoch ~/ 1000}';

String restockItemId(String cycleKey) => const Uuid().v5(restockNamespace, cycleKey);

/// The day a product comes back to its list, counted from the local date of its last purchase.
DateTime? restockDate(ShoppingProduct product) {
  final boughtAt = product.lastBoughtAt;
  if (boughtAt == null) return null;
  final bought = dateOnly(boughtAt.toLocal());
  return switch (product.restockMode) {
    RestockMode.none => null,
    RestockMode.everyTrip => bought,
    RestockMode.interval => switch (product.restockIntervalDays) {
      final days? when days >= 1 => DateTime(bought.year, bought.month, bought.day + days),
      _ => null,
    },
  };
}

bool isRestockDue(ShoppingProduct product, DateTime today) {
  final date = restockDate(product);
  return date != null && !date.isAfter(dateOnly(today));
}

/// Products whose turn has come and that are neither on the list nor already brought back in this cycle.
List<ShoppingProduct> productsToRestock({
  required Iterable<ShoppingProduct> products,
  required Iterable<NoteItem> items,
  required DateTime today,
}) {
  final listed = {for (final item in items) ?item.productId};
  return [
    for (final product in products)
      if (isRestockDue(product, today) &&
          !listed.contains(product.id) &&
          product.restockedFor != restockCycleKey(product.id, product.lastBoughtAt!))
        product,
  ];
}

String restockLabel(ShoppingProduct product) => switch (product.restockMode) {
  RestockMode.none => 'Sin repetir',
  RestockMode.everyTrip => 'Cada compra',
  RestockMode.interval => intervalLabel(product.restockIntervalDays ?? 7),
};

String intervalLabel(int days) {
  if (days % 30 == 0) return days == 30 ? 'Cada mes' : 'Cada ${days ~/ 30} meses';
  if (days % 7 == 0) return days == 7 ? 'Cada semana' : 'Cada ${days ~/ 7} semanas';
  return days == 1 ? 'Cada día' : 'Cada $days días';
}
