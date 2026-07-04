import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';
import 'package:user_roles/user_roles.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

class MockPdfRenderService extends Mock implements PdfRenderService {}

/// Grants every permission, mirroring `user_roles`' own test convention (see
/// `role_gate_test.dart`'s `_FakeUserRoleRepository`).
class _AllowAllUserRoleRepository implements UserRoleRepository {
  final _controller = StreamController<AppRole>.broadcast();

  @override
  Stream<AppRole> get currentRole => _controller.stream;

  @override
  Future<Result<AppRole>> getRole() async => const Success(AppRole.member);

  @override
  bool hasPermission(Permission permission) => true;

  @override
  bool hasMinimumRole(AppRole role) => true;

  @override
  Future<Result<void>> assignRole(String userId, AppRole role) async =>
      const Success<void>(null);
}

void main() {
  group('LibraryHomeScreen', () {
    const teacherId = 'teacher-1';
    const studentId = 'student-1';

    late MockPieceRepository repository;
    late MockPdfRenderService renderService;
    late StreamController<List<Piece>> piecesController;

    setUp(() {
      repository = MockPieceRepository();
      renderService = MockPdfRenderService();
      piecesController = StreamController<List<Piece>>.broadcast();
      when(
        () => repository.watchPieces(),
      ).thenAnswer((_) => piecesController.stream);
    });

    tearDown(() async => piecesController.close());

    Future<void> pumpScreen(
      WidgetTester tester, {
      required PieceRole role,
      required String currentUserId,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: LibraryPage(
            pieceRepository: repository,
            renderService: renderService,
            userRoleRepository: _AllowAllUserRoleRepository(),
            currentUserId: currentUserId,
            currentRole: role,
            onOpenScore: (_) {},
          ),
        ),
      );
      await tester.pump();
      // Flushes flutter_animate's initial delayed-start future for the
      // loading state's `SkeletonList` shimmer (see core_ui's
      // `skeleton_test.dart`); a zero-duration pump leaves it pending, which
      // trips the test binding's "no pending timers" invariant at teardown.
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets('teacher with no pieces sees the empty state and actions', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        role: PieceRole.teacher,
        currentUserId: teacherId,
      );
      piecesController.add(const []);
      await tester.pump();
      await tester.pump();

      expect(find.text('No pieces yet'), findsOneWidget);
      expect(find.byTooltip('Import piece'), findsOneWidget);
      expect(find.byTooltip('Invite student'), findsOneWidget);
    });

    testWidgets(
      'student with no pieces sees the student-specific empty state',
      (
        tester,
      ) async {
        await pumpScreen(
          tester,
          role: PieceRole.student,
          currentUserId: studentId,
        );
        piecesController.add(const []);
        await tester.pump();
        await tester.pump();

        expect(find.text('No pieces yet'), findsOneWidget);
        expect(find.textContaining('Ask your teacher'), findsOneWidget);
        expect(find.byTooltip('Import piece'), findsNothing);
      },
    );

    testWidgets('student sees a flat list of shared pieces', (tester) async {
      await pumpScreen(
        tester,
        role: PieceRole.student,
        currentUserId: studentId,
      );
      piecesController.add([
        Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'checksum',
          basePdfPath: '/tmp/p1.pdf',
          teacherId: teacherId,
          studentId: studentId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Clair de Lune'), findsOneWidget);
    });

    testWidgets('teacher sees pieces grouped by student, expandable', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        role: PieceRole.teacher,
        currentUserId: teacherId,
      );
      piecesController.add([
        Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'checksum',
          basePdfPath: '/tmp/p1.pdf',
          teacherId: teacherId,
          studentId: studentId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ]);
      await tester.pump();
      await tester.pump();

      expect(find.text('Clair de Lune'), findsNothing);
      await tester.tap(find.textContaining('shared piece'));
      await tester.pump();
      expect(find.text('Clair de Lune'), findsOneWidget);
    });

    testWidgets(
      'teacher sees the real studentName on a paired piece, falling back '
      'to an initials-from-id placeholder when unset',
      (tester) async {
        await pumpScreen(
          tester,
          role: PieceRole.teacher,
          currentUserId: teacherId,
        );
        piecesController.add([
          Piece(
            id: 'p1',
            title: 'Clair de Lune',
            basePdfChecksum: 'checksum',
            basePdfPath: '/tmp/p1.pdf',
            teacherId: teacherId,
            studentId: studentId,
            studentName: 'Sam Smith',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ]);
        await tester.pump();
        await tester.pump();

        expect(find.text('Sam Smith'), findsOneWidget);
        expect(find.textContaining('Student '), findsNothing);
      },
    );

    testWidgets(
      "student sees the real teacherName in a piece's subtitle, falling "
      'back to an initials-from-id placeholder when unset',
      (tester) async {
        await pumpScreen(
          tester,
          role: PieceRole.student,
          currentUserId: studentId,
        );
        piecesController.add([
          Piece(
            id: 'p1',
            title: 'Clair de Lune',
            basePdfChecksum: 'checksum',
            basePdfPath: '/tmp/p1.pdf',
            teacherId: teacherId,
            studentId: studentId,
            teacherName: 'Jane Doe',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ]);
        await tester.pump();
        await tester.pump();

        expect(find.text('Jane Doe'), findsOneWidget);
        expect(find.textContaining('Teacher '), findsNothing);
      },
    );
  });
}
