import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/src/domain/collaborator_invite_service.dart';
import 'package:monetization/monetization.dart';
import 'package:notifications/notifications.dart';
import 'package:user_directory/user_directory.dart';

/// The primary (email-based) [CollaboratorInviteService], composing
/// [UserDirectory] (email -> account resolution), [PieceRepository] (cap +
/// mutation), [MonetizationService] (tier) and [UserMessageGateway]
/// (delivery) — none of which know about each other or about "invites" as a
/// concept.
class DefaultCollaboratorInviteService implements CollaboratorInviteService {
  /// Creates a [DefaultCollaboratorInviteService].
  DefaultCollaboratorInviteService({
    required UserDirectory userDirectory,
    required PieceRepository pieceRepository,
    required MonetizationService monetizationService,
    required UserMessageGateway messageGateway,
    String Function()? messageIdGenerator,
    DateTime Function()? clock,
  }) : _userDirectory = userDirectory,
       _pieceRepository = pieceRepository,
       _monetization = monetizationService,
       _messageGateway = messageGateway,
       _messageIdGenerator = messageIdGenerator ?? _defaultMessageId,
       _now = clock ?? DateTime.now;

  /// The `UserMessage.data['type']` marking an invite message, so
  /// [watchInvites] can pick invites out of an otherwise-generic inbox.
  static const String inviteMessageType = 'invite';

  final UserDirectory _userDirectory;
  final PieceRepository _pieceRepository;
  final MonetizationService _monetization;
  final UserMessageGateway _messageGateway;
  final String Function() _messageIdGenerator;
  final DateTime Function() _now;

  static int _messageSeq = 0;
  static String _defaultMessageId() =>
      'invite_${DateTime.now().microsecondsSinceEpoch}_${_messageSeq++}';

  Future<LookupOutcome> _resolve({
    required String pieceId,
    required String email,
  }) async {
    final directoryUser = (await _userDirectory.lookupByEmail(
      email,
    )).orThrow();
    if (directoryUser == null) return const NoAccount();

    final piece = (await _pieceRepository.getPiece(pieceId)).orThrow();
    if (piece.isCollaborator(directoryUser.uid)) {
      return const AlreadyCollaborator();
    }

    final isPro = await _monetization.isProUser();
    if (CollaboratorLimits.isAtCap(piece, isPro)) {
      return const AtCap();
    }

    return Resolved(
      InviteRecipient(
        uid: directoryUser.uid,
        email: directoryUser.email,
        displayName: directoryUser.displayName,
      ),
    );
  }

  @override
  Future<Result<LookupOutcome>> lookupInvitee({
    required String pieceId,
    required String email,
  }) => Result.guard<LookupOutcome>(
    () => _resolve(pieceId: pieceId, email: email),
  );

  @override
  Future<Result<LookupOutcome>> sendInvite({
    required String pieceId,
    required String ownerId,
    required String email,
    String? ownerName,
  }) => Result.guard<LookupOutcome>(() async {
    final outcome = await _resolve(pieceId: pieceId, email: email);
    if (outcome is! Resolved) return outcome;

    (await _messageGateway.sendToUser(
      UserMessage(
        id: _messageIdGenerator(),
        toUid: outcome.recipient.uid,
        title: '${ownerName ?? 'Someone'} invited you to collaborate',
        body: 'Join a shared piece on Duet.',
        sentAt: _now(),
        // Surfacing an invite must not consume it: it stays pending until
        // `acceptInvite`, which refuses an already-read message.
        requiresAction: true,
        data: {
          'type': inviteMessageType,
          'pieceId': pieceId,
          'ownerId': ownerId,
          'ownerName': ?ownerName,
        },
      ),
    )).orThrow();
    return outcome;
  });

  @override
  Stream<List<InviteMessage>> watchInvites(String uid) {
    return _messageGateway
        .inboxFor(uid)
        .map(
          (messages) => [
            for (final message in messages)
              // Skip malformed invites (missing pieceId/ownerId) rather than
              // throwing inside `map`, which would tear down the subscription.
              if (message.data['type'] == inviteMessageType)
                if (message.data['pieceId'] case final pieceId?)
                  if (message.data['ownerId'] case final ownerId?)
                    InviteMessage(
                      messageId: message.id,
                      pieceId: pieceId,
                      ownerId: ownerId,
                      ownerName: message.data['ownerName'],
                    ),
          ],
        );
  }

  @override
  Future<Result<void>> acceptInvite(
    InviteMessage invite, {
    required String accepterId,
    String? accepterName,
    String? accepterEmail,
  }) => Result.guard<void>(() async {
    final piece = (await _pieceRepository.getPiece(invite.pieceId)).orThrow();
    final isPro = await _monetization.isProUser();
    if (!piece.isCollaborator(accepterId) &&
        CollaboratorLimits.isAtCap(piece, isPro)) {
      throw const AtCapInviteException();
    }
    (await _pieceRepository.addCollaborator(
      invite.pieceId,
      userId: accepterId,
      name: accepterName,
      email: accepterEmail,
    )).orThrow();
    // Accepting is the action that consumes a `requiresAction` invite: mark
    // the message read so it leaves every `watchInvites` snapshot —
    // mirroring the server-side `acceptInvite` callable, which marks its
    // inbox document read as part of the acceptance. (If this markRead
    // fails after the collaborator landed, a retried accept short-circuits
    // the cap check via `isCollaborator` and simply retries the consume.)
    (await _messageGateway.markRead(accepterId, invite.messageId)).orThrow();
  });
}
