import 'package:core_utils/core_utils.dart';

/// The server-side account-purge seam (task M1.9).
///
/// Deleting an account is server-authoritative: the backend purges
/// everything the uid owns (directory entries, device tokens, inbox) and
/// then deletes the identity itself — see `functions/src/deleteAccount.ts`
/// (task M1.8). This contract is what the Settings flow calls; the app
/// picks the implementation at the DI layer (`CallableAccountPurge` under
/// `useFirebase: true`, [MockAccountPurge] otherwise), which is what lets
/// the headless flow tests drive the full UI sequence without Cloud
/// Functions (G2). A single-method contract (rather than a bare function
/// type) so it registers in get_it like every other swappable seam and a
/// recording fake can track call state — `LocalNotificationPort`'s
/// reasoning.
// ignore: one_member_abstracts
abstract class AccountPurge {
  /// Deletes the signed-in account server-side.
  ///
  /// Fails with an `AuthFailure` carried in the `ResultFailure`:
  /// `requiresRecentLogin` when the backend demands a fresher credential
  /// (re-authenticate and retry), `network` for connectivity problems.
  /// After a `Success` the server-side identity no longer exists — the
  /// caller still owns local cleanup (cache wipe + sign-out).
  Future<Result<void>> deleteAccount();
}

/// The default (no-Firebase) [AccountPurge]: succeeds after a short delay.
///
/// The mock identity (`MockAuthRepository`) has no server state to purge —
/// its directory entry lives in the in-memory `UserDirectory`, which dies
/// with the process — so simulated success is the honest behavior.
class MockAccountPurge implements AccountPurge {
  @override
  Future<Result<void>> deleteAccount() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const Success(null);
  }
}
