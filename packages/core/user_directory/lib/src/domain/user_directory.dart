import 'package:core_utils/core_utils.dart';
import 'package:user_directory/src/domain/directory_user.dart';

/// Contract for looking up a discoverable account by email and publishing
/// the current user's own directory entry, so a collaborator invite can
/// resolve "does this email have an account" without either side needing to
/// already know the other's uid.
abstract class UserDirectory {
  /// Looks up the discoverable [DirectoryUser] registered under [email].
  ///
  /// `Success(null)` means no *discoverable* account resolves to [email] —
  /// this covers both "no account at all" and "an account exists but opted
  /// out of discovery" identically, by design (see
  /// [DirectoryUser.discoverable]).
  Future<Result<DirectoryUser?>> lookupByEmail(String email);

  /// Publishes/updates [user]'s own directory entry (typically called on
  /// sign-in, keyed by the caller's own email/uid).
  Future<Result<void>> upsertSelf(DirectoryUser user);
}
