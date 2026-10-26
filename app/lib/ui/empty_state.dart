import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'button.dart';
import 'icon.dart';

class CarliEmptyState extends StatelessWidget {
  const CarliEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final CarliIconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s24, vertical: CarliSpace.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: CarliSpace.s12,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
            child: CarliIcon(icon, size: 26, color: colors.text2),
          ),
          Text(
            title,
            textAlign: TextAlign.center,
            style: CarliType.h2.copyWith(color: colors.text),
          ),
          Text(
            message,
            textAlign: TextAlign.center,
            style: CarliType.small.copyWith(color: colors.text2),
          ),
          if (actionLabel case final label?)
            Padding(
              padding: const EdgeInsets.only(top: CarliSpace.s4),
              child: CarliButton(label: label, onPressed: onAction, size: CarliButtonSize.md, block: false),
            ),
        ],
      ),
    );
  }
}
