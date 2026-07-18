// A widget-level test for `PracticeView`'s region-centering, previously
// documented as infeasible in this sandbox (see `duet_flow_harness.dart` in
// `apps/duet/test/`, and `score_viewer_screen_golden_test.dart`, which only
// covers the loading/failure states for exactly this reason).
//
// That documented blocker is specific to mounting the *full*
// `ScoreViewerScreen` (its `StreamBuilder`s, gesture detectors, and multiple
// concurrent futures around `ScorePageCanvas`) inside a `testWidgets` body —
// verified here empirically not to apply to `PracticeView` in isolation,
// which is a thin, single-`FutureBuilder` wrapper over `ScorePageCanvas`
// with no sibling async work. A fake `PdfRenderService` returning a tiny
// in-memory bitmap (avoiding real `pdfx`/disk I/O, mirroring
// `duet_flow_harness.dart`'s `FakePdfRenderService`), plus one bounded
// `tester.runAsync` call to give `ScorePageCanvas`'s
// `ui.decodeImageFromPixels` decode a real event-loop turn (a `pump()`-only
// loop leaves it permanently pending here, unlike the full-flow case where
// `runAsync` itself was reported flaky), is enough for this decode to
// complete reliably, run after run, with no hang.
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// Mirrors `duet_flow_harness.dart`'s `FakePdfRenderService`: `open` always
/// succeeds, `renderPage` returns a fixed, fully-opaque bitmap — enough for
/// `ScorePageCanvas` to decode successfully without a real `pdfx` platform
/// channel or any disk I/O.
class _FakePdfRenderService implements PdfRenderService {
  static const _dimension = 4;

  @override
  Future<Result<int>> open(String path) async => const Success(1);

  @override
  Future<Result<PdfPageImage>> renderPage(
    int pageIndex, {
    double scale = 1,
  }) async => Success(
    PdfPageImage(
      pageIndex: pageIndex,
      width: _dimension,
      height: _dimension,
      bytes: List<int>.filled(_dimension * _dimension * 4, 255),
    ),
  );

  @override
  Future<Result<PdfPageImage>> renderThumbnail(
    int pageIndex, {
    int maxWidth = 96,
  }) => renderPage(pageIndex);

  @override
  Future<Result<String>> checksum(String path) async =>
      const Success('checksum');
}

const _ownerLayer = ParticipantLayer(
  ownerId: 'owner-1',
  label: 'Owner',
  colorId: 'p0',
  visible: true,
  isOwn: true,
  strokes: [
    InkStroke(
      id: 't1',
      authorId: 'owner-1',
      pageIndex: 0,
      colorId: 'p0',
      points: [InkPoint(x: 0.1, y: 0.1)],
    ),
  ],
);

const _collaboratorLayer = ParticipantLayer(
  ownerId: 'collaborator-1',
  label: 'Bea',
  colorId: 'p1',
  visible: true,
  isOwn: false,
  strokes: [
    InkStroke(
      id: 's1',
      authorId: 'collaborator-1',
      pageIndex: 0,
      colorId: 'p1',
      points: [InkPoint(x: 0.2, y: 0.2)],
    ),
  ],
);

