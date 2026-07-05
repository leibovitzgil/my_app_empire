import 'dart:convert';
import 'dart:math';

import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/src/data/invite_deep_links.dart';
import 'package:feature_pairing/src/domain/invite_service.dart';
import 'package:local_storage/local_storage.dart';
import 'package:monetization/monetization.dart';
import 'package:pieces/pieces.dart';

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
    String Function()? tokenGenerator,
    DateTime Function()? clock,
  }) : _pieceRepository = pieceRepository,
       _monetization = monetizationService,
       _storage = storage,
       _tokenGenerator = tokenGenerator ?? _generateToken,
       _now = clock ?? DateTime.now;

  static const String _storageKey = 'pairing.invites';
  static const String _tokenChars =
      'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789';

  final PieceRepository _pieceRepository;
  final MonetizationService _monetization;
  final LocalStorageService _storage;
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
    String? teacherName,
  }) => Result.guard<InviteLink>(() async {
    final piece = (await _pieceRepository.getPiece(pieceId)).orThrow();
    if (piece.teacherId != teacherId) {
      throw const InviteException(
        'Only the teacher who owns this piece can invite for it.',
      );
    }

    final isPro = await _monetization.isProUser();
    // Per-piece cap (FIX-1/FIX-2): the SAME `CollaboratorLimits` predicate
    // the email-invite path (`DefaultCollaboratorInviteService`) uses,
    // counting only this piece's current collaborators — never a
    // library-wide total. Both invite paths converge on
    // `PieceRepository.addCollaborator` and must never diverge here.
    if (CollaboratorLimits.isAtCap(piece, isPro)) {
      throw const InviteException(
        'Free plan allows 1 collaborator. Upgrade to invite more.',
      );
    }

    final token = _tokenGenerator();
    final invites = _load()
      ..add(
        _StoredInvite(
          token: token,
          pieceId: pieceId,
          teacherId: teacherId,
          teacherName: teacherName,
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
          teacherName: piece.teacherName ?? invite.teacherName,
        );
      });

  @override
  Future<Result<void>> acceptInvite(
    String token, {
    required String studentId,
    String? studentName,
    String? studentEmail,
  }) => Result.guard<void>(() async {
    final invites = _load();
    final invite = _requireValid(invites, token);

    // Re-assert the per-piece cap immediately before committing the
    // pairing (FIX-1/FIX-2, same `CollaboratorLimits` predicate as
    // `createInvite` and the email path). `createInvite`'s check only
    // guards against this piece already being at cap *at creation time* —
    // it can't see a sibling invite (for the SAME piece) accepted
    // concurrently. Re-checking the piece's current collaborator count
    // right before `pairStudent` closes that gap for the sequential case:
    // accepting invite A lands a collaborator, so a subsequently-accepted
    // invite B for the same piece sees that fresh count and is rejected if
    // it would exceed the cap. This is deliberately per-piece, not a
    // library-wide count across the teacher's other pieces.
    final piece = (await _pieceRepository.getPiece(invite.pieceId)).orThrow();
    final isPro = await _monetization.isProUser();
    if (CollaboratorLimits.isAtCap(piece, isPro)) {
      throw const InviteException(
        'Free plan allows 1 collaborator. Upgrade to invite more.',
      );
    }

    (await _pieceRepository.pairStudent(
      invite.pieceId,
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      // `pairStudent` only ever uses this to backfill a piece that has no
      // `teacherName` yet (e.g. imported before that field existed) —
      // `importPiece` is otherwise the source of truth, so it's always
      // safe to pass the invite's captured name through unconditionally.
      teacherName: invite.teacherName,
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
    this.teacherName,
    this.consumed = false,
  });

  factory _StoredInvite.fromJson(Map<String, dynamic> json) => _StoredInvite(
    token: json['token'] as String,
    pieceId: json['pieceId'] as String,
    teacherId: json['teacherId'] as String,
    teacherName: json['teacherName'] as String?,
    createdAtMillis: json['createdAtMillis'] as int,
    consumed: json['consumed'] as bool? ?? false,
  );

  final String token;
  final String pieceId;
  final String teacherId;
  final String? teacherName;
  final int createdAtMillis;
  final bool consumed;

  _StoredInvite copyWith({bool? consumed}) => _StoredInvite(
    token: token,
    pieceId: pieceId,
    teacherId: teacherId,
    teacherName: teacherName,
    createdAtMillis: createdAtMillis,
    consumed: consumed ?? this.consumed,
  );

  Map<String, dynamic> toJson() => {
    'token': token,
    'pieceId': pieceId,
    'teacherId': teacherId,
    'teacherName': teacherName,
    'createdAtMillis': createdAtMillis,
    'consumed': consumed,
  };
}
