import 'package:core_utils/core_utils.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pieces/pieces.dart';

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('PieceDetailScreen', () {
    const teacherId = 'teacher-1';
    const studentId = 'student-1';

    late MockPieceRepository repository;

    setUp(() {
      repository = MockPieceRepository();
    });

    Future<void> pumpScreen(
      WidgetTester tester, {
      required Piece piece,
      required String currentUserId,
      void Function(Piece piece)? onOpenCollaborators,
    }) async {
      when(
        () => repository.getPiece(piece.id),
      ).thenAnswer((_) async => Success(piece));
      await tester.pumpWidget(
        MaterialApp(
          home: PieceDetailPage(
            pieceRepository: repository,
            currentUserId: currentUserId,
            pieceId: piece.id,
            onOpenScore: (_) {},
            onOpenCollaborators: onOpenCollaborators,
          ),
        ),
      );
      await tester.pump();
      // Flushes flutter_animate's initial delayed-start future for the
      // "Open score" PrimaryButton's fade-in (see core_ui's
      // `skeleton_test.dart`); a zero-duration pump leaves it pending, which
      // trips the test binding's "no pending timers" invariant at teardown.
      await tester.pump(const Duration(milliseconds: 1));
    }

    testWidgets(
      'teacher sees the real studentName on a paired piece, falling back '
      'to an initials-from-id placeholder when unset',
      (tester) async {
        final piece = Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'checksum',
          basePdfPath: '/tmp/p1.pdf',
          teacherId: teacherId,
          studentId: studentId,
          studentName: 'Sam Smith',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        await pumpScreen(tester, piece: piece, currentUserId: teacherId);

        expect(find.text('Sam Smith'), findsOneWidget);
        expect(find.textContaining('Student '), findsNothing);
      },
    );

    testWidgets(
      'teacher sees an initials-from-id placeholder for a paired student '
      'with no studentName yet',
      (tester) async {
        final piece = Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'checksum',
          basePdfPath: '/tmp/p1.pdf',
          teacherId: teacherId,
          studentId: studentId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        await pumpScreen(tester, piece: piece, currentUserId: teacherId);

        expect(find.textContaining('Student '), findsOneWidget);
      },
    );

    testWidgets(
      'student sees the real teacherName, falling back to an '
      'initials-from-id placeholder when unset',
      (tester) async {
        final piece = Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'checksum',
          basePdfPath: '/tmp/p1.pdf',
          teacherId: teacherId,
          studentId: studentId,
          teacherName: 'Jane Doe',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        await pumpScreen(tester, piece: piece, currentUserId: studentId);

        expect(find.text('Jane Doe'), findsOneWidget);
        expect(find.textContaining('Teacher '), findsNothing);
      },
    );

    testWidgets(
      'student sees an initials-from-id placeholder for a teacher with '
      'no teacherName yet',
      (tester) async {
        final piece = Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'checksum',
          basePdfPath: '/tmp/p1.pdf',
          teacherId: teacherId,
          studentId: studentId,
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        await pumpScreen(tester, piece: piece, currentUserId: studentId);

        expect(find.textContaining('Teacher '), findsOneWidget);
      },
    );

    testWidgets('teacher with no paired student sees "No student paired yet"', (
      tester,
    ) async {
      final piece = Piece(
        id: 'p1',
        title: 'Clair de Lune',
        basePdfChecksum: 'checksum',
        basePdfPath: '/tmp/p1.pdf',
        teacherId: teacherId,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

      await pumpScreen(tester, piece: piece, currentUserId: teacherId);

      expect(find.text('No student paired yet.'), findsOneWidget);
    });

    testWidgets(
      'hides the Collaborators tile when onOpenCollaborators is null',
      (tester) async {
        final piece = Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'checksum',
          basePdfPath: '/tmp/p1.pdf',
          teacherId: teacherId,
          collaborators: const [
            Collaborator(uid: studentId),
            Collaborator(uid: 'student-2'),
          ],
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        await pumpScreen(tester, piece: piece, currentUserId: teacherId);

        expect(find.textContaining('Collaborators ('), findsNothing);
      },
    );

    testWidgets(
      'shows "Collaborators (N)" and navigates on tap when wired',
      (tester) async {
        final piece = Piece(
          id: 'p1',
          title: 'Clair de Lune',
          basePdfChecksum: 'checksum',
          basePdfPath: '/tmp/p1.pdf',
          teacherId: teacherId,
          collaborators: const [
            Collaborator(uid: studentId),
            Collaborator(uid: 'student-2'),
          ],
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        );

        Piece? tapped;
        await pumpScreen(
          tester,
          piece: piece,
          currentUserId: teacherId,
          onOpenCollaborators: (p) => tapped = p,
        );

        expect(find.text('Collaborators (2)'), findsOneWidget);

        await tester.tap(find.text('Collaborators (2)'));
        await tester.pump();

        expect(tapped?.id, 'p1');
      },
    );
  });
}
