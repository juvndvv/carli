import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card.dart';
import 'empty_state.dart';
import 'icon_names.dart';

class AsyncView<T> extends StatelessWidget {
  const AsyncView({
    super.key,
    required this.value,
    required this.data,
    required this.loading,
    required this.errorTitle,
    required this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget loading;
  final String errorTitle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return switch (value) {
      AsyncValue(hasValue: true, :final value) => data(value as T),
      AsyncValue(hasError: true) => CarliCard(
        child: CarliEmptyState(
          icon: carliIconNamed('circle-alert'),
          title: errorTitle,
          message: 'Comprueba tu conexión e inténtalo de nuevo.',
          actionLabel: 'Reintentar',
          onAction: onRetry,
        ),
      ),
      _ => loading,
    };
  }
}
