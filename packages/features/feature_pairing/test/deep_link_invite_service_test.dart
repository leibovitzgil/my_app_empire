import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';
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
  Future<Result<Piece>> pairStudent(
    String pieceId, {
    required String studentId,
  }) async {
    final piece = pieces.firstWhere((p) => p.id == pieceId);
    final updated = piece.copyWith(studentId: studentId);
    pieces = [
      for (final p in pieces)
        if (p.id == pieceId) updated else p,
    ];
    return Success(updated);
  }

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      throw UnimplementedError();

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> leavePiece(String pieceId) => throw UnimplementedError();

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      throw UnimplementedError();
}

void main() {
  group('DeepLinkInviteService', () {
    const teacherId = 'teacher-1';
    const studentId = 'student-1';

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
        teacherId: teacherId,
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
        teacherId: teacherId,
        pieceId: 'p1',
      );

      expect(result, isA<Success<InviteLink>>());
      final link = (result as Success<InviteLink>).value;
      expect(link.uri.toString(), 'https://duet.app/invite/token-0');
      expect(link.pieceId, 'p1');
      expect(link.teacherId, teacherId);
    });

    test(
      'createInvite fails when the caller does not own the piece',
      () async {
        final result = await service.createInvite(
          teacherId: 'someone-else',
          pieceId: 'p1',
        );
        expect(result, isA<ResultFailure<InviteLink>>());
      },
    );

    test(
      'createInvite fails at the free-tier student limit for a non-pro '
      'teacher',
      () async {
        pieceRepository.pieces = [
          piece,
          Piece(
            id: 'p2',
            title: 'Already paired',
            basePdfChecksum: 'c',
            basePdfPath: '/tmp/p2.pdf',
            teacherId: teacherId,
            studentId: 'existing-student',
            createdAt: DateTime(2024),
            updatedAt: DateTime(2024),
          ),
        ];

        final result = await service.createInvite(
          teacherId: teacherId,
          pieceId: 'p1',
        );

        expect(result, isA<ResultFailure<InviteLink>>());
      },
    );

    test('createInvite succeeds over the limit for a pro teacher', () async {
      pieceRepository.pieces = [
        piece,
        Piece(
          id: 'p2',
          title: 'Already paired',
          basePdfChecksum: 'c',
          basePdfPath: '/tmp/p2.pdf',
          teacherId: teacherId,
          studentId: 'existing-student',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      ];
      monetization.setProStatus(true);

      final result = await service.createInvite(
        teacherId: teacherId,
        pieceId: 'p1',
      );

      expect(result, isA<Success<InviteLink>>());
    });

    test(
      'resolveInvite returns the piece/teacher for a pending invite',
      () async {
        await service.createInvite(teacherId: teacherId, pieceId: 'p1');

        final result = await service.resolveInvite('token-0');

        expect(result, isA<Success<InviteDetails>>());
        final details = (result as Success<InviteDetails>).value;
        expect(details.pieceId, 'p1');
        expect(details.pieceTitle, 'Nocturne');
        expect(details.teacherId, teacherId);
      },
    );

    test('resolveInvite fails for an unknown token', () async {
      final result = await service.resolveInvite('does-not-exist');
      expect(result, isA<ResultFailure<InviteDetails>>());
    });

    test('acceptInvite pairs the student and consumes the invite', () async {
      await service.createInvite(teacherId: teacherId, pieceId: 'p1');

      final result = await service.acceptInvite(
        'token-0',
        studentId: studentId,
      );
      expect(result, isA<Success<void>>());

      final fetched = await pieceRepository.getPiece('p1');
      expect((fetched as Success<Piece>).value.studentId, studentId);

      final secondAttempt = await service.acceptInvite(
        'token-0',
        studentId: 'someone-else',
      );
      expect(secondAttempt, isA<ResultFailure<void>>());
    });

    test('acceptInvite fails for an invalid token', () async {
      final result = await service.acceptInvite(
        'bogus',
        studentId: studentId,
      );
      expect(result, isA<ResultFailure<void>>());
    });
  });
}
