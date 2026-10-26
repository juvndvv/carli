import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/tokens.dart';
import '../core/theme/typography.dart';

class CarliField extends StatelessWidget {
  const CarliField({super.key, required this.label, required this.child, this.hint, this.error});

  final String label;
  final Widget child;
  final String? hint;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: CarliSpace.s8,
      children: [
        Text(label, style: CarliType.caption.copyWith(color: colors.text2)),
        child,
        if (error case final error?)
          Semantics(
            liveRegion: true,
            child: Text(error, style: CarliType.small.copyWith(color: colors.negative)),
          )
        else if (hint case final hint?)
          Text(hint, style: CarliType.small.copyWith(color: colors.text3)),
      ],
    );
  }
}

class CarliInput extends StatelessWidget {
  const CarliInput({
    super.key,
    required this.controller,
    this.placeholder,
    this.keyboardType,
    this.autofillHints,
    this.obscureText = false,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.invalid = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.inputFormatters,
    this.prefix,
    this.suffix,
  });

  final TextEditingController controller;
  final String? placeholder;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool invalid;
  final bool autofocus;
  final int? maxLines;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? prefix;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(CarliRadius.md),
      borderSide: BorderSide(color: colors.negative),
    );
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      obscureText: obscureText,
      autocorrect: false,
      enableSuggestions: !obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      autofocus: autofocus,
      maxLines: obscureText ? 1 : maxLines,
      minLines: maxLines == null ? 3 : null,
      inputFormatters: inputFormatters,
      style: CarliType.body.copyWith(color: colors.text),
      decoration: InputDecoration(
        hintText: placeholder,
        prefixIcon: prefix,
        suffixIcon: suffix,
        enabledBorder: invalid ? errorBorder : null,
        focusedBorder: invalid ? errorBorder : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: CarliSpace.s16, vertical: 14),
      ),
    );
  }
}
