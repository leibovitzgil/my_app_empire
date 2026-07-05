/// The `InkStroke.colorId` for the pen palette's `index`th swatch (`'p0'`,
/// `'p1'`, ...).
///
/// Lives outside `ui/` because `ScoreBloc` needs it to build a stroke's
/// `colorId` without depending on presentation code; `ui/widgets/ink_palette`
/// reuses it to map a stroke's `colorId` back to a swatch colour.
String inkColorIdFor(int index) => 'p$index';
