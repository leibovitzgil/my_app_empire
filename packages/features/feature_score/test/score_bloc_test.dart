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
    const teacherId = 'teacher1';
    const studentId = 'student1';
    const pieceId = 'piece1';

    final piece = Piece(
      id: pieceId,
      title: 'Nocturne',
      basePdfChecksum: 'checksum',
      basePdfPath: '/tmp/piece1.pdf',
      teacherId: teacherId,
      studentId: studentId,
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

    ScoreBloc buildBloc({String currentUserId = teacherId}) => ScoreBloc(
      pieceRepository: pieceRepository,
      annotationRepository: annotationRepository,
      currentUserId: currentUserId,
    );

    test('initial state is loading with the given currentUserId', () {
      final bloc = buildBloc();
      expect(bloc.state.status, ScoreStatus.loading);
      expect(bloc.state.currentUserId, teacherId);
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
            .having((s) => s.currentRole, 'currentRole', PieceRole.teacher),
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
      'derives per-owner stroke lists from the annotations stream',
      build: buildBloc,
      act: (bloc) async {
        bloc.add(const ScoreOpened(pieceId));
        await Future<void>.delayed(Duration.zero);
        annotationsController.add(
          const PieceAnnotations(
            pieceId: pieceId,
            layers: [
              InkLayer(
                ownerId: teacherId,
                role: PieceRole.teacher,
                strokes: [
                  InkStroke(
                    id: 't1',
                    authorId: teacherId,
                    pageIndex: 0,
                    colorId: 'p0',
                    points: [InkPoint(x: 0, y: 0), InkPoint(x: 1, y: 1)],
                  ),
                ],
              ),
              InkLayer(
                ownerId: studentId,
                role: PieceRole.student,
                strokes: [],
              ),
            ],
            audioNotes: [],
          ),
        );
        await Future<void>.delayed(Duration.zero);
      },
      verify: (bloc) {
        expect(bloc.state.teacherStrokes, hasLength(1));
        expect(bloc.state.teacherStrokes.single.id, 't1');
        expect(bloc.state.studentStrokes, isEmpty);
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

    blocTest<ScoreBloc, ScoreState>(
      'clean-workspace toggle restores exact prior per-layer visibility',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const LayerVisibilityToggled(LayerKind.teacherInk))
        ..add(const CleanWorkspaceToggled())
        ..add(const CleanWorkspaceToggled()),
      verify: (bloc) {
        // Set up: teacherInk off, studentInk on (its default).
        // After the sequence above, clean-workspace is back off, and the
        // per-layer flags must be exactly what they were before it was
        // toggled on — not reset to some default.
        expect(bloc.state.cleanWorkspace, isFalse);
        expect(bloc.state.teacherInkVisible, isFalse);
        expect(bloc.state.studentInkVisible, isTrue);
        expect(bloc.state.effectiveTeacherInkVisible, isFalse);
        expect(bloc.state.effectiveStudentInkVisible, isTrue);
      },
    );

    blocTest<ScoreBloc, ScoreState>(
      'clean-workspace hides every layer regardless of its own flag',
      build: buildBloc,
      act: (bloc) => bloc
        ..add(const LayerVisibilityToggled(LayerKind.teacherInk))
        ..add(const CleanWorkspaceToggled()),
      verify: (bloc) {
        expect(bloc.state.effectiveTeacherInkVisible, isFalse);
        expect(bloc.state.effectiveStudentInkVisible, isFalse);
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
          expect(stroke.authorId, teacherId);
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
        "StrokeErased is a no-op for a stroke on the other party's layer",
        build: buildBloc,
        seed: () => const ScoreState.initial(currentUserId: teacherId).copyWith(
          status: ScoreStatus.ready,
          piece: piece,
          currentRole: PieceRole.teacher,
          studentStrokes: const [
            InkStroke(
              id: 'student_stroke',
              authorId: studentId,
              pageIndex: 0,
              colorId: 'p0',
              points: [InkPoint(x: 0, y: 0), InkPoint(x: 1, y: 1)],
            ),
          ],
        ),
        act: (bloc) => bloc.add(const StrokeErased('student_stroke')),
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
        seed: () => const ScoreState.initial(currentUserId: teacherId).copyWith(
          status: ScoreStatus.ready,
          piece: piece,
          notes: [
            AudioNote(
              id: 'note1',
              authorId: studentId,
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
                authorId: teacherId,
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
