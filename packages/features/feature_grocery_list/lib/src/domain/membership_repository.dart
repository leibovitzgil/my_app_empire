import 'package:core_utils/core_utils.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';

/// Thrown by [MembershipRepository] mutations to carry a user-facing [message]
/// (surfaced as a snackbar). Lets the bloc show "Enter a valid email" or "The
/// owner can't be removed" instead of a generic failure string.
class MembershipException implements Exception {
  /// Creates a [MembershipException] with a user-facing [message].
  const MembershipException(this.message);

  /// The message shown to the user.
  final String message;

  @override
  String toString() => 'MembershipException: $message';
}

/// Contract for who can collaborate on a shared list — the sharing seam. Kept
/// separate from `GroceryRepository` (exactly like `PresenceRepository`) so the
/// member roster and its sheet rebuild independently of item/stream churn. One
/// in-memory class implements all three contracts today; a Firestore impl backs
/// the real app, swapped at the DI layer with no UI/bloc changes.
abstract class MembershipRepository {
  /// Emits the current member roster on subscribe, then on every change (an
  /// invite, an acceptance, a removal) from this device or any collaborator.
  Stream<List<ListMember>> watchMembers();

  /// Invites a person to the list by [email], creating a pending member.
  /// Idempotent: re-inviting someone already on the list is a no-op that
  /// returns the existing member. Fails with a [MembershipException] when the
  /// email is invalid.
  Future<Result<ListMember>> inviteByEmail(
    String email, {
    MemberRole role = MemberRole.editor,
  });

  /// Removes the member with [collaboratorId]. The owner cannot be removed
  /// (fails with a [MembershipException]); removing someone absent is a no-op.
  Future<Result<void>> removeMember(String collaboratorId);

  /// A shareable link that lets someone join this list.
  String inviteLink();
}
