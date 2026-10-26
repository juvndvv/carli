import 'package:flutter/widgets.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/theme/typography.dart';
import '../../../ui/icon.dart';
import '../../../ui/icon_names.dart';
import '../../../ui/pressable.dart';

class FormRow extends StatelessWidget {
  const FormRow({super.key, required this.label, this.value, this.trailing, this.onTap, this.chevron = true});

  final String label;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 13),
      child: Row(
        spacing: CarliSpace.s8,
        children: [
          if (value == null)
            Expanded(
              child: Text(label, style: CarliType.body.copyWith(color: colors.text)),
            )
          else
            Flexible(
              flex: 3,
              child: Text(label, style: CarliType.body.copyWith(color: colors.text)),
            ),
          if (value case final value?)
            Expanded(
              flex: 2,
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: CarliType.money(CarliType.body).copyWith(color: colors.text2),
              ),
            ),
          ?trailing,
          if (onTap != null && chevron) CarliIcon(carliIconNamed('chevron-right'), size: 16, color: colors.text3),
        ],
      ),
    );
    return Semantics(
      button: onTap != null,
      label: value == null ? null : '$label: $value',
      child: onTap == null ? row : Pressable(onTap: onTap, pressedOpacity: 0.5, child: row),
    );
  }
}

class FormEyebrow extends StatelessWidget {
  const FormEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s4),
    child: Text(text.toUpperCase(), style: CarliType.eyebrow.copyWith(color: context.colors.text2)),
  );
}

class RoundToggle extends StatelessWidget {
  const RoundToggle({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      excludeSemantics: true,
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: CarliMotion.hover,
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? colors.text : null,
            border: Border.all(color: selected ? colors.text : colors.border),
          ),
          child: Text(
            label,
            style: CarliType.small.copyWith(
              fontWeight: FontWeight.w600,
              color: selected ? colors.surface : colors.text,
            ),
          ),
        ),
      ),
    );
  }
}
