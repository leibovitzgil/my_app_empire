import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

class MockInviteService extends Mock implements InviteService {}

class MockMonetizationService extends Mock implements MonetizationService {}

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('showInviteSheet', () {
    const teacherId = 'teacher-1';
    const pieceId = 'p1';

    late MockInviteService inviteService;
    late MockMonetizationService monetization;
    late MockPieceRepository pieceRepository;

    setUp(() {
      inviteService = MockInviteService();
      monetization = MockMonetizationService();
      pieceRepository = MockPieceRepository();
      // The invite sheet's own `PaywallBloc` also loads offerings on start,
      // independent of the invite gate check.
      when(() => monetization.getOfferings()).thenAnswer((_) async => null);
    });

    Future<void> openSheet(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showInviteSheet(
                  context,
                  inviteService: inviteService,
                  monetizationService: monetization,
                  pieceRepository: pieceRepository,
                  teacherId: teacherId,
                  pieceId: pieceId,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pump();
    }

    testWidgets(
      'a free-tier teacher at the pairing limit sees the paywall instead '
      'of the invite affordances',
      (tester) async {
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(() => pieceRepository.watchPieces()).thenAnswer(
          (_) => Stream.value([
            Piece(
              id: pieceId,
              title: 'Nocturne',
              basePdfChecksum: 'c',
              basePdfPath: '/tmp/p.pdf',
              teacherId: teacherId,
              studentId: 'already-paired-student',
              createdAt: DateTime(2024),
              updatedAt: DateTime(2024),
            ),
          ]),
        );

        await openSheet(tester);
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsOneWidget);
        expect(find.text('Get invite link'), findsNothing);
      },
    );

    testWidgets(
      'a pro teacher never sees the paywall and can create an invite link',
      (tester) async {
        when(() => monetization.isProUser()).thenAnswer((_) async => true);
        when(
          () => inviteService.createInvite(
            teacherId: teacherId,
            pieceId: pieceId,
            teacherName: any(named: 'teacherName'),
          ),
        ).thenAnswer(
          (_) async => Success(
            InviteLink(
              token: 'tok',
              uri: Uri.parse('https://duet.app/invite/tok'),
              pieceId: pieceId,
              teacherId: teacherId,
            ),
          ),
        );

        await openSheet(tester);
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsNothing);
        expect(find.text('Get invite link'), findsOneWidget);

        await tester.tap(find.text('Get invite link'));
        await tester.pumpAndSettle();

        expect(find.text('https://duet.app/invite/tok'), findsOneWidget);
      },
    );

    testWidgets(
      'a free-tier teacher under the pairing limit is not gated',
      (tester) async {
        when(() => monetization.isProUser()).thenAnswer((_) async => false);
        when(
          () => pieceRepository.watchPieces(),
        ).thenAnswer((_) => Stream.value(const []));

        await openSheet(tester);
        await tester.pumpAndSettle();

        expect(find.byType(PaywallScreen), findsNothing);
        expect(find.text('Get invite link'), findsOneWidget);
      },
    );
  });
}
