import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:local_storage/local_storage.dart';
import 'package:user_directory/user_directory.dart';

/// Owns this device's `usersByEmail` directory entry: re-publishes it
/// whenever the signed-in identity changes (sign-in, sign-up, display-name
/// edits — the account stream re-emits on each) and whenever the user flips
/// their [discoverable] choice in Settings.
///
/// The choice is persisted locally (`settings.discoverable`) and threaded
/// into every upsert — the write-through source the M1.6 task calls for.
/// Before this existed, the raw upsert listener constructed `DirectoryUser`
/// without the flag, force-resetting `discoverable: true` on every sign-in
/// (the documented clobber bug); centralizing composition here is the fix.
///
/// Constructed eagerly in `injection.dart` (like `CurrentUser`) so the
/// account subscription exists before the user can possibly sign in.
class DirectoryPublisher {
  /// Creates a [DirectoryPublisher], subscribing to [accounts] immediately.
  DirectoryPublisher({
    required UserDirectory directory,
    required LocalStorageService storage,
    required Stream<AuthAccount?> accounts,
  }) : _directory = directory,
       _storage = storage {
    _subscription = accounts.listen((account) {
      _lastAccount = account;
      if (account != null) unawaited(publish());
    });
  }

  static const _discoverableKey = 'settings.discoverable';

  final UserDirectory _directory;
  final LocalStorageService _storage;
  late final StreamSubscription<AuthAccount?> _subscription;
  AuthAccount? _lastAccount;

  /// The user's stored choice; true when they never chose (directory
  /// entries default to discoverable so invite-by-email works out of the
  /// box).
  bool get discoverable => _storage.getBool(_discoverableKey) ?? true;

  /// Persists [value] and immediately re-publishes the directory entry so
  /// the choice takes effect without waiting for the next sign-in.
  Future<Result<void>> setDiscoverable(bool value) async {
    await _storage.setBool(_discoverableKey, value);
    return publish();
  }

  /// Composes the entry from the latest account + stored choice and upserts
  /// it. A no-op `Success` while signed out (or for accounts without an
  /// email, which can't be invited by email anyway).
  Future<Result<void>> publish() async {
    final account = _lastAccount;
    final email = account?.email;
    if (account == null || email == null) return const Success(null);
    return _directory.upsertSelf(
      DirectoryUser(
        uid: account.uid,
        email: email,
        displayName: account.displayName,
        discoverable: discoverable,
      ),
    );
  }

  /// Releases the account subscription.
  Future<void> dispose() => _subscription.cancel();
}
