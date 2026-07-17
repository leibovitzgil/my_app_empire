// cloud_functions exports its own (unrelated) `Result`; ours is core_utils'.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:core_utils/core_utils.dart';
import 'package:duet/features/pairing/pairing.dart';

/// The production [InviteService] (task M5.2): tokenized deep-link invites
/// as single-use, expiring `/inviteTokens/{token}` docs, driven entirely
/// through Cloud Functions — the rules deny every client read/write on that
/// collection, so this impl is pure transport.
///
/// - [createInvite] → `createInviteToken` (owner-only + cap-checked
///   server-side; the callable mints the doc with `expiresAt = now + 14d`
///   and returns the shareable URL).
/// - [resolveInvite] → `resolveInviteToken` (the accept screen's read-only
///   piece-title preview — a fresh invitee can't read the piece doc itself,
///   its rules are participant-gated).
/// - [acceptInvite] → `acceptInviteToken` (transactional: validates
///   exists ∧ !consumed ∧ !expired, appends the caller to the piece's
///   membership arrays, marks the token `consumed`/`consumedBy`).
///
/// The callables' typed denials (`details.reason`) are mapped onto
/// [InviteException.reason] so `AcceptInviteCubit` can surface the matching
/// [AcceptInviteStatus] state (`atCap`, `alreadyCollaborator`) or the
/// standing invalid/expired/consumed failure copy. Mock-path counterpart:
/// [DeepLinkInviteService], bound under `useFirebase: false` (G2).
class CallableInviteService implements InviteService {
  /// Creates a [CallableInviteService] over the region-pinned [functions]
  /// instance.
  CallableInviteService({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  Future<Result<InviteLink>> createInvite({
    required String ownerId,
    required String pieceId,
    String? ownerName,
  }) => _guarded<InviteLink>(() async {
    // The callable derives the owner (and their display name) from the
    // caller's own auth token — [ownerId]/[ownerName] ride along in the
    // returned link only.
    final result = await _functions
        .httpsCallable('createInviteToken')
        .call<Object?>(<String, dynamic>{'pieceId': pieceId});
    final data = Map<String, dynamic>.from(result.data! as Map);
    return InviteLink(
      token: data['token'] as String,
      // The server is the URL authority (`inviteUrlFor`, mirroring
      // `InviteDeepLinks.buildUri` — the parser recognizes this shape).
      uri: Uri.parse(data['url'] as String),
      pieceId: pieceId,
      ownerId: ownerId,
    );
  });

  @override
  Future<Result<InviteDetails>> resolveInvite(String token) =>
      _guarded<InviteDetails>(() async {
        final result = await _functions
            .httpsCallable('resolveInviteToken')
            .call<Object?>(<String, dynamic>{'token': token});
        final data = Map<String, dynamic>.from(result.data! as Map);
        return InviteDetails(
          pieceId: data['pieceId'] as String,
          pieceTitle: data['pieceTitle'] as String,
          ownerId: (data['ownerId'] as String?) ?? '',
          ownerName: data['ownerName'] as String?,
        );
      });

  @override
  Future<Result<void>> acceptInvite(
    String token, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
  }) => _guarded<void>(() async {
    // [collaboratorId] is implied by the caller's auth token server-side;
    // name/email ride along for the piece's `collaborators` entry.
    await _functions.httpsCallable('acceptInviteToken').call<Object?>(
      <String, dynamic>{
        'token': token,
        'accepterName': collaboratorName,
        'accepterEmail': collaboratorEmail,
      },
    );
  });

  /// Runs [action], translating a callable's typed denial
  /// (`FirebaseFunctionsException.details.reason`) into the
  /// [InviteException] the contract promises — same copy the mock path
  /// throws, plus the machine-readable [InviteFailureReason].
  Future<Result<T>> _guarded<T>(Future<T> Function() action) =>
      Result.guard<T>(() async {
        try {
          return await action();
        } on FirebaseFunctionsException catch (e) {
          throw _asInviteException(e);
        }
      });

  static InviteException _asInviteException(FirebaseFunctionsException e) {
    final details = e.details;
    final reason = switch (details is Map ? details['reason'] : null) {
      'invalid' => InviteFailureReason.invalid,
      'expired' => InviteFailureReason.expired,
      'consumed' => InviteFailureReason.consumed,
      'at-cap' => InviteFailureReason.atCap,
      'already-collaborator' => InviteFailureReason.alreadyCollaborator,
      _ => InviteFailureReason.generic,
    };
    // The server's message is already the user-facing copy (kept in sync
    // with the mock path's strings); fall back to a generic line for
    // transport-level failures that carry none.
    final message = e.message ?? 'Something went wrong. Please try again.';
    return InviteException(message, reason: reason);
  }
}
