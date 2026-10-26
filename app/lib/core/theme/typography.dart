import 'package:flutter/material.dart';

/// Escala tipográfica (§2.4). Geist para todo, cifras tabulares.
abstract final class CarliType {
  static const family = 'Geist';
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _s(double size, double height, FontWeight w, {double tracking = 0}) => TextStyle(
    fontFamily: family,
    fontSize: size,
    height: height / size,
    fontWeight: w,
    fontVariations: [FontVariation.weight(w.value.toDouble())],
    letterSpacing: tracking * size,
  );

  static final display = _s(36, 42, FontWeight.w600, tracking: -0.02).copyWith(fontFeatures: _tabular);
  static final h1 = _s(28, 34, FontWeight.w800, tracking: -0.025);
  static final h2 = _s(16, 24, FontWeight.w600);
  static final body = _s(15, 22, FontWeight.w400);
  static final bodyStrong = _s(15, 22, FontWeight.w600);
  static final small = _s(13, 18, FontWeight.w400);
  static final caption = _s(12, 16, FontWeight.w500);
  static final eyebrow = _s(12, 16, FontWeight.w600, tracking: 0.08);

  /// Para importes en listas y KPI.
  static TextStyle money(TextStyle base) => base.copyWith(fontFeatures: _tabular);
}
