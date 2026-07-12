@Tags(['golden'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:core_ui/core_ui.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

class _MockLibraryBloc extends MockBloc<LibraryEvent, LibraryState>
    implements LibraryBloc {}

class _MockPieceRepository extends Mock implements PieceRepository {}

class _MockPdfRenderService extends Mock implements PdfRenderService {}

// A fixed "now" so the greeting bucket and every relative-time label render
// deterministically ("Good evening" + "2 hr ago" / "1 d ago" / ...).
final _now = DateTime(2024, 6, 15, 20, 30);

/// An owned sheet. [fresh] true → `updatedAt` after `createdAt`, so it reads
/// as unread.
Piece _mine({
  required String id,
  required String title,
  required Duration ago,
  List<Collaborator> collaborators = const [],
  bool fresh = false,
}) {
  final updatedAt = _now.subtract(ago);
  return Piece(
    id: id,
    title: title,
    basePdfChecksum: 'sum-$id',
    basePdfPath: '/tmp/$id.pdf',
    ownerId: 'me',
    collaborators: collaborators,
    createdAt: fresh ? DateTime(2024) : updatedAt,
    updatedAt: updatedAt,
  );
}

/// A sheet shared with the viewer by [ownerName].
Piece _shared({
  required String id,
  required String title,
  required String ownerId,
  required String ownerName,
  required Duration ago,
  bool fresh = false,
}) {
  final updatedAt = _now.subtract(ago);
  return Piece(
    id: id,
    title: title,
    basePdfChecksum: 'sum-$id',
    basePdfPath: '/tmp/$id.pdf',
    ownerId: ownerId,
    ownerName: ownerName,
    collaborators: const [Collaborator(uid: 'me')],
    createdAt: fresh ? DateTime(2024) : updatedAt,
    updatedAt: updatedAt,
  );
}

final _seededPieces = <Piece>[
  _mine(
    id: 'p1',
    title: 'Sonata in D Major, K. 448',
    ago: const Duration(hours: 2),
    collaborators: const [Collaborator(uid: 'maya')],
    fresh: true,
  ),
  _mine(
    id: 'p2',
    title: 'Clair de Lune (Four Hands)',
    ago: const Duration(days: 1),
    collaborators: const [
      Collaborator(uid: 'maya'),
      Collaborator(uid: 'tomer'),
    ],
  ),
  _mine(id: 'p3', title: 'Libertango', ago: const Duration(hours: 5)),
  _shared(
    id: 'p4',
    title: 'Dolly Suite, Op. 56',
    ownerId: 'maya',
    ownerName: 'Maya K.',
    ago: const Duration(hours: 1),
    fresh: true,
  ),
  _shared(
    id: 'p5',
    title: 'Slavonic Dance, Op. 46 No. 8',
    ownerId: 'tomer',
    ownerName: 'Tomer R.',
    ago: const Duration(days: 2),
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required Brightness brightness,
  required List<Piece> pieces,
  Size surface = const Size(1300, 980),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final bloc = _MockLibraryBloc();
  final state = const LibraryState.initial(
    currentUserId: 'me',
  ).copyWith(status: LibraryStatus.ready, pieces: pieces);
  whenListen(bloc, const Stream<LibraryState>.empty(), initialState: state);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.testTheme(brightness: brightness),
      home: BlocProvider<LibraryBloc>.value(
        value: bloc,
        child: LibraryHomeScreen(
          pieceRepository: _MockPieceRepository(),
          renderService: _MockPdfRenderService(),
          binaryStore: const NoopPieceBinaryStore(),
          currentUserId: 'me',
          appName: 'Duet',
          currentUserName: 'Gil',
          onOpenScore: (_) {},
          onOpenSettings: () {},
          now: _now,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('LibraryHomeScreen goldens', () {
    testWidgets('ready gallery — dark', (tester) async {
      await _pump(
        tester,
        brightness: Brightness.dark,
        pieces: _seededPieces,
      );
      await expectLater(
        find.byType(LibraryHomeScreen),
        matchesGoldenFile('goldens/library_gallery_dark.png'),
      );
    });

    testWidgets('ready gallery — light', (tester) async {
      await _pump(
        tester,
        brightness: Brightness.light,
        pieces: _seededPieces,
      );
      await expectLater(
        find.byType(LibraryHomeScreen),
        matchesGoldenFile('goldens/library_gallery_light.png'),
      );
    });

    testWidgets('empty library — dark', (tester) async {
      await _pump(
        tester,
        brightness: Brightness.dark,
        pieces: const [],
        surface: const Size(900, 900),
      );
      await expectLater(
        find.byType(LibraryHomeScreen),
        matchesGoldenFile('goldens/library_empty_dark.png'),
      );
    });
  });
}
