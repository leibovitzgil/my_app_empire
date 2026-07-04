import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockInviteService extends Mock implements InviteService {}

void main() {
  group('AcceptInviteScreen', () {
    const token = 'tok-1';
    const studentId = 'student-1';
    const details = InviteDetails(
      pieceId: 'p1',
      pieceTitle: 'Clair de Lune',
      teacherId: 'teacher-1',
    );

    late MockInviteService inviteService;

    setUp(() {
      inviteService = MockInviteService();
    });

    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AcceptInvitePage(
            inviteService: inviteService,
            token: token,
            studentId: studentId,
            onAccepted: (_) {},
          ),
        ),
      );
    }

    testWidgets('shows the piece title and teacher once resolved', (
      tester,
    ) async {
      when(
        () => inviteService.resolveInvite(token),
      ).thenAnswer((_) async => const Success(details));

      await pumpScreen(tester);
      await tester.pump();
      await tester.pump();
      // Flushes flutter_animate's initial delayed-start future for
      // `PrimaryButton`/`SecondaryButton`'s fade-in (see core_ui's
      // `skeleton_test.dart` for the same pattern); a zero-duration pump
      // leaves it pending, tripping the test binding's teardown invariant.
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text('Clair de Lune'), findsOneWidget);
      expect(find.text('Accept'), findsOneWidget);
      expect(find.text('Decline'), findsOneWidget);
    });

    testWidgets('shows an error state for an invalid token', (tester) async {
      when(() => inviteService.resolveInvite(token)).thenAnswer(
        (_) async => const ResultFailure<InviteDetails>(
          InviteException('This invite link is invalid or has expired.'),
        ),
      );

      await pumpScreen(tester);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(find.text("Couldn't open this invite"), findsOneWidget);
      // Shown twice: once in `ErrorRetryView`'s message, once in the
      // snackbar the `BlocConsumer` listener surfaces for the same failure.
      expect(find.textContaining('invalid or has expired'), findsWidgets);
    });

    testWidgets('accepting calls onAccepted with the paired piece id', (
      tester,
    ) async {
      when(
        () => inviteService.resolveInvite(token),
      ).thenAnswer((_) async => const Success(details));
      when(
        () => inviteService.acceptInvite(token, studentId: studentId),
      ).thenAnswer((_) async => const Success<void>(null));

      String? acceptedPieceId;
      await tester.pumpWidget(
        MaterialApp(
          home: AcceptInvitePage(
            inviteService: inviteService,
            token: token,
            studentId: studentId,
            onAccepted: (pieceId) => acceptedPieceId = pieceId,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Accept'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));

      expect(acceptedPieceId, 'p1');
    });
  });
}
