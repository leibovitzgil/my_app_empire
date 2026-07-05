@Tags(['golden'])
library;

import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.

class MockCollaboratorInviteService extends Mock
    implements CollaboratorInviteService {}

class MockInviteService extends Mock implements InviteService {}

class MockMonetizationService extends Mock implements MonetizationService {}

class MockPieceRepository extends Mock implements PieceRepository {}

void main() {
  group('InviteSheet goldens', () {
    const teacherId = 'teacher-1';
    const pieceId = 'p1';
    const email = 'student@example.com';

    late MockCollaboratorInviteService collaboratorInviteService;
    late MockInviteService inviteService;
    late MockMonetizationService monetization;
    late MockPieceRepository pieceRepository;

    setUp(() {
      collaboratorInviteService = MockCollaboratorInviteService();
      inviteService = MockInviteService();
      monetization = MockMonetizationService();
      pieceRepository = MockPieceRepository();
      when(() => monetization.getOfferings()).thenAnswer((_) async => null);
      when(() => monetization.isProUser()).thenAnswer((_) async => true);
      when(() => pieceRepository.getPiece(pieceId)).thenAnswer(
        (_) async => Success(
          Piece(
            id: pieceId,
            title: 'Nocturne',
            basePdfChecksum: 'c',
            basePdfPath: '/tmp/p.pdf',
            teacherId: teacherId,
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ),
      );
    });

    Future<void> openSheet(
      WidgetTester tester, {
      required Brightness brightness,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            brightness: brightness,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showInviteSheet(
                  context,
                  collaboratorInviteService: collaboratorInviteService,
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
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), email);
      await tester.pumpAndSettle();
    }

    testWidgets('AppTextField errorText (not found, light)', (tester) async {
      when(
        () => collaboratorInviteService.lookupInvitee(
          pieceId: pieceId,
          email: email,
        ),
      ).thenAnswer((_) async => const Success(NoAccount()));

      await openSheet(tester, brightness: Brightness.light);

      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/invite_sheet_not_found_light.png'),
      );
    });

    testWidgets('AppTextField errorText (already collaborator, dark)', (
      tester,
    ) async {
      when(
        () => collaboratorInviteService.lookupInvitee(
          pieceId: pieceId,
          email: email,
        ),
      ).thenAnswer((_) async => const Success(AlreadyCollaborator()));

      await openSheet(tester, brightness: Brightness.dark);

      await expectLater(
        find.byType(BottomSheet),
        matchesGoldenFile('goldens/invite_sheet_already_collaborator_dark.png'),
      );
    });
  });
}
