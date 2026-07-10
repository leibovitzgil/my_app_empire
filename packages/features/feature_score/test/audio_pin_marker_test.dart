import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';

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

void main() {
  group('AudioPinMarker', () {
    testWidgets('tapping the marker calls onTap regardless of ownership', (
      tester,
    ) async {
      var tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudioPinMarker(
              note: _note('owner1'),
              currentUserId: 'collaborator1',
              isPlaying: false,
              onTap: () => tapped = true,
              onDelete: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.byType(AudioPinMarker));
      expect(tapped, isTrue);
    });

    testWidgets(
      'long-pressing a note owned by the current user surfaces a delete '
      'affordance, and confirming it calls onDelete',
      (tester) async {
        var deleted = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AudioPinMarker(
                note: _note('owner1'),
                currentUserId: 'owner1',
                isPlaying: false,
                onTap: () {},
                onDelete: () => deleted = true,
              ),
            ),
          ),
        );

        await tester.longPress(find.byType(AudioPinMarker));
        await tester.pumpAndSettle();

        expect(find.text('Delete'), findsOneWidget);
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();

        expect(deleted, isTrue);
      },
    );

    testWidgets(
      'long-pressing a note owned by someone else surfaces no delete '
      'affordance at all — not merely a disabled one',
      (tester) async {
        var deleted = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AudioPinMarker(
                note: _note('owner1'),
                currentUserId: 'collaborator1',
                isPlaying: false,
                onTap: () {},
                onDelete: () => deleted = true,
              ),
            ),
          ),
        );

        await tester.longPress(find.byType(AudioPinMarker));
        await tester.pumpAndSettle();

        // No bottom sheet, no delete option — the long-press gesture isn't
        // even wired up for a note the current user doesn't own.
        expect(find.text('Delete'), findsNothing);
        expect(deleted, isFalse);
      },
    );
  });
}
