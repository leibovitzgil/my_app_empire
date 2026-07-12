// cloud_functions exports its own (unrelated) `Result`; ours is core_utils'.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:core_utils/core_utils.dart';
import 'package:user_directory/user_directory.dart';

/// A [UserDirectory] whose email lookup goes through the rate-limited
/// `lookupEmail` Cloud Function (task M2.5), while self-publication stays a
/// direct client write.
///
/// Under the M2.5 rules a client may read only its *own* `usersByEmail`
/// document, so cross-user discovery can no longer be a direct Firestore read
/// — it's this callable, which honors `discoverable` (returning `null` for an
/// absent *and* a non-discoverable account, exactly like
/// `FirestoreUserDirectory.lookupByEmail`) and bounds enumeration per caller.
/// [upsertSelf] is delegated to [_local] (a direct self-doc write the rules
/// still allow).
class CallableUserDirectory implements UserDirectory {
  /// Creates a [CallableUserDirectory] over [local] (the direct-Firestore
  /// directory, used for [upsertSelf]) and the region-pinned [functions].
  CallableUserDirectory({
    required UserDirectory local,
    required FirebaseFunctions functions,
  }) : _local = local,
       _functions = functions;

  final UserDirectory _local;
  final FirebaseFunctions _functions;

  @override
  Future<Result<DirectoryUser?>> lookupByEmail(String email) =>
      Result.guard<DirectoryUser?>(() async {
        final result = await _functions
            .httpsCallable('lookupEmail')
            .call<Object?>(<String, dynamic>{'email': email});
        final data = Map<String, dynamic>.from(result.data! as Map);
        final user = data['user'];
        if (user == null) return null;
        final map = Map<String, dynamic>.from(user as Map);
        return DirectoryUser(
          uid: map['uid'] as String,
          email: map['email'] as String,
          displayName: map['displayName'] as String?,
          discoverable: map['discoverable'] as bool? ?? true,
        );
      });

  @override
  Future<Result<void>> upsertSelf(DirectoryUser user) =>
      _local.upsertSelf(user);
}
