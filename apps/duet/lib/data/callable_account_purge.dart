// cloud_functions exports its own (unrelated) `Result`; ours is core_utils'.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/account_purge.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/foundation.dart';

/// The region Duet's Cloud Functions deploy to.
///
/// Must match `functions/src/region.ts` (and `apps/duet/dev.sh`'s `REGION`)
/// — callables are addressed per-region, so a mismatch here means every
/// call 404s. TODO(M0.H): replace with the recorded production region,
/// together with those two.
const String duetFunctionsRegion = 'europe-west1';

/// An [AccountPurge] backed by the `deleteAccount` callable (task M1.8).
///
/// The callable authenticates via the Firebase SDK's own ID token and
/// requires it to be *recent* (`auth_time` within 5 minutes), so callers
/// re-authenticate first — see `DuetSettingsPage`'s deletion flow.
class CallableAccountPurge implements AccountPurge {
  /// Creates a [CallableAccountPurge] over [functions] — pass the
  /// region-pinned instance (`FirebaseFunctions.instanceFor(region:
  /// duetFunctionsRegion)`).
  CallableAccountPurge({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  Future<Result<void>> deleteAccount() async {
    try {
      await _functions.httpsCallable('deleteAccount').call<Object?>();
      return const Success(null);
    } on Exception catch (e) {
      return ResultFailure<void>(mapCallableError(e));
    }
  }
}

/// Maps a `deleteAccount` callable [error] onto the shared `AuthFailure`
/// taxonomy, mirroring `feature_auth`'s repository-boundary mapping.
///
/// `failed-precondition` is the function's stale-sign-in rejection;
/// `unauthenticated` (a missing/expired ID token) heals the same way, so
/// both map to [AuthFailure.requiresRecentLogin] and land in the flow's
/// re-authenticate-and-retry loop.
@visibleForTesting
AuthFailure mapCallableError(Object error) {
  if (error is! FirebaseFunctionsException) {
    return AuthFailure.unknown(error);
  }
  return switch (error.code) {
    'failed-precondition' ||
    'unauthenticated' => const AuthFailure.requiresRecentLogin(),
    'unavailable' || 'deadline-exceeded' => const AuthFailure.network(),
    _ => AuthFailure.unknown(error),
  };
}
