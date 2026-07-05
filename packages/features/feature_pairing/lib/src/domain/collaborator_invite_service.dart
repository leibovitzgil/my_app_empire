import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';

/// A directory-resolved recipient a collaborator invite can be sent to.
class InviteRecipient extends Equatable {
  /// Creates an [InviteRecipient].
  const InviteRecipient({
    required this.uid,
    required this.email,
    this.displayName,
  });

  /// The recipient's account id.
  final String uid;

  /// The email the recipient was resolved by.
  final String email;

  /// The recipient's display name, if known.
  final String? displayName;

  @override
  List<Object?> get props => [uid, email, displayName];
}

/// A pending collaborator invite, decoded from the generic
/// `UserMessageGateway` inbox for the accepting device's own current user.
class InviteMessage extends Equatable {
  /// Creates an [InviteMessage].
  const InviteMessage({
    required this.messageId,
    required this.pieceId,
    required this.ownerId,
    this.ownerName,
  });

  /// The id of the underlying `UserMessage`, needed to mark it read once
  /// acted on.
  final String messageId;

  /// The piece this invite grants access to.
  final String pieceId;

  /// The inviting owner's id.
  final String ownerId;

  /// The inviting owner's display name, if known at send time.
  final String? ownerName;

  @override
  List<Object?> get props => [messageId, pieceId, ownerId, ownerName];
}

/// The result of resolving what would happen if a given email were invited
/// to a given piece — shared between the preview-only
/// [CollaboratorInviteService.lookupInvitee] and the side-effecting
/// [CollaboratorInviteService.sendInvite], so both agree on exactly one
/// outcome for exactly one set of checks.
sealed class LookupOutcome extends Equatable {
  const LookupOutcome();

  @override
  List<Object?> get props => [];
}

/// The email resolves to a discoverable, not-yet-a-collaborator,
/// under-cap [recipient] — inviting (or accepting) may proceed.
final class Resolved extends LookupOutcome {
  /// Creates a [Resolved] outcome for [recipient].
  const Resolved(this.recipient);

  /// The resolved recipient.
  final InviteRecipient recipient;

  @override
  List<Object?> get props => [recipient];
}

/// No discoverable account resolves to that email — the caller should fall
/// back to the deep-link invite path.
final class NoAccount extends LookupOutcome {
  /// Creates a [NoAccount] outcome.
  const NoAccount();
}

/// The resolved recipient is already a collaborator on this piece.
final class AlreadyCollaborator extends LookupOutcome {
  /// Creates an [AlreadyCollaborator] outcome.
  const AlreadyCollaborator();
}

/// The piece is already at its collaborator cap for the owner's current
/// monetization tier (see `CollaboratorLimits`).
final class AtCap extends LookupOutcome {
  /// Creates an [AtCap] outcome.
  const AtCap();
}

/// Thrown (surfaced via a `Result` failure) by [CollaboratorInviteService]
/// when [CollaboratorInviteService.acceptInvite] can't complete, with a
/// user-facing [message].
sealed class CollaboratorInviteException implements Exception {
  const CollaboratorInviteException(this.message);

  /// The message shown to the user.
  final String message;

  @override
  String toString() => 'CollaboratorInviteException: $message';
}

/// The accepting piece is already at its collaborator cap for the owner's
/// current monetization tier — thrown by
/// [CollaboratorInviteService.acceptInvite]'s re-check, closing the race
/// where the cap fills between send and accept.
final class AtCapInviteException extends CollaboratorInviteException {
  /// Creates an [AtCapInviteException].
  const AtCapInviteException()
    : super('Free plan allows 1 collaborator. Upgrade to invite more.');
}

/// Contract for the email-based (primary) collaborator invite path: resolve
/// an email to an account, send that account an invite message, and accept
/// a received invite — all composed over `UserDirectory`, `PieceRepository`,
/// `MonetizationService` and `UserMessageGateway`.
///
/// The tokenized deep-link invite (`DeepLinkInviteService`) remains the
/// secondary/fallback path for an email with no discoverable account; both
/// paths converge on `PieceRepository.addCollaborator` and share exactly one
/// cap predicate (`CollaboratorLimits`).
abstract class CollaboratorInviteService {
  /// Resolves what would happen if [email] were invited to [pieceId], without
  /// sending anything — used by the invite sheet to show a live preview
  /// (found/no-account/already-collaborator/paywall) as the owner types.
  Future<Result<LookupOutcome>> lookupInvitee({
    required String pieceId,
    required String email,
  });

  /// Re-runs the same checks as [lookupInvitee] and, only if they resolve to
  /// [Resolved], sends an invite message to that recipient's inbox. Any
  /// other outcome sends nothing — this re-check closes the race where
  /// state changed between preview and send (e.g. a concurrently-accepted
  /// sibling invite filling the cap).
  Future<Result<LookupOutcome>> sendInvite({
    required String pieceId,
    required String ownerId,
    required String email,
    String? ownerName,
  });

  /// Streams the pending invites addressed to [uid] (this device's current
  /// user).
  Stream<List<InviteMessage>> watchInvites(String uid);

  /// Accepts [invite] on behalf of [accepterId], re-checking the
  /// collaborator cap before completing via
  /// `PieceRepository.addCollaborator`. Fails with an
  /// [AtCapInviteException] if the cap fills before this call lands.
  Future<Result<void>> acceptInvite(
    InviteMessage invite, {
    required String accepterId,
    String? accepterName,
    String? accepterEmail,
  });
}
