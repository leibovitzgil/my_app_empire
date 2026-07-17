import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';

/// A shareable invite created by [InviteService.createInvite].
class InviteLink extends Equatable {
  /// Creates an [InviteLink].
  const InviteLink({
    required this.token,
    required this.uri,
    required this.pieceId,
    required this.ownerId,
  });

  /// The opaque, unguessable token identifying this invite.
  final String token;

  /// The shareable URI — copy/paste or `share_plus`'d to the collaborator,
  /// and later opened as a deep link on their device. See `InviteDeepLinks`
  /// for the format this encodes and how the app-glue layer's deep link
  /// parser recognizes it.
  final Uri uri;

  /// The piece this invite grants access to.
  final String pieceId;

  /// The inviting owner's id.
  final String ownerId;

  @override
  List<Object?> get props => [token, uri, pieceId, ownerId];
}

/// The details shown on the Accept Invite screen before the collaborator
/// commits.
class InviteDetails extends Equatable {
  /// Creates [InviteDetails].
  const InviteDetails({
    required this.pieceId,
    required this.pieceTitle,
    required this.ownerId,
    this.ownerName,
  });

  /// The piece this invite grants access to.
  final String pieceId;

  /// The piece's display title.
  final String pieceTitle;

  /// The inviting owner's id.
  final String ownerId;

  /// The inviting owner's display name, if known — falls back to an
  /// initials-from-id placeholder in the UI when `null`.
  final String? ownerName;

  @override
  List<Object?> get props => [pieceId, pieceTitle, ownerId, ownerName];
}

/// Why an [InviteService] operation was denied — machine-readable alongside
/// [InviteException.message]'s user-facing copy, so `AcceptInviteCubit` can
/// map a denial onto the matching `AcceptInviteStatus` state (M5.2: the
/// cloud path surfaces these as typed error codes from the callables;
/// the mock path throws the same reasons).
enum InviteFailureReason {
  /// The token is unknown (or its piece no longer exists).
  invalid,

  /// The token exists but its expiry has passed.
  expired,

  /// The token was already redeemed (by someone else).
  consumed,

  /// The piece is at its collaborator cap for the owner's tier.
  atCap,

  /// The accepter already has access to the piece.
  alreadyCollaborator,

  /// Anything else (ownership violations, transport failures, ...).
  generic,
}

/// Thrown (surfaced via a `Result` failure) by [InviteService] with a
/// user-facing [message] — e.g. "This invite link is invalid or has
/// expired.", "Free plan allows 1 collaborator." — and a typed [reason].
class InviteException implements Exception {
  /// Creates an [InviteException] with a user-facing [message].
  const InviteException(
    this.message, {
    this.reason = InviteFailureReason.generic,
  });

  /// The message shown to the user.
  final String message;

  /// The machine-readable denial reason (defaults to
  /// [InviteFailureReason.generic]).
  final InviteFailureReason reason;

  @override
  String toString() => 'InviteException: $message';
}

/// Contract for creating and accepting invites that pair a collaborator to
/// an owner's piece.
///
/// This is Duet-specific plumbing the architect's Phase 1 plan didn't yet
/// define — added here, in `feature_pairing`, alongside its first (and so
/// far only) implementation, `DeepLinkInviteService`.
abstract class InviteService {
  /// Creates an invite for a collaborator-to-be to join [pieceId], owned by
  /// [ownerId]. Fails with an [InviteException] if [ownerId] doesn't own
  /// [pieceId], or if the account is at its free-tier collaborator limit
  /// (callers should check the cap *before* even showing the invite sheet —
  /// this is a defense-in-depth backstop, not the primary gate).
  ///
  /// [ownerName] is the inviting owner's display name, captured at
  /// invite-creation time so it can flow through to [InviteDetails] (and,
  /// if the piece doesn't already have one, backfill `Piece.ownerName` on
  /// acceptance) even for a piece imported before that field existed.
  Future<Result<InviteLink>> createInvite({
    required String ownerId,
    required String pieceId,
    String? ownerName,
  });

  /// Resolves [token] to the piece/owner it invites the caller to join,
  /// without consuming it — used by the Accept Invite screen to show the
  /// piece title and owner before the collaborator commits. Fails with an
  /// [InviteException] if [token] is unknown, expired or already consumed.
  ///
  /// Not in the architect's original two-method sketch (`createInvite` /
  /// `acceptInvite`); added because the Accept Invite screen needs to show
  /// invite details *before* the collaborator decides to accept or decline.
  Future<Result<InviteDetails>> resolveInvite(String token);

  /// Accepts the invite identified by [token] on behalf of [collaboratorId],
  /// pairing them to the invite's piece. Fails with an [InviteException] if
  /// [token] is unknown/expired/consumed, or if the piece is already paired
  /// with a different collaborator.
  ///
  /// [collaboratorName]/[collaboratorEmail] are the accepting collaborator's
  /// own display name/email, sourced from the accepting device's
  /// current-user identity.
  Future<Result<void>> acceptInvite(
    String token, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
  });
}
