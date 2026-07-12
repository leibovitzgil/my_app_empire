import 'package:core_ui/core_ui.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  ScoreMode mode = ScoreMode.view,
  int currentPage = 0,
  int pageCount = 1,
  ScoreSyncStatus syncStatus = ScoreSyncStatus.notSynced,
  bool cleanWorkspace = false,
  List<AvatarStackPerson> collaborators = const [],
  List<String> collaboratorNames = const [],
  Duration? recordingElapsed,
  bool compact = false,
  VoidCallback onBack = _noop,
  VoidCallback? onPreviousPage,
  VoidCallback? onNextPage,
  VoidCallback? onOpenLayers,
  Future<void> Function()? onShare,
  Future<void> Function()? onImport,
  VoidCallback? onPracticePage,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ReaderTopBar(
          title: 'Clair de Lune',
          mode: mode,
          currentPage: currentPage,
          pageCount: pageCount,
          syncStatus: syncStatus,
          cleanWorkspace: cleanWorkspace,
          collaborators: collaborators,
          collaboratorNames: collaboratorNames,
          recordingElapsed: recordingElapsed,
          compact: compact,
          onBack: onBack,
          onPreviousPage: onPreviousPage,
          onNextPage: onNextPage,
          onOpenLayers: onOpenLayers,
          onShare: onShare,
          onImport: onImport,
          onPracticePage: onPracticePage,
        ),
      ),
    ),
  );
}

final _threePeople = <AvatarStackPerson>[
  (initials: 'MK', color: const Color(0xFF8B5CF6)),
  (initials: 'TR', color: const Color(0xFFF59E0B)),
  (initials: 'NB', color: const Color(0xFF14B8A6)),
];

void _noop() {}

