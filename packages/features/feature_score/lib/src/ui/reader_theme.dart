import 'package:flutter/material.dart';

/// The reader's forced-dark colour scheme (the app runs `ThemeMode.system`,
/// but the score-reading surfaces are unconditionally dark — a stage, not a
/// document). Computed once — `fromSeed` is a pure function of its inputs,
/// so it never needs re-deriving per rebuild.
final ColorScheme readerDarkScheme = ColorScheme.fromSeed(
  seedColor: Colors.blue,
  brightness: Brightness.dark,
);

/// [context]'s theme with the reader's forced-dark scheme applied. Every
/// screen in the score-reading flow (the reader itself, the practice view)
/// wraps itself in this so pushing between them never flashes back to the
/// host app's light theme.
///
/// `copyWith(colorScheme:)` alone is not enough: [ThemeData] bakes several
/// colours in at construction time from whatever scheme it was *built*
/// with, so those must be re-pointed at the dark scheme explicitly —
/// otherwise the stage shows light letterbox flanks around the page
/// (scaffold background) and light-surfaced sheets behind dark-scheme
/// content on phone widths (bottom-sheet theme).
ThemeData readerTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    brightness: Brightness.dark,
    colorScheme: readerDarkScheme,
    scaffoldBackgroundColor: readerDarkScheme.surface,
    canvasColor: readerDarkScheme.surface,
    cardColor: readerDarkScheme.surfaceContainer,
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: readerDarkScheme.surfaceContainer,
    ),
  );
}
