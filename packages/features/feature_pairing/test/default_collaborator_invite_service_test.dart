import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';
import 'package:pieces/pieces.dart';
import 'package:user_directory/user_directory.dart';

class _FakeMonetizationService extends SimulatedMonetizationService {}

class _FakePieceRepository implements PieceRepository {
  _FakePieceRepository(this.pieces);

  List<Piece> pieces;

  @override
  Future<Result<Piece>> getPiece(String pieceId) async {
    for (final piece in pieces) {
      if (piece.id == pieceId) return Success(piece);
    }
    return ResultFailure<Piece>(StateError('Unknown piece: $pieceId'));
  }

  @override
  Stream<List<Piece>> watchPieces() => Stream.value(pieces);

  @override
  Future<Result<void>> addCollaborator(
    String pieceId, {
    required String userId,
    String? name,
    String? email,
  }) async {
    final piece = pieces.firstWhere((p) => p.id == pieceId);
    if (piece.isCollaborator(userId)) return const Success(null);
    final updated = piece.copyWith(
      collaborators: [
        ...piece.collaborators,
        Collaborator(uid: userId, name: name, email: email),
      ],
    );
    pieces = [
      for (final p in pieces)
        if (p.id == pieceId) updated else p,
    ];
    return const Success(null);
  }

  @override
  Future<Result<void>> removeCollaborator(String pieceId, String userId) =>
      throw UnimplementedError();

  @override
  Future<Result<Piece>> pairCollaborator(
    String pieceId, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
    String? ownerName,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      throw UnimplementedError();

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
    String? ownerName,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> leavePiece(String pieceId) => throw UnimplementedError();

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      throw UnimplementedError();

  @override
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String ownerId,
    required String sourcePath,
    String? collaboratorId,
    String? ownerName,
    String? collaboratorName,
  }) => throw UnimplementedError();
}

