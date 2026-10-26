import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_error.dart';
import '../../../ui/toast.dart';
import 'bank.dart';
import 'finance_providers.dart';
import 'models.dart';

const similarOfferDuration = Duration(seconds: 10);

String similarMessage(int count) =>
    count == 1 ? 'Hay 1 movimiento parecido sin categoría' : 'Hay $count movimientos parecidos sin categoría';

String applySimilarLabel(int count) =>
    count == 1 ? 'Aplicar al parecido y recordar' : 'Aplicar a los $count parecidos y recordar';

String appliedMessage(int updated, String? pattern, String category) {
  final moved = updated == 1 ? '1 movimiento más' : '$updated movimientos más';
  return pattern == null ? '$moved en $category' : '$moved en $category · regla «$pattern» guardada';
}

bool categorizedImport(Transaction? original, Transaction saved) =>
    original != null &&
    original.categoryId == null &&
    !original.isSplit &&
    (original.kind == TransactionKind.expense || original.kind == TransactionKind.income) &&
    saved.kind == original.kind &&
    saved.categoryId != null &&
    !saved.isSplit;

Future<bool> offerSimilarCategorization(Ref ref, String transactionId, String categoryId) async {
  final bank = ref.read(bankRepositoryProvider);
  final toasts = ref.read(toastControllerProvider.notifier);
  final int count;
  try {
    count = await bank.similarCount(transactionId);
  } on Object {
    return false;
  }
  if (count == 0) return false;
  toasts.enqueue(
    similarMessage(count),
    duration: similarOfferDuration,
    action: ToastAction(applySimilarLabel(count), () async {
      try {
        final result = await bank.categorizeSimilar(transactionId, categoryId);
        final category = ref.read(categoriesProvider).value?.find(categoryId)?.label ?? 'la categoría elegida';
        toasts.show(appliedMessage(result.updated, result.pattern, category));
      } catch (error) {
        toasts.error(apiErrorMessage(error, fallback: 'No se han podido categorizar los parecidos.'));
      }
    }),
  );
  return true;
}

final similarCategorizationProvider = Provider<Future<bool> Function(String transactionId, String categoryId)>(
  (ref) =>
      (transactionId, categoryId) => offerSimilarCategorization(ref, transactionId, categoryId),
);
