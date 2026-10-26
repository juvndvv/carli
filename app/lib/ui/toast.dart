import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'pressable.dart';

enum ToastTone { normal, error }

class ToastAction {
  const ToastAction(this.label, this.handler);

  final String label;
  final FutureOr<void> Function() handler;
}

@immutable
class Toast {
  const Toast({
    required this.id,
    required this.message,
    this.action,
    this.tone = ToastTone.normal,
    required this.duration,
  });

  final int id;
  final String message;
  final ToastAction? action;
  final ToastTone tone;
  final Duration duration;
}

const defaultToastDuration = Duration(seconds: 5);

final toastControllerProvider = NotifierProvider<ToastController, Toast?>(ToastController.new);

class ToastController extends Notifier<Toast?> {
  final _queue = <Toast>[];
  Timer? _timer;
  var _nextId = 1;

  @override
  Toast? build() {
    ref.onDispose(() => _timer?.cancel());
    return null;
  }

  int show(
    String message, {
    ToastAction? action,
    ToastTone tone = ToastTone.normal,
    Duration duration = defaultToastDuration,
  }) {
    final toast = Toast(id: _nextId++, message: message, action: action, tone: tone, duration: duration);
    _display(toast);
    return toast.id;
  }

  int enqueue(String message, {ToastAction? action, Duration duration = defaultToastDuration}) {
    if (state?.action == null) return show(message, action: action, duration: duration);
    final toast = Toast(id: _nextId++, message: message, action: action, duration: duration);
    _queue.add(toast);
    return toast.id;
  }

  int withUndo(String message, FutureOr<void> Function() undo, {Duration duration = defaultToastDuration}) =>
      show(message, action: ToastAction('Deshacer', undo), duration: duration);

  int error(String message) => show(message, tone: ToastTone.error);

  Future<void> runAction(int id) async {
    final action = state?.id == id ? state?.action : null;
    _queue.clear();
    dismiss(id);
    await action?.handler();
  }

  void dismiss(int id) {
    _queue.removeWhere((toast) => toast.id == id);
    if (state?.id != id) return;
    _timer?.cancel();
    state = null;
    if (_queue.isNotEmpty) _display(_queue.removeAt(0));
  }

  void _display(Toast toast) {
    _timer?.cancel();
    state = toast;
    if (toast.duration > Duration.zero) _timer = Timer(toast.duration, () => dismiss(toast.id));
  }
}

class ToastHost extends ConsumerWidget {
  const ToastHost({super.key, this.bottomOffset = 136});

  final double bottomOffset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toast = ref.watch(toastControllerProvider);
    final colors = context.colors;
    return Positioned(
      left: CarliSpace.s16,
      right: CarliSpace.s16,
      bottom: MediaQuery.paddingOf(context).bottom + bottomOffset,
      child: AnimatedSwitcher(
        duration: CarliMotion.enter,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: toast == null
            ? const SizedBox.shrink()
            : Semantics(
                key: ValueKey(toast.id),
                liveRegion: true,
                container: true,
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 480, minHeight: 48),
                    padding: const EdgeInsets.only(left: CarliSpace.s20, right: CarliSpace.s8),
                    decoration: BoxDecoration(
                      color: toast.tone == ToastTone.error ? colors.negative : colors.text,
                      borderRadius: BorderRadius.circular(CarliRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: CarliSpace.s12),
                            child: Text(
                              toast.message,
                              style: CarliType.small.copyWith(
                                color: toast.tone == ToastTone.error ? colors.onPrimary : colors.surface,
                              ),
                            ),
                          ),
                        ),
                        if (toast.action case final action?)
                          Semantics(
                            button: true,
                            child: Pressable(
                              onTap: () => ref.read(toastControllerProvider.notifier).runAction(toast.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: CarliSpace.s12,
                                  vertical: CarliSpace.s12,
                                ),
                                child: Text(
                                  action.label,
                                  style: CarliType.small.copyWith(fontWeight: FontWeight.w600, color: colors.surface),
                                ),
                              ),
                            ),
                          )
                        else
                          const SizedBox(width: CarliSpace.s12),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
