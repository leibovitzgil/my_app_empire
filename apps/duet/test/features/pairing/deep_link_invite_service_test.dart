import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  Stream<Map<String, DateTime>> watchReads() =>
      Stream.value(const <String, DateTime>{});

  @override
  Future<Result<void>> markOpened(String pieceId) async =>
      const Success<void>(null);

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
  Future<Result<void>> removeCollaborator(String pieceId, String userId) async {
    final piece = pieces.firstWhere((p) => p.id == pieceId);
    final updated = piece.copyWith(
      collaborators: piece.collaborators
          .where((collaborator) => collaborator.uid != userId)
          .toList(),
    );
    pieces = [
      for (final p in pieces)
        if (p.id == pieceId) updated else p,
    ];
    return const Success(null);
  }

  @override
  Future<Result<Piece>> pairCollaborator(
    String pieceId, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
    String? ownerName,
  }) async {
    final piece = pieces.firstWhere((p) => p.id == pieceId);
    if (ownerName != null && piece.ownerName == null) {
      pieces = [
        for (final p in pieces)
          if (p.id == pieceId) p.copyWith(ownerName: ownerName) else p,
      ];
    }
    await addCollaborator(
      pieceId,
      userId: collaboratorId,
      name: collaboratorName,
      email: collaboratorEmail,
    );
    return Success(pieces.firstWhere((p) => p.id == pieceId));
  }

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
  group('DeepLinkInviteService', () {
    const ownerId = 'owner-1';
    const collaboratorId = 'collaborator-1';

    late Piece piece;
    late _FakePieceRepository pieceRepository;
    late _FakeMonetizationService monetization;
    late LocalStorageService storage;
    late DeepLinkInviteService service;
    var tokenSeq = 0;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      storage = LocalStorageService(prefs);
      monetization = _FakeMonetizationService();
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
      tokenSeq = 0;
      service = DeepLinkInviteService(
        pieceRepository: pieceRepository,
        monetizationService: monetization,
        storage: storage,
        tokenGenerator: () => 'token-${tokenSeq++}',
      );
    });

    test('createInvite mints a link with the expected shareable uri', () async {
      final result = await service.createInvite(
        ownerId: ownerId,
        pieceId: 'p1',
      );

      expect(result, isA<Success<InviteLink>>());
      final link = (result as Success<InviteLink>).value;
      expect(link.uri.toString(), 'https://duet.app/invite/token-0');
      expect(link.pieceId, 'p1');
      expect(link.ownerId, ownerId);
    });

    test(
      'createInvite fails when the caller does not own the piece',
      () async {
        final result = await service.createInvite(
          ownerId: 'someone-else',
          pieceId: 'p1',
        );
        expect(result, isA<ResultFailure<InviteLink>>());
      },
    );

    test(
      'createInvite fails when the piece is already at the free-tier '
      'collaborator cap (FIX-1/FIX-2: per-piece, not library-wide)',
      () async {
        pieceRepository.pieces = [
          piece.copyWith(
            collaborators: const [Collaborator(uid: 'existing-collaborator')],
          ),
        ];

        final result = await service.createInvite(
          ownerId: ownerId,
          pieceId: 'p1',
        );

        expect(result, isA<ResultFailure<InviteLink>>());
      },
    );

    test(
      'createInvite succeeds for a free owner even when a DIFFERENT '
      'piece is already paired — the cap is per-piece, never a library-wide '
      'total (FIX-1/FIX-2 regression guard)',
      () async {
        pieceRepository.pieces = [
          piece,
          Piece(
            id: 'p2',
            title: 'Already paired',
            basePdfChecksum: 'c',
            basePdfPath: '/tmp/p2.pdf',
            ownerId: ownerId,
            collaborators: const [Collaborator(uid: 'existing-collaborator')],
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ];

        final result = await service.createInvite(
          ownerId: ownerId,
          pieceId: 'p1',
        );

        expect(result, isA<Success<InviteLink>>());
      },
    );

    test('createInvite succeeds over the cap for a pro owner', () async {
      pieceRepository.pieces = [
        piece.copyWith(
          collaborators: const [Collaborator(uid: 'existing-collaborator')],
        ),
      ];
      monetization.setProStatus(true);

      final result = await service.createInvite(
        ownerId: ownerId,
        pieceId: 'p1',
      );

      expect(result, isA<Success<InviteLink>>());
    });

    test(
      'resolveInvite returns the piece/owner for a pending invite',
      () async {
        await service.createInvite(ownerId: ownerId, pieceId: 'p1');

        final result = await service.resolveInvite('token-0');

        expect(result, isA<Success<InviteDetails>>());
        final details = (result as Success<InviteDetails>).value;
        expect(details.pieceId, 'p1');
        expect(details.pieceTitle, 'Nocturne');
        expect(details.ownerId, ownerId);
      },
    );

    test(
      'resolveInvite surfaces the real ownerName captured at '
      "createInvite time, when the piece doesn't already have one",
      () async {
        await service.createInvite(
          ownerId: ownerId,
          pieceId: 'p1',
          ownerName: 'Jane Doe',
        );

        final result = await service.resolveInvite('token-0');

        expect(
          (result as Success<InviteDetails>).value.ownerName,
          'Jane Doe',
        );
      },
    );

    test(
      "resolveInvite prefers the piece's own ownerName over the invite's "
      'captured one, when the piece already has one',
      () async {
        pieceRepository.pieces = [
          Piece(
            id: piece.id,
            title: piece.title,
            basePdfChecksum: piece.basePdfChecksum,
            basePdfPath: piece.basePdfPath,
            ownerId: piece.ownerId,
            ownerName: 'Piece-level owner name',
            createdAt: piece.createdAt,
            updatedAt: piece.updatedAt,
          ),
        ];
        await service.createInvite(
          ownerId: ownerId,
          pieceId: 'p1',
          ownerName: 'Invite-time owner name',
        );

        final result = await service.resolveInvite('token-0');

        expect(
          (result as Success<InviteDetails>).value.ownerName,
          'Piece-level owner name',
        );
      },
    );

    test('resolveInvite fails for an unknown token', () async {
      final result = await service.resolveInvite('does-not-exist');
      expect(result, isA<ResultFailure<InviteDetails>>());
    });

    test(
      'acceptInvite pairs the collaborator and consumes the invite',
      () async {
        await service.createInvite(ownerId: ownerId, pieceId: 'p1');

        final result = await service.acceptInvite(
          'token-0',
          collaboratorId: collaboratorId,
        );
        expect(result, isA<Success<void>>());

        final fetched = await pieceRepository.getPiece('p1');
        expect((fetched as Success<Piece>).value.collaboratorIds, [
          collaboratorId,
        ]);

        final secondAttempt = await service.acceptInvite(
          'token-0',
          collaboratorId: 'someone-else',
        );
        expect(secondAttempt, isA<ResultFailure<void>>());
      },
    );

    test(
      "acceptInvite stores the accepting collaborator's real "
      'collaboratorName, and backfills ownerName from the invite when the '
      'piece has none',
      () async {
        await service.createInvite(
          ownerId: ownerId,
          pieceId: 'p1',
          ownerName: 'Jane Doe',
        );

        await service.acceptInvite(
          'token-0',
          collaboratorId: collaboratorId,
          collaboratorName: 'Sam Smith',
        );

        final fetched = await pieceRepository.getPiece('p1');
        final paired = (fetched as Success<Piece>).value;
        expect(paired.collaborators.single.name, 'Sam Smith');
        expect(paired.ownerName, 'Jane Doe');
      },
    );

    test('acceptInvite fails for an invalid token', () async {
      final result = await service.acceptInvite(
        'bogus',
        collaboratorId: collaboratorId,
      );
      expect(result, isA<ResultFailure<void>>());
    });

    test(
      'link accept is cap-gated by CURRENT collaborator count '
      '(FIX-1/AC-6/AC-11): an outstanding second link for the SAME piece '
      'still resolves, but accepting it once the free-tier cap is hit is '
      'rejected',
      () async {
        final firstInvite = await service.createInvite(
          ownerId: ownerId,
          pieceId: 'p1',
        );
        final secondInvite = await service.createInvite(
          ownerId: ownerId,
          pieceId: 'p1',
        );
        expect(firstInvite, isA<Success<InviteLink>>());
        expect(secondInvite, isA<Success<InviteLink>>());

        // The outstanding second link still resolves (AC-11) — creating it
        // wasn't rejected, since the piece had no collaborators yet.
        final resolved = await service.resolveInvite('token-1');
        expect(resolved, isA<Success<InviteDetails>>());

        final firstAccept = await service.acceptInvite(
          'token-0',
          collaboratorId: 'collaborator-1',
        );
        expect(firstAccept, isA<Success<void>>());

        // Accepting the second (still-valid, unconsumed) link for the same
        // piece now exceeds the free-tier cap of 1 and must be rejected.
        final secondAccept = await service.acceptInvite(
          'token-1',
          collaboratorId: 'collaborator-2',
        );
        expect(secondAccept, isA<ResultFailure<void>>());

        final fetched = await pieceRepository.getPiece('p1');
        expect((fetched as Success<Piece>).value.collaboratorCount, 1);
      },
    );

    test(
      'acceptInvite succeeds over the free-tier cap for a pro owner '
      '(same piece, second collaborator)',
      () async {
        monetization.setProStatus(true);

        await service.createInvite(ownerId: ownerId, pieceId: 'p1');
        await service.createInvite(ownerId: ownerId, pieceId: 'p1');

        final firstAccept = await service.acceptInvite(
          'token-0',
          collaboratorId: 'collaborator-1',
        );
        final secondAccept = await service.acceptInvite(
          'token-1',
          collaboratorId: 'collaborator-2',
        );

        expect(firstAccept, isA<Success<void>>());
        expect(secondAccept, isA<Success<void>>());

        final fetched = await pieceRepository.getPiece('p1');
        expect((fetched as Success<Piece>).value.collaboratorCount, 2);
      },
    );
  });
}
