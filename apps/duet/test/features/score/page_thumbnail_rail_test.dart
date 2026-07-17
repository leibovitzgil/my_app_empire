import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  int pageCount = 3,
  int currentPage = 0,
  List<PageInkPresence> presence = const [],
  ValueChanged<int>? onSelectPage,
  Future<ui.Image?> Function(int pageIndex)? thumbnailFor,
  bool dimmed = false,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: PageThumbnailRail(
            pageCount: pageCount,
            currentPage: currentPage,
            presence: presence,
            onSelectPage: onSelectPage ?? (_) {},
            thumbnailFor: thumbnailFor,
            dimmed: dimmed,
          ),
        ),
      ),
    ),
  );
}

/// Decodes a tiny opaque image — a stand-in for a real page thumbnail.
///
/// Must run inside [WidgetTester.runAsync]: `decodeImageFromPixels`
/// completes on real async, which the fake-async test clock never drives.
Future<ui.Image> _testImage() {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List.fromList(List<int>.filled(4 * 4 * 4, 255)),
    4,
    4,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

void main() {
  group('PageThumbnailRail', () {
    testWidgets('shows one thumbnail label per page', (tester) async {
      await _pump(tester, pageCount: 4);

      for (final label in ['1', '2', '3', '4']) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('tapping a page invokes onSelectPage with its index', (
      tester,
    ) async {
      int? selected;
      await _pump(tester, onSelectPage: (i) => selected = i);

      await tester.tap(find.bySemanticsLabel('Page 3'));
      expect(selected, 2);
    });

    testWidgets('marks the current page as selected in semantics', (
      tester,
    ) async {
      await _pump(tester, currentPage: 1);

      expect(find.bySemanticsLabel('Page 2, current page'), findsOneWidget);
      expect(find.bySemanticsLabel('Page 1'), findsOneWidget);
    });

    testWidgets('dimmed disables page taps entirely', (tester) async {
      int? selected;
      await _pump(
        tester,
        dimmed: true,
        onSelectPage: (i) => selected = i,
      );

      // Page 1 is also the (default) current page, so its actual label is
      // "Page 1, current page" — match by prefix rather than assume the
      // bare "Page 1" string.
      await tester.tap(find.bySemanticsLabel(RegExp('^Page 1')));
      expect(selected, isNull);
    });

    testWidgets('every thumbnail meets the 48x48 minimum tap target', (
      tester,
    ) async {
      await _pump(tester, pageCount: 2);

      final boxes = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.minWidth == 48 &&
            widget.constraints.minHeight == 48,
      );
      expect(boxes, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final size = tester.getSize(boxes.at(i));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('renders an ink-presence dot per colour on that page', (
      tester,
    ) async {
      await _pump(
        tester,
        pageCount: 1,
        presence: const [
          (
            hasAudio: false,
            inkColors: [Colors.blue, Colors.red],
            hasNew: false,
          ),
        ],
      );

      final dots = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      );
      expect(dots, findsNWidgets(2));
    });

    testWidgets('shows a mic glyph when the page has an audio note', (
      tester,
    ) async {
      await _pump(
        tester,
        pageCount: 1,
        presence: const [(hasAudio: true, inkColors: <Color>[], hasNew: false)],
      );

      expect(find.byIcon(Icons.mic), findsOneWidget);
    });

    testWidgets('renders the real thumbnail for each page once it resolves', (
      tester,
    ) async {
      final image = (await tester.runAsync(_testImage))!;
      addTearDown(image.dispose);
      final requested = <int>[];
      await _pump(
        tester,
        thumbnailFor: (page) async {
          requested.add(page);
          return image.clone();
        },
      );
      await tester.pumpAndSettle();

      expect(requested, unorderedEquals([0, 1, 2]));
      expect(find.byType(RawImage), findsNWidgets(3));
    });

    testWidgets('keeps the stylized placeholder when a thumbnail is '
        'unavailable', (tester) async {
      await _pump(tester, thumbnailFor: (_) async => null);
      await tester.pumpAndSettle();

      expect(find.byType(RawImage), findsNothing);
    });

    testWidgets('tap targets stay >= 48x48 with real thumbnails', (
      tester,
    ) async {
      final image = (await tester.runAsync(_testImage))!;
      addTearDown(image.dispose);
      await _pump(
        tester,
        pageCount: 2,
        thumbnailFor: (_) async => image.clone(),
      );
      await tester.pumpAndSettle();

      final boxes = find.byWidgetPredicate(
        (widget) =>
            widget is ConstrainedBox &&
            widget.constraints.minWidth == 48 &&
            widget.constraints.minHeight == 48,
      );
      expect(boxes, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final size = tester.getSize(boxes.at(i));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });

    testWidgets('shows a "new" accent + semantics when the page has new ink', (
      tester,
    ) async {
      await _pump(
        tester,
        pageCount: 1,
        presence: const [(hasAudio: false, inkColors: <Color>[], hasNew: true)],
      );

      // No ink dots on this page, so the only circle is the new-accent hint.
      final circles = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            (widget.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      );
      expect(circles, findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('new annotations')),
        findsOneWidget,
      );
    });
  });
}