void main() {
  group('PracticeView', () {
    late _FakePdfRenderService renderService;

    setUp(() {
      renderService = _FakePdfRenderService();
    });

    Future<void> pumpPracticeView(
      WidgetTester tester, {
      required Region region,
      List<ParticipantLayer> layers = const [],
      int pageCount = 6,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PracticeView(
            region: region,
            renderService: renderService,
            layers: layers,
            pageCount: pageCount,
            pieceTitle: 'Clair de Lune',
          ),
        ),
      );
      await tester.pump();
      // Lets the `FutureBuilder`'s `renderPage`/`decodeImageFromPixels`
      // chain resolve, then flushes the `addPostFrameCallback` that applies
      // the centering transform.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    Region focusedRegion(WidgetTester tester) => tester
        .widget<ScorePageCanvas>(find.byType(ScorePageCanvas))
        .focusRegion!;

    testWidgets('renders the focused region with both ink overlays', (
      tester,
    ) async {
      await pumpPracticeView(
        tester,
        region: const Region(
          pageIndex: 0,
          left: 0.2,
          top: 0.3,
          width: 0.2,
          height: 0.1,
        ),
        layers: const [_ownerLayer, _collaboratorLayer],
      );

      expect(find.text('Practice'), findsOneWidget);
      expect(find.text('Clair de Lune'), findsOneWidget);
      expect(find.byType(RawImage), findsOneWidget);
      // One overlay per participant ink layer, regardless of how many
      // strokes each carries.
      expect(find.byType(InkOverlay), findsNWidgets(2));
      expect(find.text('Edit here'), findsOneWidget);
      // The location chip and the mini-map caption both say where we are.
      expect(find.text('Page 1 of 6'), findsNWidgets(2));
    });

    testWidgets(
      'centers and zooms the transform on the given region, not the page '
      'origin',
      (tester) async {
        const region = Region(
          pageIndex: 0,
          left: 0.2,
          top: 0.3,
          width: 0.2,
          height: 0.1,
        );
        await pumpPracticeView(tester, region: region);

        final viewer = tester.widget<InteractiveViewer>(
          find.byType(InteractiveViewer),
        );
        final matrix = viewer.transformationController!.value;

        // Mirrors `ScorePageCanvas._focusOnRegionIfNeeded`'s own formula:
        // scale is bounded by the region's width/height (whichever needs
        // more zoom to fill the viewport), capped at 5x. The formula runs
        // against `LayoutBuilder`'s `constraints.biggest` — the *available*
        // space handed to `InteractiveViewer`: the Scaffold body minus the
        // 64dp top bar, inset by the 16dp padding around the canvas (this
        // mirrors the widget's fixed layout, the same way the old version
        // of this test mirrored the `AppBar` height).
        final scaffoldSize = tester.getSize(find.byType(Scaffold));
        final viewportSize = Size(
          scaffoldSize.width - 32,
          scaffoldSize.height - 64 - 32,
        );
        final expectedScale = [
          1 / region.width,
          1 / region.height,
          5.0,
        ].reduce((a, b) => a < b ? a : b);
        final expectedCenterX =
            (region.left + region.width / 2) * viewportSize.width;
        final expectedCenterY =
            (region.top + region.height / 2) * viewportSize.height;
        final expectedDx =
            viewportSize.width / 2 - expectedCenterX * expectedScale;
        final expectedDy =
            viewportSize.height / 2 - expectedCenterY * expectedScale;

        // The transform must not be the identity (i.e. centering actually
        // ran) and must match the expected translate+scale within floating
        // point tolerance.
        expect(matrix, isNot(Matrix4.identity()));
        expect(matrix.getColumn(0)[0], closeTo(expectedScale, 0.001));
        expect(matrix.getColumn(1)[1], closeTo(expectedScale, 0.001));
        expect(matrix.getColumn(3)[0], closeTo(expectedDx, 0.5));
        expect(matrix.getColumn(3)[1], closeTo(expectedDy, 0.5));
      },
    );

    testWidgets('steppers move the focus window one height at a time', (
      tester,
    ) async {
      await pumpPracticeView(
        tester,
        region: const Region(
          pageIndex: 0,
          left: 0.2,
          top: 0.3,
          width: 0.6,
          height: 0.2,
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(focusedRegion(tester).top, closeTo(0.5, 0.0001));

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(focusedRegion(tester).top, closeTo(0.1, 0.0001));

      // Finish the glide animations so no ticker is left running.
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('stepping past the page edge rolls onto the next page', (
      tester,
    ) async {
      await pumpPracticeView(
        tester,
        region: const Region(
          pageIndex: 0,
          left: 0,
          top: 0.5,
          width: 1,
          height: 0.5,
        ),
        pageCount: 2,
      );

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      var region = focusedRegion(tester);
      expect(region.pageIndex, 1);
      expect(region.top, 0);
      expect(find.text('Page 2 of 2'), findsNWidgets(2));

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      region = focusedRegion(tester);
      expect(region.pageIndex, 1);
      expect(region.top, closeTo(0.5, 0.0001));

      // Last window of the last page: forward is now disabled.
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      region = focusedRegion(tester);
      expect(region.pageIndex, 1);
      expect(region.top, closeTo(0.5, 0.0001));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('the back stepper is disabled at the very start', (
      tester,
    ) async {
      await pumpPracticeView(
        tester,
        region: const Region(
          pageIndex: 0,
          left: 0,
          top: 0,
          width: 1,
          height: 0.2,
        ),
      );

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      expect(focusedRegion(tester).top, 0);
      expect(focusedRegion(tester).pageIndex, 0);
    });

    testWidgets('layer dots toggle a participant ink overlay', (
      tester,
    ) async {
      await pumpPracticeView(
        tester,
        region: const Region(
          pageIndex: 0,
          left: 0.2,
          top: 0.3,
          width: 0.2,
          height: 0.1,
        ),
        layers: const [_ownerLayer, _collaboratorLayer],
      );
      expect(find.byType(InkOverlay), findsNWidgets(2));

      await tester.tap(find.byTooltip('Bea'));
      await tester.pump();
      expect(find.byType(InkOverlay), findsOneWidget);

      await tester.tap(find.byTooltip('Bea'));
      await tester.pump();
      expect(find.byType(InkOverlay), findsNWidgets(2));
    });

    testWidgets('a layer hidden in the reader starts hidden here', (
      tester,
    ) async {
      await pumpPracticeView(
        tester,
        region: const Region(
          pageIndex: 0,
          left: 0.2,
          top: 0.3,
          width: 0.2,
          height: 0.1,
        ),
        layers: [
          _ownerLayer,
          _collaboratorLayer.copyWith(visible: false),
        ],
      );

      expect(find.byType(InkOverlay), findsOneWidget);
    });

    testWidgets('tapping the mini-map recenters the focus window there', (
      tester,
    ) async {
      await pumpPracticeView(
        tester,
        region: const Region(
          pageIndex: 0,
          left: 0.2,
          top: 0.3,
          width: 0.2,
          height: 0.1,
        ),
      );

      final map = find.descendant(
        of: find.bySemanticsLabel(RegExp('Page map')),
        matching: find.byType(GestureDetector),
      );
      await tester.tapAt(tester.getCenter(map));
      await tester.pump();

      final region = focusedRegion(tester);
      expect(region.left, closeTo(0.4, 0.05));
      expect(region.top, closeTo(0.45, 0.05));
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets('"Edit here" pops back to the caller', (tester) async {
      const region = Region(
        pageIndex: 0,
        left: 0.2,
        top: 0.3,
        width: 0.2,
        height: 0.1,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Navigator(
            onGenerateRoute: (settings) => MaterialPageRoute<void>(
              builder: (context) => Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => PracticeView(
                          region: region,
                          renderService: renderService,
                          layers: const [],
                          pageCount: 6,
                        ),
                      ),
                    ),
                    child: const Text('Open practice'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open practice'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(PracticeView), findsOneWidget);

      await tester.tap(find.text('Edit here'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(PracticeView), findsNothing);
      expect(find.text('Open practice'), findsOneWidget);
    });
  });
}
