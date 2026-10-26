import 'package:flutter/material.dart';

/// SF Pro through Flutter's iOS system font aliases: Text below 20 pt, Display from 20 pt,
/// as UIKit does. Geist is kept only for the "carli" wordmark.
abstract final class CarliType {
  static const family = 'CupertinoSystemText';
  static const displayFamily = 'CupertinoSystemDisplay';
  static const brandFamily = 'Geist';
  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _s(double size, double height, FontWeight w, {double tracking = 0}) => TextStyle(
    fontFamily: size >= 20 ? displayFamily : family,
    fontSize: size,
    height: height / size,
    fontWeight: w,
    letterSpacing: tracking,
  );

  static final display = _s(34, 41, FontWeight.w700, tracking: 0.4).copyWith(fontFeatures: _tabular);
  static final h1 = _s(34, 41, FontWeight.w700, tracking: 0.4);
  static final title2 = _s(22, 28, FontWeight.w700, tracking: -0.26);
  static final metric = _s(28, 34, FontWeight.w600, tracking: 0.38).copyWith(fontFeatures: _tabular);
  static final h2 = _s(17, 22, FontWeight.w600, tracking: -0.43);
  static final body = _s(15, 20, FontWeight.w400, tracking: -0.23);
  static final bodyStrong = _s(15, 20, FontWeight.w600, tracking: -0.23);
  static final small = _s(13, 18, FontWeight.w400, tracking: -0.08);
  static final caption = _s(12, 16, FontWeight.w500);
  static final eyebrow = _s(13, 18, FontWeight.w600, tracking: -0.08);

  static TextStyle wordmark(double size) => TextStyle(
    fontFamily: brandFamily,
    fontSize: size,
    height: 1.2,
    fontWeight: FontWeight.w600,
    fontVariations: const [FontVariation.weight(650)],
    letterSpacing: -0.03 * size,
  );

  static TextStyle money(TextStyle base) => base.copyWith(fontFeatures: _tabular);
}
