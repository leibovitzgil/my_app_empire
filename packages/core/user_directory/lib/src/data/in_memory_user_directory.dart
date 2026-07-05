import 'package:core_utils/core_utils.dart';
import 'package:user_directory/src/domain/directory_user.dart';
import 'package:user_directory/src/domain/user_directory.dart';

/// A [UserDirectory] backed by an in-memory map, keyed by a
/// lower-cased/trimmed email. The default-gate (headless, no-Firebase) fake:
/// seed it with whichever [DirectoryUser]s a test/app run needs to already
/// be "discoverable".
class InMemoryUserDirectory implements UserDirectory {
  /// Creates an [InMemoryUserDirectory], optionally pre-seeded with
  /// [seed] (a list of already-known [DirectoryUser]s).
  InMemoryUserDirectory({List<DirectoryUser>? seed})
    : _byEmail = {
        for (final user in seed ?? const <DirectoryUser>[])
          _key(user.email): user,
      };

  final Map<String, DirectoryUser> _byEmail;

  static String _key(String email) => email.trim().toLowerCase();

  @override
  Future<Result<DirectoryUser?>> lookupByEmail(String email) =>
      Result.guard(() async {
        final user = _byEmail[_key(email)];
        if (user == null || !user.discoverable) return null;
        return user;
      });

  @override
  Future<Result<void>> upsertSelf(DirectoryUser user) => Result.guard(() async {
    _byEmail[_key(user.email)] = user;
  });
}
