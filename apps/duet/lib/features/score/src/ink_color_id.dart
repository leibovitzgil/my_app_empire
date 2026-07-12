/// The number of distinct swatches in the ink palette (`kInkPalette`, in
/// `ui/widgets/ink_palette.dart`).
///
/// Lives here, outside `ui/`, so `ScoreBloc` can assign each participant a
/// distinct, palette-cycling ink colour (see [inkColorIdFor]) without
/// importing presentation code. `kInkPalette` is asserted to be exactly this
/// long by `ink_palette_test.dart`.
const int kInkPaletteSize = 5;

/// The `InkStroke.colorId` for the palette swatch at [index], cycling within
/// the palette (`'p0'`, `'p1'`, ..., wrapping after [kInkPaletteSize]).
///
/// Lives outside `ui/` because `ScoreBloc` needs it to build a stroke's
/// `colorId` — and to assign each participant their layer colour — without
/// depending on presentation code; `ui/widgets/ink_palette` reuses it to map a
/// stroke's `colorId` back to a swatch colour. Cycling keeps every colour id
/// in range even when a piece has more participants than the palette has
/// swatches (colours then repeat, which is inherent to a fixed palette).
String inkColorIdFor(int index) => 'p${index % kInkPaletteSize}';
