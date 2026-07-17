@Tags(['golden'])
library;

import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:core_ui/core_ui.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes. The reader is unconditionally
// dark (see `score_viewer_screen.dart`), so every feature_score golden uses
// the dark test theme.
final ThemeData _theme = AppTheme.testTheme(brightness: Brightness.dark);

const List<PageInkPresence> _presence = [
  (hasAudio: false, inkColors: [Color(0xFF0072B2)], hasNew: false),
  (
    hasAudio: true,
    inkColors: [Color(0xFF0072B2), Color(0xFFD55E00)],
    hasNew: true,
  ),
  (hasAudio: false, inkColors: <Color>[], hasNew: false),
];

/// A deterministic fake page render (M8.1): paper-white pixels with dark
/// horizontal "system" bands whose phase depends on the page index, decoded
/// from raw RGBA bytes — no fonts, no platform channels, byte-identical on
/// every host.
Future<ui.Image> _fakePageImage(int pageIndex) {
  const width = 56;
  const height = 72;
  final bytes = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    final band = ((y + pageIndex * 4) % 12) < 2;
    for (var x = 0; x < width; x++) {
      final i = (y * width + x) * 4;
      bytes[i] = band ? 40 : 244;
      bytes[i + 1] = band ? 44 : 242;
      bytes[i + 2] = band ? 60 : 236;
      bytes[i + 3] = 255;
    }
  }
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

Future<void> _pump(WidgetTester tester, {bool dimmed = false}) async {
  // Decode up-front under real async — `decodeImageFromPixels` completes on
  // real async, which the fake-async test clock never drives. The rail takes
  // ownership of (and disposes) each image it's handed.
  final pages = (await tester.runAsync(
    () async => [for (var i = 0; i < 3; i++) await _fakePageImage(i)],
  ))!;
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: PageThumbnailRail(
            pageCount: 3,
            currentPage: 1,
            presence: _presence,
            onSelectPage: (_) {},
            thumbnailFor: (page) async => pages[page],
            dimmed: dimmed,
          ),
        ),
      ),
    ),
  );
  // Let every thumbnail load resolve and land via setState.
  await tester.pumpAndSettle();
}

void main() {
  group('PageThumbnailRail goldens', () {
    testWidgets('current page 2, real thumbnails, ink and audio presence '
        'dots', (tester) async {
      await _pump(tester);
      await expectLater(
        find.byType(PageThumbnailRail),
        matchesGoldenFile('goldens/page_thumbnail_rail.png'),
      );
    });

    testWidgets('dimmed (draw mode)', (tester) async {
      await _pump(tester, dimmed: true);
      await expectLater(
        find.byType(PageThumbnailRail),
        matchesGoldenFile('goldens/page_thumbnail_rail_dimmed.png'),
      );
    });
  });
}
