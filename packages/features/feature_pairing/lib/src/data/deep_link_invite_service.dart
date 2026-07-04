import 'dart:convert';
import 'dart:math';

import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/src/data/invite_deep_links.dart';
import 'package:feature_pairing/src/domain/invite_service.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

/// Free-tier cap on paired students per teacher, enforced defensively inside
/// [DeepLinkInviteService.createInvite] as a backstop. The primary gate is
/// UI-level (`InviteBloc` checks this *before* even showing the invite
/// sheet, so a gated teacher sees `feature_paywall`'s `PaywallScreen`
/// instead) — this is belt-and-suspenders, the same pattern `ScoreBloc` uses
/// to backstop `AnnotationRepository`'s ownership guards.
const int defaultFreeTierStudentLimit = 1;

/// An [InviteService] that mints tokenized invite links (see
/// [InviteDeepLinks]), persists pending/consumed invites locally via
/// [LocalStorageService] (JSON-encoded, mirroring `LocalPieceRepository`'s
/// own persistence style), and completes acceptance via
/// [PieceRepository.pairStudent].
class DeepLinkInviteService implements InviteService {
  /// Creates a [DeepLinkInviteService]. [tokenGenerator] defaults to a
  /// cryptographically random 20-character token; inject a fake in tests for
  /// deterministic assertions.
  DeepLinkInviteService({
    required PieceRepository pieceRepository,
    required MonetizationService monetizationService,
    required LocalStorageService storage,
    int freeTierStudentLimit = defaultFreeTierStudentLimit,
    String Function()? tokenGenerator,
    DateTime Function()? clock,
  }) : _pieceRepository = pieceRepository,
       _monetization = monetizationService,
       _storage = storage,
       _freeTierStudentLimit = freeTierStudentLimit,
       _tokenGenerator = tokenGenerator ?? _generateToken,
       _now = clock ?? DateTime.now;

  static const String _storageKey = 'pairing.invites';
  static const String _tokenChars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  final PieceRepository _pieceRepository;
  final MonetizationService _monetization;
  final LocalStorageService _storage;
  final int _freeTierStudentLimit;
  final String Function() _tokenGenerator;
  final DateTime Function() _now;

  static String _generateToken() {
    final random = Random.secure();
    return List.generate(
      20,
      (_) => _tokenChars[random.nextInt(_tokenChars.length)],
    ).join();
  }

  List<_StoredInvite> _load() {
    final raw = _storage.getString(_storageKey);
    if (raw == null) return <_StoredInvite>[];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => _StoredInvite.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> _persist(List<_StoredInvite> invites) => _storage.setString(
    _storageKey,
    jsonEncode(invites.map((i) => i.toJson()).toList()),
  );

  _StoredInvite? _findOrNull(List<_StoredInvite> invites, String token) {
    for (final invite in invites) {
      if (invite.token == token) return invite;
    }
    return null;
  }

  _StoredInvite _requireValid(List<_StoredInvite> invites, String token) {
    final invite = _findOrNull(invites, token);
    if (invite == null) {
      throw const InviteException(
        'This invite link is invalid or has expired.',
      );
    }
    if (invite.consumed) {
      throw const InviteException('This invite has already been used.');
    }
    return invite;
  }

  @override
  Future<Result<InviteLink>> createInvite({
    required String teacherId,
    required String pieceId,
  }) => Result.guard<InviteLink>(() async {
    final piece = (await _pieceRepository.getPiece(pieceId)).orThrow();
    if (piece.teacherId != teacherId) {
      throw const InviteException(
        'Only the teacher who owns this piece can invite for it.',
      );
    }

    final isPro = await _monetization.isProUser();
    if (!isPro && piece.studentId == null) {
      final pieces = await _pieceRepository.watchPieces().first;
      final pairedStudents = pieces
          .where((p) => p.teacherId == teacherId && p.studentId != null)
          .map((p) => p.studentId)
          .toSet();
      if (pairedStudents.length >= _freeTierStudentLimit) {
        throw const InviteException(
          'Free plan allows 1 student. Upgrade to invite more.',
        );
      }
    }

    final token = _tokenGenerator();
    final invites = _load()
      ..add(
        _StoredInvite(
          token: token,
          pieceId: pieceId,
          teacherId: teacherId,
          createdAtMillis: _now().millisecondsSinceEpoch,
        ),
      );
    await _persist(invites);
    return InviteLink(
      token: token,
      uri: InviteDeepLinks.buildUri(token),
      pieceId: pieceId,
      teacherId: teacherId,
    );
  });

  @override
  Future<Result<InviteDetails>> resolveInvite(String token) =>
      Result.guard<InviteDetails>(() async {
        final invite = _requireValid(_load(), token);
        final piece = (await _pieceRepository.getPiece(
          invite.pieceId,
        )).orThrow();
        return InviteDetails(
          pieceId: piece.id,
          pieceTitle: piece.title,
          teacherId: invite.teacherId,
        );
      });

  @override
  Future<Result<void>> acceptInvite(
    String token, {
    required String studentId,
  }) => Result.guard<void>(() async {
    final invites = _load();
    final invite = _requireValid(invites, token);

    // Re-assert the free-tier cap immediately before committing the
    // pairing. `createInvite`'s check only guards against the piece
    // invited-for *at creation time* already being paired — it can't see
    // sibling invites created concurrently for other unpaired pieces. Since
    // pairing only actually lands here (via `pairStudent`), re-counting
    // paired students right before that call closes the gap for the
    // sequential case: accepting invite A lands a pairing, so a
    // subsequently-accepted invite B for the same teacher sees that fresh
    // count and is rejected if it would exceed the cap.
    final piece = (await _pieceRepository.getPiece(invite.pieceId)).orThrow();
    final isPro = await _monetization.isProUser();
    if (!isPro && piece.studentId == null) {
      final pieces = await _pieceRepository.watchPieces().first;
      final pairedStudents = pieces
          .where(
            (p) => p.teacherId == invite.teacherId && p.studentId != null,
          )
          .map((p) => p.studentId)
          .toSet();
      if (pairedStudents.length >= _freeTierStudentLimit) {
        throw const InviteException(
          'Free plan allows 1 student. Upgrade to invite more.',
        );
      }
    }

    (await _pieceRepository.pairStudent(
      invite.pieceId,
      studentId: studentId,
    )).orThrow();
    await _persist([
      for (final stored in invites)
        if (stored.token == token) stored.copyWith(consumed: true) else stored,
    ]);
  });
}

/// A pending/consumed invite, persisted locally. Kept private —
/// [InviteLink]/[InviteDetails] are the public surface.
class _StoredInvite {
  const _StoredInvite({
    required this.token,
    required this.pieceId,
    required this.teacherId,
    required this.createdAtMillis,
    this.consumed = false,
  });

  factory _StoredInvite.fromJson(Map<String, dynamic> json) => _StoredInvite(
    token: json['token'] as String,
    pieceId: json['pieceId'] as String,
    teacherId: json['teacherId'] as String,
    createdAtMillis: json['createdAtMillis'] as int,
    consumed: json['consumed'] as bool? ?? false,
  );

  final String token;
  final String pieceId;
  final String teacherId;
  final int createdAtMillis;
  final bool consumed;

  _StoredInvite copyWith({bool? consumed}) => _StoredInvite(
    token: token,
    pieceId: pieceId,
    teacherId: teacherId,
    createdAtMillis: createdAtMillis,
    consumed: consumed ?? this.consumed,
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'pieceId': pieceId,
    'teacherId': teacherId,
    'createdAtMillis': createdAtMillis,
    'consumed': consumed,
  };
}
