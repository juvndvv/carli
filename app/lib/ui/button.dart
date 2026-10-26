import 'package:flutter/cupertino.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'icon.dart';
import 'pressable.dart';

enum CarliButtonVariant { primary, secondary, ghost, danger }

enum CarliButtonSize { sm, md, lg }

class CarliButton extends StatelessWidget {
  const CarliButton({
    super.key,
    required String this.label,
    required this.onPressed,
    this.variant = CarliButtonVariant.primary,
    this.size = CarliButtonSize.lg,
    this.icon,
    this.loading = false,
    this.block = true,
  }) : semanticLabel = null;

  const CarliButton.icon({
    super.key,
    required CarliIconData this.icon,
    required String this.semanticLabel,
    required this.onPressed,
    this.variant = CarliButtonVariant.ghost,
    this.size = CarliButtonSize.md,
    this.loading = false,
  }) : label = null,
       block = false;

  final String? label;
  final String? semanticLabel;
  final VoidCallback? onPressed;
  final CarliButtonVariant variant;
  final CarliButtonSize size;
  final CarliIconData? icon;
  final bool loading;
  final bool block;

  double get _height => switch (size) {
    CarliButtonSize.sm => 36,
    CarliButtonSize.md => 44,
    CarliButtonSize.lg => 52,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground, border) = switch (variant) {
      CarliButtonVariant.primary => (colors.primary, colors.onPrimary, null),
      CarliButtonVariant.secondary => (colors.surface, colors.text, colors.border),
      CarliButtonVariant.ghost => (colors.surface2, colors.text, null),
      CarliButtonVariant.danger => (CarliColors.dangerFill, colors.onPrimary, null),
    };
    final iconOnly = label == null;
    final enabled = onPressed != null && !loading;
    final iconSize = size == CarliButtonSize.sm ? 16.0 : 20.0;
    final textStyle = (size == CarliButtonSize.sm ? CarliType.small : CarliType.body).copyWith(
      fontWeight: FontWeight.w600,
      color: foreground,
    );

    final content = loading
        ? CupertinoActivityIndicator(color: foreground, radius: iconSize / 2.2)
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: CarliSpace.s8,
            children: [
              if (icon case final icon?) CarliIcon(icon, size: iconSize, color: foreground),
              if (label case final label?)
                Flexible(
                  child: Text(label, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          );

    final radius = iconOnly
        ? BorderRadius.circular(CarliRadius.full)
        : BorderRadius.circular(size == CarliButtonSize.lg ? CarliRadius.controlLg : CarliRadius.control);

    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      excludeSemantics: iconOnly,
      child: Opacity(
        opacity: onPressed == null && !loading ? 0.4 : 1,
        child: Pressable(
          onTap: enabled ? onPressed : null,
          child: Container(
            height: _height,
            width: iconOnly ? _height : (block ? double.infinity : null),
            padding: iconOnly
                ? null
                : EdgeInsets.symmetric(horizontal: size == CarliButtonSize.sm ? CarliSpace.s12 : CarliSpace.s20),
            alignment: iconOnly || block ? Alignment.center : null,
            decoration: BoxDecoration(
              color: background,
              borderRadius: radius,
              border: border == null ? null : Border.all(color: border),
            ),
            child: iconOnly || block ? content : Center(widthFactor: 1, child: content),
          ),
        ),
      ),
    );
  }
}