void main() {
  group('ReaderTopBar', () {
    testWidgets('shows the title and a solo subtitle with no collaborators', (
      tester,
    ) async {
      await _pump(tester);

      expect(find.text('Clair de Lune'), findsOneWidget);
      expect(find.text('Sheet music'), findsOneWidget);
    });

    testWidgets('view subtitle lists collaborators when present', (
      tester,
    ) async {
      await _pump(
        tester,
        collaboratorNames: const ['Maya K.', 'Tomer R.'],
      );

      expect(
        find.text('Sheet music · Duet with Maya K. & Tomer R.'),
        findsOneWidget,
      );
    });

    testWidgets('draw/passage subtitle shows the page count instead', (
      tester,
    ) async {
      await _pump(
        tester,
        mode: ScoreMode.draw,
        currentPage: 1,
        pageCount: 6,
        collaboratorNames: const ['Maya K.'],
      );

      expect(find.text('Sheet music · Page 2 of 6'), findsOneWidget);
    });

    testWidgets('tapping back invokes onBack', (tester) async {
      var backTapped = false;
      await _pump(tester, onBack: () => backTapped = true);

      await tester.tap(find.bySemanticsLabel('Back'));
      expect(backTapped, isTrue);
    });

    testWidgets('the page-nav pill only shows in view mode', (tester) async {
      await _pump(tester);
      expect(find.text('Page 1 of 1'), findsOneWidget);

      await _pump(tester, mode: ScoreMode.draw);
      expect(find.text('Page 1 of 1'), findsNothing);
    });

    testWidgets('collaborator avatars only show in view mode', (
      tester,
    ) async {
      const collaborators = [(initials: 'MK', color: Colors.purple)];

      await _pump(tester, collaborators: collaborators);
      expect(find.byType(AvatarStack), findsOneWidget);

      await _pump(tester, mode: ScoreMode.draw, collaborators: collaborators);
      expect(find.byType(AvatarStack), findsNothing);
    });

    testWidgets('draw mode always shows "Drawing in your layer", even when '
        'clean workspace is also on', (tester) async {
      await _pump(
        tester,
        mode: ScoreMode.draw,
        cleanWorkspace: true,
      );

      expect(find.text('Drawing in your layer'), findsOneWidget);
      expect(find.text('Clean workspace'), findsNothing);
    });

    testWidgets('a live recording outranks every other status badge', (
      tester,
    ) async {
      await _pump(
        tester,
        mode: ScoreMode.regionSelect,
        cleanWorkspace: true,
        recordingElapsed: const Duration(seconds: 67),
      );

      expect(find.text('REC 1:07'), findsOneWidget);
      expect(find.text('Clean workspace'), findsNothing);
      expect(find.text('Not synced'), findsNothing);
    });

    testWidgets('clean workspace wins over the sync badge outside draw mode', (
      tester,
    ) async {
      await _pump(
        tester,
        cleanWorkspace: true,
        syncStatus: ScoreSyncStatus.synced,
      );

      expect(find.text('Clean workspace'), findsOneWidget);
      expect(find.text('Synced'), findsNothing);
    });

    testWidgets('falls back to the sync badge otherwise', (tester) async {
      await _pump(tester, syncStatus: ScoreSyncStatus.syncing);

      expect(find.text('Syncing…'), findsOneWidget);
    });

    testWidgets('the Layers button only shows when onOpenLayers is set', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.bySemanticsLabel('Layers'), findsNothing);

      await _pump(tester, onOpenLayers: () {});
      expect(find.bySemanticsLabel('Layers'), findsOneWidget);
    });

    testWidgets('overflow menu only shows wired-up actions', (tester) async {
      await _pump(tester);
      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Practice this page'), findsNothing);
      expect(find.text('Share my annotations'), findsNothing);
      expect(find.text('Import review bundle'), findsNothing);
    });

    testWidgets('overflow menu actions invoke their callbacks', (
      tester,
    ) async {
      var practiceCalled = false;
      var shareCalled = false;
      await _pump(
        tester,
        onPracticePage: () => practiceCalled = true,
        onShare: () async => shareCalled = true,
      );

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      expect(find.text('Practice this page'), findsOneWidget);
      expect(find.text('Share my annotations'), findsOneWidget);
      expect(find.text('Import review bundle'), findsNothing);

      await tester.tap(find.text('Practice this page'));
      await tester.pumpAndSettle();
      expect(practiceCalled, isTrue);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Share my annotations'));
      await tester.pumpAndSettle();
      expect(shareCalled, isTrue);
    });

    testWidgets('previous/next page chevrons are disabled when null', (
      tester,
    ) async {
      await _pump(tester);

      final previous = tester.widget<IconButton>(
        find.descendant(
          of: find.bySemanticsLabel('Previous page'),
          matching: find.byType(IconButton),
        ),
      );
      expect(previous.onPressed, isNull);
    });

    testWidgets('tapping the chevrons invokes the page callbacks', (
      tester,
    ) async {
      var previousTapped = false;
      var nextTapped = false;
      await _pump(
        tester,
        currentPage: 1,
        pageCount: 3,
        onPreviousPage: () => previousTapped = true,
        onNextPage: () => nextTapped = true,
      );

      await tester.tap(find.bySemanticsLabel('Previous page'));
      expect(previousTapped, isTrue);
      await tester.tap(find.bySemanticsLabel('Next page'));
      expect(nextTapped, isTrue);
    });

    testWidgets(
      'compact view mode does not overflow a phone width and drops the page '
      'pill and avatars',
      (tester) async {
        tester.view.physicalSize = const Size(360, 200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pump(
          tester,
          compact: true,
          currentPage: 1,
          pageCount: 6,
          collaborators: _threePeople,
          collaboratorNames: const ['Maya K.', 'Tomer R.', 'Noa B.'],
          onOpenLayers: () {},
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(AvatarStack), findsNothing);
        expect(find.text('Page 2 of 6'), findsNothing);
      },
    );

    testWidgets(
      'compact draw mode does not overflow a phone width despite the wide '
      'status badge',
      (tester) async {
        tester.view.physicalSize = const Size(360, 200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await _pump(
          tester,
          mode: ScoreMode.draw,
          compact: true,
          currentPage: 1,
          pageCount: 6,
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Drawing in your layer'), findsOneWidget);
      },
    );
  });
}
