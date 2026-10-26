import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'tokens.dart';
import 'typography.dart';

ThemeData carliTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? CarliColors.dark : CarliColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.primary,
    onPrimary: c.onPrimary,
    secondary: c.text,
    onSecondary: c.surface,
    error: c.negative,
    onError: c.onPrimary,
    surface: c.surface,
    onSurface: c.text,
    surfaceContainerHighest: c.surface2,
    outline: c.border,
    outlineVariant: c.border,
  );
  final controlShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(CarliRadius.control));

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: CarliType.family,
    scaffoldBackgroundColor: c.bg,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    cupertinoOverrideTheme: CupertinoThemeData(
      brightness: brightness,
      primaryColor: c.brandInk,
      scaffoldBackgroundColor: c.bg,
      barBackgroundColor: c.bg,
      textTheme: CupertinoTextThemeData(
        primaryColor: c.brandInk,
        textStyle: CarliType.body.copyWith(color: c.text),
        navTitleTextStyle: CarliType.h2.copyWith(color: c.text),
        navLargeTitleTextStyle: CarliType.h1.copyWith(color: c.text),
      ),
    ),
    dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
    textTheme: TextTheme(
      displayLarge: CarliType.display,
      headlineMedium: CarliType.h1,
      titleMedium: CarliType.h2,
      bodyMedium: CarliType.body,
      bodySmall: CarliType.small,
      labelSmall: CarliType.caption,
    ).apply(bodyColor: c.text, displayColor: c.text),
    cardTheme: CardThemeData(
      color: c.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CarliRadius.lg),
        side: BorderSide(color: c.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: c.primary,
        foregroundColor: c.onPrimary,
        minimumSize: const Size(44, 44),
        shape: controlShape,
        textStyle: CarliType.bodyStrong,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: c.brandInk, textStyle: CarliType.bodyStrong),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: c.text,
        side: BorderSide(color: c.border),
        minimumSize: const Size(44, 44),
        shape: controlShape,
        textStyle: CarliType.bodyStrong,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.surface,
      hintStyle: CarliType.body.copyWith(color: c.text3),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CarliRadius.md),
        borderSide: BorderSide(color: c.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CarliRadius.md),
        borderSide: BorderSide(color: c.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CarliRadius.md),
        borderSide: BorderSide(color: c.text),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surface,
      dragHandleColor: c.border,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(CarliRadius.sheet))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.text,
      contentTextStyle: CarliType.body.copyWith(color: c.surface),
      actionTextColor: c.surface,
      behavior: SnackBarBehavior.floating,
      shape: const StadiumBorder(),
    ),
  );
}
