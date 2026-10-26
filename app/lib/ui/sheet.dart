import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

Future<T?> showCarliSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
  bool scrollable = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _SheetBody(title: title, scrollable: scrollable, child: builder(context)),
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.child, this.title, required this.scrollable});

  final Widget child;
  final String? title;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final insets = MediaQuery.viewInsetsOf(context);
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title case final title?)
          Padding(
            padding: const EdgeInsets.fromLTRB(CarliSpace.s20, 0, CarliSpace.s20, CarliSpace.s12),
            child: Semantics(
              header: true,
              child: Text(title, style: CarliType.h2.copyWith(fontSize: 18, color: colors.text)),
            ),
          ),
        Flexible(child: child),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: scrollable ? body : SingleChildScrollView(child: body),
      ),
    );
  }
}

Future<bool> confirmCarli(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final confirmed = await showCupertinoDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (context) => CupertinoAlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