void main() {
  group('DefaultCollaboratorInviteService', () {
    const ownerId = 'owner-1';
    const recipientEmail = 'sam@example.com';

    late Piece piece;
    late _FakePieceRepository pieceRepository;
    late _FakeMonetizationService monetization;
    late InMemoryUserDirectory directory;
    late InMemoryUserMessaging messaging;
    late DefaultCollaboratorInviteService service;

    setUp(() {
      piece = Piece(
        id: 'p1',
        title: 'Nocturne',
        basePdfChecksum: 'checksum',
        basePdfPath: '/tmp/p1.pdf',
        ownerId: ownerId,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );
      pieceRepository = _FakePieceRepository([piece]);
      monetization = _FakeMonetizationService();
      directory = InMemoryUserDirectory(
        seed: [
          const DirectoryUser(uid: 'sam-uid', email: recipientEmail),
        ],
      );
      messaging = InMemoryUserMessaging();
      service = DefaultCollaboratorInviteService(
        userDirectory: directory,
        pieceRepository: pieceRepository,
        monetizationService: monetization,
        messageGateway: messaging,
      );
    });

    test(
      'lookupInvitee resolves a discoverable, not-yet-collaborator email',
      () async {
        final result = await service.lookupInvitee(
          pieceId: 'p1',
          email: recipientEmail,
        );

        expect(result, isA<Success<LookupOutcome>>());
        final outcome = (result as Success<LookupOutcome>).value;
        expect(outcome, isA<Resolved>());
        expect((outcome as Resolved).recipient.uid, 'sam-uid');
      },
    );

    test(
      'lookupInvitee resolves NoAccount for an email with no discoverable '
      'account (AC-3)',
      () async {
        final result = await service.lookupInvitee(
          pieceId: 'p1',
          email: 'nobody@example.com',
        );

        expect(
          (result as Success<LookupOutcome>).value,
          isA<NoAccount>(),
        );
      },
    );

    test(
      'lookupInvitee resolves AlreadyCollaborator when the recipient is '
      'already on the piece',
      () async {
        await pieceRepository.addCollaborator(
          'p1',
          userId: 'sam-uid',
          email: recipientEmail,
        );

        final result = await service.lookupInvitee(
          pieceId: 'p1',
          email: recipientEmail,
        );

        expect(
          (result as Success<LookupOutcome>).value,
          isA<AlreadyCollaborator>(),
        );
      },
    );

    test(
      'lookupInvitee resolves AtCap when the piece is at its free-tier cap',
      () async {
        await pieceRepository.addCollaborator(
          'p1',
          userId: 'existing-collaborator',
        );

        final result = await service.lookupInvitee(
          pieceId: 'p1',
          email: recipientEmail,
        );

        expect((result as Success<LookupOutcome>).value, isA<AtCap>());
      },
    );

    test(
      'sendInvite on Resolved records a message for the recipient uid '
      '(AC-1)',
      () async {
        final result = await service.sendInvite(
          pieceId: 'p1',
          ownerId: ownerId,
          ownerName: 'Jane',
          email: recipientEmail,
        );

        expect(result, isA<Success<LookupOutcome>>());
        expect((result as Success<LookupOutcome>).value, isA<Resolved>());

        final inbox = await messaging.inboxFor('sam-uid').first;
        expect(inbox, hasLength(1));
        expect(inbox.single.data['type'], 'invite');
        expect(inbox.single.data['pieceId'], 'p1');
        expect(inbox.single.data['ownerId'], ownerId);
        expect(inbox.single.data['ownerName'], 'Jane');
      },
    );

    test(
      'sendInvite on NoAccount sends nothing',
      () async {
        final result = await service.sendInvite(
          pieceId: 'p1',
          ownerId: ownerId,
          email: 'nobody@example.com',
        );

        expect((result as Success<LookupOutcome>).value, isA<NoAccount>());
        expect(await messaging.inboxFor('sam-uid').first, isEmpty);
      },
    );

    test(
      'sendInvite on AtCap records NOTHING in the gateway (AC-6)',
      () async {
        await pieceRepository.addCollaborator(
          'p1',
          userId: 'existing-collaborator',
        );

        final result = await service.sendInvite(
          pieceId: 'p1',
          ownerId: ownerId,
          email: recipientEmail,
        );

        expect((result as Success<LookupOutcome>).value, isA<AtCap>());
        expect(await messaging.inboxFor('sam-uid').first, isEmpty);
      },
    );

    test('watchInvites maps only invite-typed inbox messages', () async {
      await messaging.sendToUser(
        UserMessage(
          id: 'm1',
          toUid: 'sam-uid',
          title: 'Invite',
          body: 'Join',
          sentAt: DateTime(2024),
          data: const {
            'type': 'invite',
            'pieceId': 'p1',
            'ownerId': ownerId,
            'ownerName': 'Jane',
          },
        ),
      );
      await messaging.sendToUser(
        UserMessage(
          id: 'm2',
          toUid: 'sam-uid',
          title: 'Other',
          body: 'Not an invite',
          sentAt: DateTime(2024),
          data: const {'type': 'something_else'},
        ),
      );

      final invites = await service.watchInvites('sam-uid').first;

      expect(invites, hasLength(1));
      expect(invites.single.messageId, 'm1');
      expect(invites.single.pieceId, 'p1');
      expect(invites.single.ownerId, ownerId);
      expect(invites.single.ownerName, 'Jane');
    });

    test(
      'watchInvites skips a malformed invite (missing pieceId/ownerId) '
      'instead of tearing down the stream',
      () async {
        await messaging.sendToUser(
          UserMessage(
            id: 'malformed',
            toUid: 'sam-uid',
            title: 'Invite',
            body: 'Join',
            sentAt: DateTime(2024),
            data: const {'type': 'invite', 'ownerName': 'Jane'},
          ),
        );
        await messaging.sendToUser(
          UserMessage(
            id: 'good',
            toUid: 'sam-uid',
            title: 'Invite',
            body: 'Join',
            sentAt: DateTime(2024),
            data: const {
              'type': 'invite',
              'pieceId': 'p1',
              'ownerId': ownerId,
            },
          ),
        );

        final invites = await service.watchInvites('sam-uid').first;

        expect(invites, hasLength(1));
        expect(invites.single.messageId, 'good');
      },
    );

    test('acceptInvite records the accepting uid and email (AC-2)', () async {
      const invite = InviteMessage(
        messageId: 'm1',
        pieceId: 'p1',
        ownerId: ownerId,
        ownerName: 'Jane',
      );

      final result = await service.acceptInvite(
        invite,
        accepterId: 'sam-uid',
        accepterName: 'Sam',
        accepterEmail: recipientEmail,
      );

      expect(result, isA<Success<void>>());
      final fetched = await pieceRepository.getPiece('p1');
      final updated = (fetched as Success<Piece>).value;
      expect(updated.isCollaborator('sam-uid'), isTrue);
      expect(updated.collaborators.single.email, recipientEmail);
    });

    test(
      'acceptInvite re-checks the cap and fails if it filled since send',
      () async {
        await pieceRepository.addCollaborator(
          'p1',
          userId: 'someone-else',
        );
        const invite = InviteMessage(
          messageId: 'm1',
          pieceId: 'p1',
          ownerId: ownerId,
        );

        final result = await service.acceptInvite(
          invite,
          accepterId: 'sam-uid',
        );

        expect(result, isA<ResultFailure<void>>());
      },
    );
  });
}
