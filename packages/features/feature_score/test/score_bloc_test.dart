import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_score/feature_score.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pieces/pieces.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

class MockAnnotationRepository extends Mock implements AnnotationRepository {}

void main() {
  group('ScoreBloc', () {
    const ownerId = 'owner1';
    const collaboratorId = 'collaborator1';
    const pieceId = 'piece1';

    final piece = Piece(
      id: pieceId,
      title: 'Nocturne',
      basePdfChecksum: 'checksum',
      basePdfPath: '/tmp/piece1.pdf',
      ownerId: ownerId,
      collaborators: const [Collaborator(uid: collaboratorId)],
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );

    late MockPieceRepository pieceRepository;
    late MockAnnotationRepository annotationRepository;
    late StreamController<PieceAnnotations> annotationsController;

    setUpAll(() {
      registerFallbackValue(
        const InkStroke(
          id: 'fallback',
          authorId: 'fallback',
          pageIndex: 0,
          colorId: 'p0',
          points: [],
        ),
      );
      registerFallbackValue(
        AudioNote(
          id: 'fallback',
          authorId: 'fallback',
          audioAssetId: 'fallback',
          pageIndex: 0,
          durationMs: 0,
          region: const Region(
            pageIndex: 0,
            left: 0,
            top: 0,
            width: 1,
            height: 1,
          ),
          createdAt: DateTime(2024),
        ),
      );
    });

    setUp(() {
      pieceRepository = MockPieceRepository();
      annotationRepository = MockAnnotationRepository();
      annotationsController = StreamController<PieceAnnotations>.broadcast();
      when(
        () => pieceRepository.getPiece(pieceId),
      ).thenAnswer((_) async => Success(piece));
      when(
        () => annotationRepository.watch(pieceId),
      ).thenAnswer((_) => annotationsController.stream);
      when(
        () => annotationRepository.addStroke(any(), any()),
      ).thenAnswer((_) async => const Success<void>(null));
      when(
        () => annotationRepository.eraseStroke(any(), any()),
      ).thenAnswer((_) async => const Success<void>(null));
      when(
        () => annotationRepository.addAudioNote(any(), any()),
      ).thenAnswer((_) async => const Success<void>(null));
      when(
        () => annotationRepository.deleteAudioNote(any(), any()),
      ).thenAnswer((_) async => const Success<void>(null));
    });

    tearDown(() async {
      await annotationsController.close();
    });

    ScoreBloc buildBloc({String currentUserId = ownerId}) => ScoreBloc(
      pieceRepository: pieceRepository,
      annotationRepository: annotationRepository,
      currentUserId: currentUserId,
    );

    test('initial state is loading with the given currentUserId', () {
      final bloc = buildBloc();
      expect(bloc.state.status, ScoreStatus.loading);
      expect(bloc.state.currentUserId, ownerId);
      addTearDown(bloc.close);
    });

    blocTest<ScoreBloc, ScoreState>(
      'ScoreOpened loads the piece and resolves the current role',
      build: buildBloc,
      act: (bloc) => bloc.add(const ScoreOpened(pieceId)),
      expect: () => [
        isA<ScoreState>()
            .having((s) => s.status, 'status', ScoreStatus.loading)
            .having((s) => s.pieceId, 'pieceId', pieceId),
        isA<ScoreState>()
            .having((s) => s.status, 'status', ScoreStatus.ready)
            .having((s) => s.piece, 'piece', piece)
            .having((s) => s.currentRole, 'currentRole', PieceRole.owner),
      ],
    );

    blocTest<ScoreBloc, ScoreState>(
      'ScoreOpened surfaces a failure when the piece cannot be loaded',
      setUp: () {
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => ResultFailure<Piece>(StateError('nope')));
      },
      build: buildBloc,
      act: (bloc) => bloc.add(const ScoreOpened(pieceId)),
      expect: () => [
        isA<ScoreState>().having(
          (s) => s.status,
          'status',
          ScoreStatus.loading,
        ),
        isA<ScoreState>().having(
          (s) => s.status,
          'status',
          ScoreStatus.failure,
        ),
      ],
    );

    blocTest<ScoreBloc, ScoreState>(
      'projects one layer per participant from the annotations stream, in '
      'participant order, each with a distinct auto-assigned colour',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const ScoreOpened(pieceId));
        await Future<void>.delayed(Duration.zero);
        annotationsController.add(
          const PieceAnnotations(
            pieceId: pieceId,
            layers: [
              InkLayer(
                ownerId: ownerId,
                role: PieceRole.owner,
                strokes: [
                  InkStroke(
                    id: 't1',
                    authorId: ownerId,
                    pageIndex: 0,
                    colorId: 'p0',
                    points: [InkPoint(x: 0, y: 0), InkPoint(x: 1, y: 1)],
                  ),
                ],
              ),
              InkLayer(
                ownerId: collaboratorId,
                role: PieceRole.collaborator,
                strokes: [],
              ),
            ],
            audioNotes: [],
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        final layers = bloc.state.layers;
        expect(layers, hasLength(2));
        // Owner first, then the collaborator, in participant order.
        expect(layers[0].ownerId, ownerId);
        expect(layers[0].strokes, hasLength(1));
        expect(layers[0].strokes.single.id, 't1');
        expect(layers[0].colorId, 'p0');
        expect(layers[0].isOwn, isTrue);
        expect(layers[1].ownerId, collaboratorId);
        expect(layers[1].strokes, isEmpty);
        expect(layers[1].colorId, 'p1');
        expect(layers[1].isOwn, isFalse);
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'projects a layer for every collaborator, not just the first',
      build: buildBloc,
      setUp: () {
        final multiPiece = Piece(
          id: pieceId,
          title: 'Trio',
          basePdfChecksum: 'checksum',
          basePdfPath: '/tmp/piece1.pdf',
          ownerId: ownerId,
          collaborators: const [
            Collaborator(uid: 'collaborator1', name: 'Bea'),
            Collaborator(uid: 'collaborator2', name: 'Cy'),
          ],
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );
        when(
          () => pieceRepository.getPiece(pieceId),
        ).thenAnswer((_) async => Success(multiPiece));
      },
      act: (bloc) async {
        bloc.add(const ScoreOpened(pieceId));
        await Future<void>.delayed(Duration.zero);
        annotationsController.add(
          const PieceAnnotations(
            pieceId: pieceId,
            layers: [
              InkLayer(
                ownerId: 'collaborator2',
                role: PieceRole.collaborator,
                strokes: [
                  InkStroke(
                    id: 'c2',
                    authorId: 'collaborator2',
                    pageIndex: 0,
                    colorId: 'p2',
                    points: [InkPoint(x: 0, y: 0), InkPoint(x: 1, y: 1)],
                  ),
                ],
              ),
            ],
            audioNotes: [],
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        final layers = bloc.state.layers;
        expect(layers.map((l) => l.ownerId), [
          ownerId,
          'collaborator1',
          'collaborator2',
        ]);
        expect(layers.map((l) => l.label), ['Owner', 'Bea', 'Cy']);
        expect(layers.map((l) => l.colorId), ['p0', 'p1', 'p2']);
        // The third participant's strokes are projected, not dropped.
        expect(layers[2].strokes.single.id, 'c2');
      },
    );

    group('mode transitions', () {
      blocTest<ScoreBloc, ScoreState>(
        'draw and regionSelect are mutually exclusive; view exits either',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const ModeChanged(ScoreMode.draw))
          ..add(const ModeChanged(ScoreMode.regionSelect))
          ..add(const ModeChanged(ScoreMode.view)),
        expect: () => [
          isA<ScoreState>().having((s) => s.mode, 'mode', ScoreMode.draw),
          isA<ScoreState>().having(
            (s) => s.mode,
            'mode',
            ScoreMode.regionSelect,
          ),
          isA<ScoreState>().having((s) => s.mode, 'mode', ScoreMode.view),
        ],
      );

      blocTest<ScoreBloc, ScoreState>(
        'leaving regionSelect clears the active region and intent',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const RegionSelectStarted(RegionIntent.practice))
          ..add(
            const RegionSelectCompleted(
              Region(
                pageIndex: 0,
                left: 0.1,
                top: 0.1,
                width: 0.2,
                height: 0.2,
              ),
            ),
          )
          ..add(const ModeChanged(ScoreMode.view)),
        skip: 2,
        expect: () => [
          isA<ScoreState>()
              .having((s) => s.mode, 'mode', ScoreMode.view)
              .having((s) => s.activeRegion, 'activeRegion', isNull)
              .having((s) => s.regionIntent, 'regionIntent', isNull),
        ],
      );
    });

    ParticipantLayer layerFor(ScoreBloc bloc, String participantId) =>
        bloc.state.layers.firstWhere((l) => l.ownerId == participantId);

    blocTest<ScoreBloc, ScoreState>(
      'clean-workspace toggle restores exact prior per-layer visibility',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const ScoreOpened(pieceId));
        await Future<void>.delayed(Duration.zero);
        annotationsController.add(PieceAnnotations.empty(pieceId));
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const InkLayerToggled(ownerId)) // owner ink off
          ..add(const CleanWorkspaceToggled())
          ..add(const CleanWorkspaceToggled());
      },
      verify: (bloc) {
        // Set up: owner ink off, collaborator ink on (its default).
        // After the sequence above, clean-workspace is back off, and each
        // layer's visibility must be exactly what it was before it was
        // toggled on — not reset to some default.
        expect(bloc.state.cleanWorkspace, isFalse);
        expect(bloc.state.hiddenInkOwnerIds, {ownerId});
        expect(layerFor(bloc, ownerId).visible, isFalse);
        expect(layerFor(bloc, collaboratorId).visible, isTrue);
        expect(
          bloc.state.effectiveInkVisible(layerFor(bloc, ownerId)),
          isFalse,
        );
        expect(
          bloc.state.effectiveInkVisible(layerFor(bloc, collaboratorId)),
          isTrue,
        );
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'clean-workspace hides every layer regardless of its own flag',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const ScoreOpened(pieceId));
        await Future<void>.delayed(Duration.zero);
        annotationsController.add(PieceAnnotations.empty(pieceId));
        await Future<void>.delayed(Duration.zero);
        bloc
          ..add(const InkLayerToggled(ownerId))
          ..add(const CleanWorkspaceToggled());
      },
      verify: (bloc) {
        for (final layer in bloc.state.layers) {
          expect(bloc.state.effectiveInkVisible(layer), isFalse);
        }
        expect(bloc.state.effectiveAudioPinsVisible, isFalse);
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'toggling one ink layer leaves the other layers untouched',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const ScoreOpened(pieceId));
        await Future<void>.delayed(Duration.zero);
        annotationsController.add(PieceAnnotations.empty(pieceId));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const InkLayerToggled(ownerId));
      },
      verify: (bloc) {
        expect(layerFor(bloc, ownerId).visible, isFalse);
        expect(layerFor(bloc, collaboratorId).visible, isTrue);
        expect(bloc.state.audioPinsVisible, isTrue);
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'the audio-pins toggle is immediate: a single event, a single emission',
      build: buildBloc,
      act: (bloc) => bloc.add(const AudioPinsToggled()),
      expect: () => [
        isA<ScoreState>().having(
          (s) => s.audioPinsVisible,
          'audioPinsVisible',
          isFalse,
        ),
      ],
    );

    blocTest<ScoreBloc, ScoreState>(
      'a layer toggled while clean-workspace is active updates its '
      'underlying flag (masked, not lost), and turning clean-workspace off '
      'reveals that change rather than whatever was visible before masking',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const CleanWorkspaceToggled()) // mask: all start visible
        ..add(const AudioPinsToggled()) // toggled while masked
        ..add(const CleanWorkspaceToggled()), // unmask
      verify: (bloc) {
        expect(bloc.state.cleanWorkspace, isFalse);
        expect(bloc.state.audioPinsVisible, isFalse);
        expect(bloc.state.effectiveAudioPinsVisible, isFalse);
      },
    );

    group('drawing', () {
      // Different event types are processed concurrently by bloc (each
      // `on<E>` has its own subscription), so tests combining ScoreOpened
      // with a follow-up event that depends on the piece being loaded must
      // await a beat between dispatches rather than chaining `add` calls
      // synchronously.
      blocTest<ScoreBloc, ScoreState>(
        'StrokeCompleted builds a stroke authored by the current user and '
        'sends it to the repository',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const ScoreOpened(pieceId));
          await Future<void>.delayed(Duration.zero);
          bloc
            ..add(const ModeChanged(ScoreMode.draw))
            ..add(
              const StrokeCompleted([
                InkPoint(x: 0.1, y: 0.1),
                InkPoint(x: 0.2, y: 0.2),
              ]),
            );
        },
        verify: (_) {
          final captured = verify(
            () => annotationRepository.addStroke(pieceId, captureAny()),
          ).captured;
          expect(captured, hasLength(1));
          final stroke = captured.single as InkStroke;
          expect(stroke.authorId, ownerId);
        },
      );

      blocTest<ScoreBloc, ScoreState>(
        'StrokeCompleted is ignored outside draw mode',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const ScoreOpened(pieceId));
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            const StrokeCompleted([
              InkPoint(x: 0.1, y: 0.1),
              InkPoint(x: 0.2, y: 0.2),
            ]),
          );
        },
        verify: (_) {
          verifyNever(() => annotationRepository.addStroke(any(), any()));
        },
      );

      blocTest<ScoreBloc, ScoreState>(
        "StrokeErased is a no-op for a stroke on another participant's layer",
        build: buildBloc,
        seed: () => const ScoreState.initial(currentUserId: ownerId).copyWith(
          status: ScoreStatus.ready,
          piece: piece,
          currentRole: PieceRole.owner,
          layers: const [
            ParticipantLayer(
              ownerId: ownerId,
              label: 'Owner',
              colorId: 'p0',
              strokes: [],
              visible: true,
              isOwn: true,
            ),
            ParticipantLayer(
              ownerId: collaboratorId,
              label: 'Bea',
              colorId: 'p1',
              visible: true,
              isOwn: false,
              strokes: [
                InkStroke(
                  id: 'collaborator_stroke',
                  authorId: collaboratorId,
                  pageIndex: 0,
                  colorId: 'p1',
                  points: [InkPoint(x: 0, y: 0), InkPoint(x: 1, y: 1)],
                ),
              ],
            ),
          ],
        ),
        act: (bloc) => bloc.add(const StrokeErased('collaborator_stroke')),
        verify: (_) {
          verifyNever(() => annotationRepository.eraseStroke(any(), any()));
        },
      );

      blocTest<ScoreBloc, ScoreState>(
        'UndoRequested pops and erases only the most recent own stroke',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const ScoreOpened(pieceId));
          await Future<void>.delayed(Duration.zero);
          bloc
            ..add(const ModeChanged(ScoreMode.draw))
            ..add(
              const StrokeCompleted([
                InkPoint(x: 0, y: 0),
                InkPoint(x: 1, y: 1),
              ]),
            );
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            const StrokeCompleted([
              InkPoint(x: 0, y: 0.5),
              InkPoint(x: 1, y: 0.5),
            ]),
          );
          await Future<void>.delayed(Duration.zero);
          bloc.add(const UndoRequested());
        },
        verify: (bloc) {
          expect(bloc.state.undoStack, hasLength(1));
          final erased = verify(
            () => annotationRepository.eraseStroke(pieceId, captureAny()),
          ).captured;
          expect(erased, hasLength(1));
        },
      );
    });

    group('pageCount', () {
      blocTest<ScoreBloc, ScoreState>(
        'PageCountResolved sets pageCount, flooring non-positive counts at 1',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const PageCountResolved(6))
          ..add(const PageCountResolved(0)),
        expect: () => [
          isA<ScoreState>().having((s) => s.pageCount, 'pageCount', 6),
          isA<ScoreState>().having((s) => s.pageCount, 'pageCount', 1),
        ],
      );

      blocTest<ScoreBloc, ScoreState>(
        'PageChanged clamps into [0, pageCount - 1]',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const PageCountResolved(3))
          ..add(const PageChanged(10))
          ..add(const PageChanged(-2)),
        skip: 1,
        expect: () => [
          isA<ScoreState>().having((s) => s.currentPage, 'currentPage', 2),
          isA<ScoreState>().having((s) => s.currentPage, 'currentPage', 0),
        ],
      );

      blocTest<ScoreBloc, ScoreState>(
        'a smaller pageCount re-clamps an out-of-range currentPage',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const PageCountResolved(6))
          ..add(const PageChanged(5))
          ..add(const PageCountResolved(2)),
        skip: 2,
        expect: () => [
          isA<ScoreState>()
              .having((s) => s.pageCount, 'pageCount', 2)
              .having((s) => s.currentPage, 'currentPage', 1),
        ],
      );

      test('isFirstPage/isLastPage reflect currentPage against pageCount', () {
        const state = ScoreState.initial(currentUserId: ownerId);
        final middle = state.copyWith(pageCount: 3, currentPage: 1);
        expect(middle.isFirstPage, isFalse);
        expect(middle.isLastPage, isFalse);
        expect(middle.copyWith(currentPage: 0).isFirstPage, isTrue);
        expect(middle.copyWith(currentPage: 2).isLastPage, isTrue);
        // The default pageCount (1) makes page 0 both first and last.
        expect(state.isFirstPage, isTrue);
        expect(state.isLastPage, isTrue);
      });
    });

    group('region select', () {
      blocTest<ScoreBloc, ScoreState>(
        'routes to the recordAudio intent',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const RegionSelectStarted(RegionIntent.recordAudio))
          ..add(
            const RegionSelectCompleted(
              Region(pageIndex: 0, left: 0, top: 0, width: 0.5, height: 0.5),
            ),
          ),
        verify: (bloc) {
          expect(bloc.state.regionIntent, RegionIntent.recordAudio);
          expect(bloc.state.activeRegion, isNotNull);
        },
      );

      blocTest<ScoreBloc, ScoreState>(
        'routes to the practice intent',
        build: buildBloc,
        act: (bloc) => bloc
          ..add(const RegionSelectStarted(RegionIntent.practice))
          ..add(
            const RegionSelectCompleted(
              Region(pageIndex: 0, left: 0, top: 0, width: 0.5, height: 0.5),
            ),
          ),
        verify: (bloc) {
          expect(bloc.state.regionIntent, RegionIntent.practice);
        },
      );
    });

    group('audio notes', () {
      blocTest<ScoreBloc, ScoreState>(
        'AudioNoteDeleteRequested is a no-op for a note owned by someone else',
        build: buildBloc,
        seed: () => const ScoreState.initial(currentUserId: ownerId).copyWith(
          status: ScoreStatus.ready,
          piece: piece,
          notes: [
            AudioNote(
              id: 'note1',
              authorId: collaboratorId,
              audioAssetId: '/tmp/a.m4a',
              pageIndex: 0,
              durationMs: 1000,
              region: const Region(
                pageIndex: 0,
                left: 0,
                top: 0,
                width: 0.2,
                height: 0.2,
              ),
              createdAt: DateTime(2024),
            ),
          ],
        ),
        act: (bloc) => bloc.add(const AudioNoteDeleteRequested('note1')),
        verify: (_) {
          verifyNever(
            () => annotationRepository.deleteAudioNote(any(), any()),
          );
        },
      );

      blocTest<ScoreBloc, ScoreState>(
        'AudioNoteSaved invokes addAudioNote',
        build: buildBloc,
        act: (bloc) async {
          bloc.add(const ScoreOpened(pieceId));
          await Future<void>.delayed(Duration.zero);
          bloc.add(
            AudioNoteSaved(
              AudioNote(
                id: 'note1',
                authorId: ownerId,
                audioAssetId: '/tmp/a.m4a',
                pageIndex: 0,
                durationMs: 1000,
                region: const Region(
                  pageIndex: 0,
                  left: 0,
                  top: 0,
                  width: 0.2,
                  height: 0.2,
                ),
                createdAt: DateTime(2024),
              ),
              '/tmp/a.m4a',
            ),
          );
        },
        verify: (_) {
          verify(
            () => annotationRepository.addAudioNote(pieceId, any()),
          ).called(1);
        },
      );
    });
  });
}
