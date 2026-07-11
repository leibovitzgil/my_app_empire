import 'package:feature_score/feature_score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';

const List<ParticipantLayer> _layers = [
  ParticipantLayer(
    ownerId: 'owner',
    label: 'Ms. Rivera',
    colorId: 'p0',
    strokes: [],
    visible: true,
    isOwn: true,
  ),
  ParticipantLayer(
    ownerId: 'c1',
    label: 'Bea',
    colorId: 'p1',
    visible: false,
    isOwn: false,
    strokes: [],
  ),
];

/// Pumps [widget], then flushes `AppTextButton`'s `flutter_animate` fade-in
/// delayed-start future (see `score_viewer_screen_golden_test.dart`'s
/// `_theme` note for the same pattern) — a zero-duration pump alone leaves
/// it pending, which trips the test binding's "no pending timers" invariant
/// at teardown once the "Share" button is on screen.
Future<void> _pumpAndFlush(WidgetTester tester, Widget widget) async {
  await tester.pumpWidget(widget);
  await tester.pump(const Duration(milliseconds: 1));
}

Future<void> _pump(
  WidgetTester tester, {
  List<ParticipantLayer> layers = _layers,
  bool audioPinsVisible = true,
  int audioPinCountOnPage = 2,
  bool cleanWorkspace = false,
  ValueChanged<String>? onInkToggle,
  VoidCallback? onAudioToggle,
  VoidCallback? onCleanWorkspaceToggle,
  VoidCallback? onClose,
  VoidCallback? onShare,
  bool annotationsShared = false,
}) {
  return _pumpAndFlush(
    tester,
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 300,
          height: 600,
          child: LayersPanel(
            layers: layers,
            audioPinsVisible: audioPinsVisible,
            audioPinCountOnPage: audioPinCountOnPage,
            cleanWorkspace: cleanWorkspace,
            onInkToggle: onInkToggle ?? (_) {},
            onAudioToggle: onAudioToggle ?? () {},
            onCleanWorkspaceToggle: onCleanWorkspaceToggle ?? () {},
            onClose: onClose,
            onShare: onShare,
            annotationsShared: annotationsShared,
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('LayersPanel', () {
    testWidgets('shows one row per layer with its stroke count', (
      tester,
    ) async {
      await _pump(
        tester,
        layers: const [
          ParticipantLayer(
            ownerId: 'owner',
            label: 'Ms. Rivera',
            colorId: 'p0',
            visible: true,
            isOwn: true,
            strokes: [
              InkStroke(
                id: 's1',
                authorId: 'owner',
                pageIndex: 0,
                colorId: 'p0',
                points: [],
              ),
            ],
          ),
        ],
      );

      expect(find.text('Ms. Rivera'), findsOneWidget);
      // Singular/plural resolved, and "· pen" only on the user's own layer.
      expect(find.text('1 stroke · pen'), findsOneWidget);
    });

    testWidgets("a collaborator's row shows a bare stroke count", (
      tester,
    ) async {
      await _pump(tester);

      // Bea's row has no "· pen" suffix; only the own layer's does.
      expect(find.text('0 strokes'), findsOneWidget);
      expect(find.text('0 strokes · pen'), findsOneWidget);
    });

    testWidgets('tapping a layer row invokes onInkToggle with its ownerId', (
      tester,
    ) async {
      String? toggled;
      await _pump(tester, onInkToggle: (id) => toggled = id);

      await tester.tap(find.text('Bea'));
      expect(toggled, 'c1');
    });

    testWidgets('shows the audio pins row with the on-page count', (
      tester,
    ) async {
      await _pump(tester, audioPinCountOnPage: 3);

      expect(find.text('Audio pins'), findsOneWidget);
      expect(find.text('3 on this page'), findsOneWidget);
    });

    testWidgets('tapping the audio pins row invokes onAudioToggle', (
      tester,
    ) async {
      var toggled = false;
      await _pump(tester, onAudioToggle: () => toggled = true);

      await tester.tap(find.text('Audio pins'));
      expect(toggled, isTrue);
    });

    testWidgets('the clean workspace switch reflects state and toggles', (
      tester,
    ) async {
      var toggled = false;
      await _pump(tester, onCleanWorkspaceToggle: () => toggled = true);

      expect(find.text('Clean workspace'), findsOneWidget);
      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.value, isFalse);

      await tester.tap(find.byType(Switch));
      expect(toggled, isTrue);
    });

    testWidgets('the close button only shows when onClose is set', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.bySemanticsLabel('Close layers panel'), findsNothing);

      await _pump(tester, onClose: () {});
      expect(find.bySemanticsLabel('Close layers panel'), findsOneWidget);
    });

    testWidgets(
      'the share prompt shows only when unshared and onShare is set',
      (tester) async {
        await _pump(tester);
        expect(find.text('Annotations not shared yet'), findsNothing);

        await _pump(tester, onShare: () {});
        expect(find.text('Annotations not shared yet'), findsOneWidget);

        await _pump(tester, onShare: () {}, annotationsShared: true);
        expect(find.text('Annotations not shared yet'), findsNothing);
      },
    );

    testWidgets('tapping Share invokes onShare', (tester) async {
      var shared = false;
      await _pump(tester, onShare: () => shared = true);

      await tester.tap(find.text('Share'));
      expect(shared, isTrue);
    });
  });
}
