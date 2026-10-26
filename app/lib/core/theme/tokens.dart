import 'package:flutter/material.dart';

/// Tokens del design system "Ember" (docs/DESIGN-SYSTEM.md §2).
@immutable
class CarliColors extends ThemeExtension<CarliColors> {
  const CarliColors({
    required this.bg,
    required this.surface,
    required this.surface2,
    required this.sidebar,
    required this.border,
    required this.text,
    required this.text2,
    required this.text3,
    required this.primary,
    required this.primaryHover,
    required this.primarySoft,
    required this.onPrimary,
    required this.primaryStrong,
    required this.brandInk,
    required this.positive,
    required this.warning,
    required this.negative,
    required this.positiveSoft,
    required this.warningSoft,
    required this.negativeSoft,
    required this.focusRing,
    required this.chart,
  });

  final Color bg, surface, surface2, sidebar, border;
  final Color text, text2, text3;
  final Color primary, primaryHover, primarySoft, onPrimary, primaryStrong, brandInk;
  final Color positive, warning, negative;
  final Color positiveSoft, warningSoft, negativeSoft;
  final Color focusRing;

  /// Paleta categórica en orden fijo; solo gráficos y leyendas.
  final List<Color> chart;

  /// Relleno de acciones destructivas en ambos temas; `negative` queda para cifras y texto.
  static const dangerFill = Color(0xFFC8281C);

  static const light = CarliColors(
    bg: Color(0xFFF5F5F7),
    surface: Color(0xFFFFFFFF),
    surface2: Color(0xFFF0F0F2),
    sidebar: Color(0xFFFFFFFF),
    border: Color(0xFFEBEBEB),
    text: Color(0xFF1F1F1F),
    text2: Color(0xFF666666),
    text3: Color(0xFF6E6E6E),
    primary: Color(0xFFE5063F),
    primaryHover: Color(0xFFD90033),
    primarySoft: Color(0xFFFFEBF0),
    onPrimary: Color(0xFFFFFFFF),
    primaryStrong: Color(0xFFE5063F),
    brandInk: Color(0xFFD90033),
    positive: Color(0xFF0F7B4A),
    warning: Color(0xFFB45309),
    negative: Color(0xFFC8281C),
    positiveSoft: Color(0xFFECFDF0),
    warningSoft: Color(0xFFFFFBEB),
    negativeSoft: Color(0xFFFEF3F2),
    focusRing: Color(0x40E5063F),
    chart: [
      Color(0xFF2A78D6),
      Color(0xFFEB6834),
      Color(0xFF1BAF7A),
      Color(0xFFEDA100),
      Color(0xFFE87BA4),
      Color(0xFF008300),
      Color(0xFF6250D6),
      Color(0xFFE34948),
    ],
  );

  static const dark = CarliColors(
    bg: Color(0xFF000000),
    surface: Color(0xFF161616),
    surface2: Color(0xFF1F1F1F),
    sidebar: Color(0xFF0A0A0A),
    border: Color(0xFF262626),
    text: Color(0xFFFFFFFF),
    text2: Color(0xFFA3A3A3),
    text3: Color(0xFF8A8A8A),
    primary: Color(0xFFE5063F),
    primaryHover: Color(0xFFFA114F),
    primarySoft: Color(0xFF3A0A18),
    onPrimary: Color(0xFFFFFFFF),
    primaryStrong: Color(0xFFFA114F),
    brandInk: Color(0xFFFF5C85),
    positive: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    negative: Color(0xFFED5A46),
    positiveSoft: Color(0xFF0F2E22),
    warningSoft: Color(0xFF3A2A0A),
    negativeSoft: Color(0xFF3D1A16),
    focusRing: Color(0x66FF5C85),
    chart: [
      Color(0xFF3987E5),
      Color(0xFFD95926),
      Color(0xFF199E70),
      Color(0xFFC98500),
      Color(0xFFD55181),
      Color(0xFF008300),
      Color(0xFF9085E9),
      Color(0xFFE66767),
    ],
  );

  @override
  CarliColors copyWith() => this;

  @override
  CarliColors lerp(ThemeExtension<CarliColors>? other, double t) {
    if (other is! CarliColors) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return CarliColors(
      bg: l(bg, other.bg),
      surface: l(surface, other.surface),
      surface2: l(surface2, other.surface2),
      sidebar: l(sidebar, other.sidebar),
      border: l(border, other.border),
      text: l(text, other.text),
      text2: l(text2, other.text2),
      text3: l(text3, other.text3),
      primary: l(primary, other.primary),
      primaryHover: l(primaryHover, other.primaryHover),
      primarySoft: l(primarySoft, other.primarySoft),
      onPrimary: l(onPrimary, other.onPrimary),
      primaryStrong: l(primaryStrong, other.primaryStrong),
      brandInk: l(brandInk, other.brandInk),
      positive: l(positive, other.positive),
      warning: l(warning, other.warning),
      negative: l(negative, other.negative),
      positiveSoft: l(positiveSoft, other.positiveSoft),
      warningSoft: l(warningSoft, other.warningSoft),
      negativeSoft: l(negativeSoft, other.negativeSoft),
      focusRing: l(focusRing, other.focusRing),
      chart: [for (var i = 0; i < chart.length; i++) l(chart[i], other.chart[i])],
    );
  }
}

/// Radios (§2.5).
abstract final class CarliRadius {
  static const sm = 6.0;
  static const md = 12.0;
  static const control = 12.0;
  static const controlLg = 16.0;
  static const chip = 8.0;
  static const lg = 22.0;
  static const sheet = 28.0;
  static const xl = 32.0;
  static const full = 999.0;
}

/// Escala de espaciado en px (§2.5).
abstract final class CarliSpace {
  static const s2 = 2.0, s4 = 4.0, s8 = 8.0, s12 = 12.0, s16 = 16.0, s20 = 20.0;
  static const s24 = 24.0, s32 = 32.0, s40 = 40.0, s48 = 48.0, s64 = 64.0;
}

/// Duraciones (§2.5).
abstract final class CarliMotion {
  static const hover = Duration(milliseconds: 120);
  static const enter = Duration(milliseconds: 200);
  static const fade = Duration(milliseconds: 240);
}

extension CarliThemeX on BuildContext {
  CarliColors get colors => Theme.of(this).extension<CarliColors>()!;
}
