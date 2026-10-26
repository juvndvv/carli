import 'package:flutter/widgets.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'icon.dart';
import 'pressable.dart';

class CarliListItem extends StatelessWidget {
  const CarliListItem({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final CarliIconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lead =
        leading ??
        (icon == null
            ? null
            : Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.surface2, shape: BoxShape.circle),
                child: CarliIcon(icon!, size: 20, color: colors.text),
              ));
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: CarliSpace.s12),
      child: Row(
        spacing: CarliSpace.s12,
        children: [
          ?lead,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CarliType.body.copyWith(fontWeight: FontWeight.w500, color: colors.text),
                ),
                if (subtitle case final subtitle?)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: CarliType.small.copyWith(color: colors.text2),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      child: onTap == null ? row : Pressable(onTap: onTap, pressedOpacity: 0.5, child: row),
    );
  }
}
