import 'json.dart';
import 'models.dart';
import 'transactions_repository.dart';

enum ShareMode {
  equal('equal', 'A partes iguales'),
  percentage('percentage', 'Porcentaje'),
  amount('amount', 'Importe');

  const ShareMode(this.api, this.label);

  final String api;
  final String label;
}

class SplitDraft {
  SplitDraft({this.categoryId, this.amount});

  String? categoryId;
  Cents? amount;
}

class ShareDraft {
  ShareDraft({required this.contactId, required this.name, this.percentage, this.amount});

  final String contactId;
  final String name;
  double? percentage;
  Cents? amount;
}

typedef SharePreview = ({String contactId, String name, Cents amount});

Cents splitRemaining(Cents total, List<SplitDraft> splits) =>
    total.abs() - splits.fold<int>(0, (sum, split) => sum + (split.amount ?? 0).abs());

List<Json> toSplitInputs(TransactionKind kind, List<SplitDraft> splits) => [
  for (final split in splits)
    if (split.categoryId != null && (split.amount ?? 0) != 0)
      {'category_id': split.categoryId, 'amount_cents': signedAmount(kind, split.amount!)},
];

List<SharePreview> previewShares(Cents total, ShareMode mode, bool includeSelf, List<ShareDraft> items) {
  final absolute = total.abs();
  if (items.isEmpty || absolute == 0) {
    return [for (final item in items) (contactId: item.contactId, name: item.name, amount: 0)];
  }
  switch (mode) {
    case ShareMode.equal:
      final parts = items.length + (includeSelf ? 1 : 0);
      final base = absolute ~/ parts;
      final remainder = includeSelf ? 0 : absolute - base * parts;
      return [
        for (final (index, item) in items.indexed)
          (contactId: item.contactId, name: item.name, amount: base + (index < remainder ? 1 : 0)),
      ];
    case ShareMode.percentage:
      return [
        for (final item in items)
          (
            contactId: item.contactId,
            name: item.name,
            amount: (absolute * ((item.percentage ?? 0) * 100).round() / 10000).round(),
          ),
      ];
    case ShareMode.amount:
      return [for (final item in items) (contactId: item.contactId, name: item.name, amount: item.amount ?? 0)];
  }
}

Json toSharesInput(ShareMode mode, bool includeSelf, List<ShareDraft> items) => {
  'mode': mode.api,
  if (mode == ShareMode.equal) 'include_self': includeSelf,
  'items': [
    for (final item in items)
      {
        'contact_id': item.contactId,
        if (mode == ShareMode.percentage) 'percentage': item.percentage,
        if (mode == ShareMode.amount) 'amount_cents': item.amount,
      },
  ],
};

List<String> parseTagInput(String raw) => [
  for (final tag in raw.split(RegExp(r'[,\s]+')))
    if (tag.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase() case final normalized when normalized.isNotEmpty)
      normalized,
];
