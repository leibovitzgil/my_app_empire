import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/src/domain/piece.dart';

/// Contract for listing, importing and managing [Piece]s.
abstract class PieceRepository {
  /// Emits the current user's pieces (as owner or collaborator), most-recently
  /// updated first, updating as they change.
  Stream<List<Piece>> watchPieces();

  /// Fetches a single piece by [pieceId].
  Future<Result<Piece>> getPiece(String pieceId);

  /// Imports a new piece titled [title] from the PDF at [sourcePath], owned
  /// by the current user. [ownerName] is the importing user's display name, if
  /// the caller has one to offer (sourced from auth identity) — nullable since
  /// not every identity source resolves a display name.
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
    String? ownerName,
  });

  /// Renames [pieceId] to [title].
  Future<Result<void>> renamePiece(String pieceId, String title);

  /// Permanently deletes [pieceId]. Owner-only: fails with an
  /// `OwnershipViolation` (see `ownership.dart`) if the caller isn't
  /// [Piece.ownerId].
  Future<Result<void>> deletePiece(String pieceId);

  /// Removes the current user's own [Piece.collaborators] entry (and their
  /// ink layer/audio notes) from [pieceId], without deleting it for anyone
  /// else. A no-op if the caller isn't currently a collaborator. Fails if
  /// the caller is the owner — owners delete the piece instead.
  Future<Result<void>> leavePiece(String pieceId);

  /// Appends [userId] as a collaborator on [pieceId] (with [name]/[email] if
  /// given), completing an invite acceptance. IDEMPOTENT: calling again for
  /// an already-current collaborator updates their [name]/[email] (only
  /// where newly given — never clobbered with a null) rather than
  /// duplicating the entry. Not owner-gated (runs as the invitee) and NOT
  /// cap-gated here — the collaborator cap (see `CollaboratorLimits`) is a
  /// caller-side (invite service) concern, not this repository's.
  Future<Result<void>> addCollaborator(
    String pieceId, {
    required String userId,
    String? name,
    String? email,
  });

  /// Removes [userId] from [pieceId]'s collaborators, dropping their ink
  /// layer/audio notes (via `AnnotationRepository.removeAuthorSlice`).
  /// Owner-only: fails with an `OwnershipViolation` if the caller isn't
  /// [Piece.ownerId]. Idempotent if [userId] isn't currently a collaborator.
  Future<Result<void>> removeCollaborator(String pieceId, String userId);

  /// Attaches [collaboratorId] to [pieceId] as a collaborator, completing an
  /// invite acceptance. A thin, doc-preserving delegate to [addCollaborator]
  /// — see that method for the append/idempotent semantics (multiple
  /// collaborators are supported).
  ///
  /// [collaboratorName]/[collaboratorEmail] are the accepting user's display
  /// name/email, if the caller has one to offer — always applied, since this
  /// call's own subject is the accepting collaborator. [ownerName] is a
  /// *backfill*: it only ever fills in a piece that doesn't already have one
  /// (e.g. one imported before this field existed) and never overwrites an
  /// existing [Piece.ownerName], even if passed a different value.
  ///
  /// Owned by callers in `feature_pairing` — this package only exposes the
  /// mutation itself, mirroring how `AnnotationRepository.replaceAuthorSlice`
  /// exposes a privileged operation for `review_sync` to drive without this
  /// package needing to know about sync or pairing semantics.
  Future<Result<Piece>> pairCollaborator(
    String pieceId, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
    String? ownerName,
  });

  /// Registers a piece received for the first time via a cross-device
  /// transfer (e.g. `review_sync`'s "first share" bundle, which embeds the
  /// base PDF precisely so a receiver who has never seen this piece before
  /// can create it locally), preserving the sender's identity fields
  /// ([pieceId], [ownerId], [collaboratorId]) rather than minting a fresh
  /// [Piece.id] the way [importPiece] does for a user's own local import —
  /// the receiver must end up tracking the exact same piece the sender does.
  ///
  /// [sourcePath] is a local (scratch) copy of the base PDF's bytes; this
  /// repository copies it into its own persistent storage and checksums it,
  /// mirroring [importPiece]. Fails if [pieceId] already exists locally —
  /// callers should check via [getPiece] first and only call this for a
  /// genuinely new piece.
  ///
  /// [ownerName]/[collaboratorName] carry whatever identity the transfer
  /// mechanism knows at this point — typically only [ownerName] (the export's
  /// author/owner side, embedded in the sender's manifest), since
  /// [collaboratorName] is normally already known locally as the receiving
  /// device's own current user. [collaboratorId], if given, maps to a single
  /// collaborator entry.
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String ownerId,
    required String sourcePath,
    String? collaboratorId,
    String? ownerName,
    String? collaboratorName,
  });
}
