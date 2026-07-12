// cloud_functions exports its own (unrelated) `Result`; ours is core_utils'.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:core_utils/core_utils.dart';
import 'package:duet/features/pairing/pairing.dart';

/// A [CollaboratorInviteService] that routes the two operations which must be
/// server-authoritative — sending an invite (writing the recipient's inbox)
/// and consuming an accepted one — through Cloud Functions (task M2.4), while
/// delegating everything else to a local [CollaboratorInviteService].
///
/// Under the M2.2 rules a client can no longer create `userInbox` documents,
/// so the direct-gateway send of [DefaultCollaboratorInviteService] would be
/// denied; the `sendInvite` callable (Admin SDK) is the only writer. The
/// preview ([lookupInvitee]), the inbox stream ([watchInvites], a recipient
/// read the rules still allow), and — pre-M3, while pieces are on-device — the
/// accept's piece mutation all stay client-side via [_local].
class CallableCollaboratorInviteService implements CollaboratorInviteService {
  /// Creates a [CallableCollaboratorInviteService] over [local] (the
  /// backend-agnostic logic) and the region-pinned [functions] instance.
  CallableCollaboratorInviteService({
    required CollaboratorInviteService local,
    required FirebaseFunctions functions,
  }) : _local = local,
       _functions = functions;

  final CollaboratorInviteService _local;
  final FirebaseFunctions _functions;

  @override
  Future<Result<LookupOutcome>> lookupInvitee({
    required String pieceId,
    required String email,
  }) => _local.lookupInvitee(pieceId: pieceId, email: email);

  @override
  Stream<List<InviteMessage>> watchInvites(String uid) =>
      _local.watchInvites(uid);

  @override
  Future<Result<LookupOutcome>> sendInvite({
    required String pieceId,
    required String ownerId,
    required String email,
    String? ownerName,
  }) => Result.guard<LookupOutcome>(() async {
    final result = await _functions.httpsCallable('sendInvite').call<Object?>(
      <String, dynamic>{'pieceId': pieceId, 'inviteeEmail': email},
    );
    final data = Map<String, dynamic>.from(result.data! as Map);
    switch (data['status']) {
      case 'sent':
        return Resolved(
          InviteRecipient(
            uid: data['recipientUid'] as String,
            email: data['recipientEmail'] as String,
            displayName: data['recipientDisplayName'] as String?,
          ),
        );
      case 'no-account':
        return const NoAccount();
      case final status:
        throw StateError('Unexpected sendInvite status: $status');
    }
  });

  @override
  Future<Result<void>> acceptInvite(
    InviteMessage invite, {
    required String accepterId,
    String? accepterName,
    String? accepterEmail,
  }) => Result.guard<void>(() async {
    // Re-check the cap and add the collaborator to the on-device piece first
    // (pre-M3 the piece lives locally); this throws `AtCapInviteException` if
    // the cap filled between send and accept.
    (await _local.acceptInvite(
      invite,
      accepterId: accepterId,
      accepterName: accepterName,
      accepterEmail: accepterEmail,
    )).orThrow();
    // Then consume the inbox message server-side (marks it read), so it can't
    // be replayed and — post-M3 — the participant mutation lands there.
    await _functions.httpsCallable('acceptInvite').call<Object?>(
      <String, dynamic>{'messageId': invite.messageId},
    );
  });
}
