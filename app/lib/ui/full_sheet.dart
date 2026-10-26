import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

Future<T?> showFullSheet<T>(BuildContext context, WidgetBuilder builder) => showModalBottomSheet<T>(
  context: context,
  useRootNavigator: true,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: false,
  builder: (context) => FractionallySizedBox(heightFactor: 0.94, child: builder(context)),
);

class FullSheetHeader extends StatelessWidget {
  const FullSheetHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leadingLabel = 'Cancelar',
    required this.onLeading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String leadingLabel;
  final VoidCallback onLeading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 88,
            child: Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onLeading,
                style: TextButton.styleFrom(foregroundColor: colors.text2, textStyle: CarliType.body),
                child: Text(leadingLabel),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CarliType.h2.copyWith(color: colors.text),
                  ),
                  if (subtitle case final subtitle?)
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: CarliType.caption.copyWith(color: colors.text3),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: Align(alignment: Alignment.centerRight, child: trailing),
          ),
        ],
      ),
    );
  }
}

class SaveHeaderAction extends StatelessWidget {
  const SaveHeaderAction({super.key, required this.saving, required this.onSave, this.label = 'Guardar'});

  final bool saving;
  final VoidCallback? onSave;
  final String label;

  @override
  Widget build(BuildContext context) => saving
      ? const Center(child: SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)))
      : TextButton(onPressed: onSave, child: Text(label));
}

class FormError extends StatelessWidget {
  const FormError(this.message, {super.key, this.center = false});

  final String message;
  final bool center;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      message,
      textAlign: center ? TextAlign.center : TextAlign.start,
      style: CarliType.small.copyWith(color: context.colors.negative),
    ),
  );
}
