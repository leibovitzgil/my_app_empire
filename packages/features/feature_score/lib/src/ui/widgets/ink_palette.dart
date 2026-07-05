import 'package:feature_score/src/ink_color_id.dart';
import 'package:flutter/material.dart';

/// The fixed, colour-blind-safe ink palette (Okabe-Ito) strokes are drawn in.
///
/// Indexed 0-4 and referenced by an `InkStroke`'s `colorId` as `'p$index'`
/// (see [inkColorIdFor]/[inkColorForId]) so a stroke's colour survives
/// round-tripping through the repository without carrying a raw `Color`
/// across the domain/data boundary.
const List<Color> kInkPalette = [
  Color(0xFF0072B2), // Blue
  Color(0xFFD55E00), // Vermillion
  Color(0xFF009E73), // Bluish green
  Color(0xFFCC79A7), // Reddish purple
  Color(0xFFE69F00), // Orange
];

/// Resolves a stroke's [colorId] back to a [Color], defaulting to the first
/// palette entry for unrecognised ids rather than throwing — annotations are
/// long-lived data and a palette tweak shouldn't break rendering old strokes.
Color inkColorForId(String colorId) {
  final index = int.tryParse(colorId.replaceFirst('p', ''));
  if (index == null || index < 0 || index >= kInkPalette.length) {
    return kInkPalette.first;
  }
  return kInkPalette[index];
}
