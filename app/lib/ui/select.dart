import 'package:flutter/material.dart';
import 'package:hugeicons/styles/stroke_rounded.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';
import 'icon.dart';
import 'pressable.dart';
import 'sheet.dart';

class CarliOption<T> {
  const CarliOption(this.value, this.label, {this.icon, this.subtitle});

  final T value;
  final String label;
  final CarliIconData? icon;
  final String? subtitle;
}

class CarliSelect<T> extends StatelessWidget {
  const CarliSelect({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Elige una opción',
    this.title,
    this.invalid = false,
  });

  final List<CarliOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final String placeholder;
  final String? title;
  final bool invalid;

  Future<void> _open(BuildContext context) async {
    final picked = await pickCarliOption<T>(context, options: options, value: value, title: title);
    if (picked != null) onChanged(picked.$1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final selected = options.where((option) => option.value == value).firstOrNull;
    return Semantics(
      button: true,
      label: title,
      value: selected?.label,
      child: Pressable(
        onTap: () => _open(context),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(CarliRadius.md),
            border: Border.all(color: invalid ? colors.negative : colors.border),
          ),
          child: Row(
            spacing: CarliSpace.s8,
            children: [
              if (selected?.icon case final icon?) CarliIcon(icon, size: 18, color: colors.text2),
              Expanded(
                child: Text(
                  selected?.label ?? placeholder,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: CarliType.body.copyWith(color: selected == null ? colors.text3 : colors.text),
                ),
              ),
              CarliIcon(HugeIconsStrokeRounded.arrowDown01, size: 18, color: colors.text3),
            ],
          ),
        ),
      ),
    );
  }
}

Future<(T,)?> pickCarliOption<T>(
  BuildContext context, {
  required List<CarliOption<T>> options,
  T? value,
  String? title,
}) => showCarliSheet<(T,)>(
  context,
  title: title,
  scrollable: true,
  builder: (context) => _OptionList(options: options, value: value),
);

class _OptionList<T> extends StatelessWidget {
  const _OptionList({required this.options, required this.value});

  final List<CarliOption<T>> options;
  final T? value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.only(bottom: CarliSpace.s16),
      itemCount: options.length,
      separatorBuilder: (_, _) => Divider(indent: CarliSpace.s20, color: colors.border),
      itemBuilder: (context, index) {
        final option = options[index];
        final selected = option.value == value;
        return Semantics(
          selected: selected,
          button: true,
          child: Pressable(
            onTap: () => Navigator.pop(context, (option.value,)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: CarliSpace.s20, vertical: 14),
              child: Row(
                spacing: CarliSpace.s12,
                children: [
                  if (option.icon case final icon?) CarliIcon(icon, size: 20, color: colors.text2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(option.label, style: CarliType.body.copyWith(color: colors.text)),
                        if (option.subtitle case final subtitle?)
                          Text(subtitle, style: CarliType.small.copyWith(color: colors.text2)),
                      ],
                    ),
                  ),
                  if (selected)
                    CarliIcon(HugeIconsStrokeRounded.tick02, size: 20, color: colors.brandInk, strokeWidth: 2),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
