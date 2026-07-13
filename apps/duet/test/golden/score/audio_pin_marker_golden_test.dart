@Tags(['golden'])
library;

import 'package:duet/domain/domain.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A network-free theme (AppTheme pulls google_fonts, which fetches at
// runtime and fails in tests).
final _theme = ThemeData(useMaterial3: true);

const _region = Region(
  pageIndex: 0,
  left: 0.1,
  top: 0.1,
  width: 0.1,
  height: 0.1,
);

AudioNote _note(String authorId) => AudioNote(
  id: 'note1',
  authorId: authorId,
  audioAssetId: '/tmp/a.m4a',
  pageIndex: 0,
  durationMs: 4000,
  region: _region,
  createdAt: DateTime(2024),
);

Future<void> _pump(
  WidgetTester tester, {
  required String currentUserId,
  bool isPlaying = false,
  bool isNew = false,
  double? progress,
}) {
  return tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: Scaffold(
        body: Center(
          child: AudioPinMarker(
            note: _note('owner1'),
            currentUserId: currentUserId,
            isPlaying: isPlaying,
            isNew: isNew,
            progress: progress,
            onTap: () {},
            onDelete: () {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('AudioPinMarker goldens', () {
    testWidgets('idle, owned by current user', (tester) async {
      await _pump(tester, currentUserId: 'owner1');
      await expectLater(
        find.byType(AudioPinMarker),
        matchesGoldenFile('goldens/audio_pin_marker_idle_own.png'),
      );
    });

    testWidgets('idle, owned by the other participant', (tester) async {
      await _pump(tester, currentUserId: 'collaborator1');
      await expectLater(
        find.byType(AudioPinMarker),
        matchesGoldenFile('goldens/audio_pin_marker_idle_other.png'),
      );
    });

    testWidgets('new, owned by the other participant', (tester) async {
      await _pump(tester, currentUserId: 'collaborator1', isNew: true);
      await expectLater(
        find.byType(AudioPinMarker),
        matchesGoldenFile('goldens/audio_pin_marker_new.png'),
      );
    });

    testWidgets('playing, with progress', (tester) async {
      await _pump(
        tester,
        currentUserId: 'owner1',
        isPlaying: true,
        progress: 0.4,
      );
      await expectLater(
        find.byType(AudioPinMarker),
        matchesGoldenFile('goldens/audio_pin_marker_playing.png'),
      );
    });
  });
}
