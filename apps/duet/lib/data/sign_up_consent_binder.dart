import 'dart:async';

import 'package:duet/data/consent_recorder.dart';
import 'package:feature_auth/feature_auth.dart';

/// App glue that turns the sign-up screen's consent tick into a stored
/// [ConsentRecord] once the new account exists.
///
/// The seam is deliberately split across time: at sign-up the acceptance box
/// is ticked *before* an account (and therefore a uid) exists, so the UI can
/// only signal intent. This binder holds that intent ([markPending]) and, on
/// the next account to authenticate, records the acceptance against its uid
/// via [ConsentRecorder]. It listens to the same `AuthAccountProvider.account`
/// stream the other eager account-bound singletons do (`DirectoryPublisher`,
/// `CrashReporterUserBinder`), so it must be constructed eagerly — before the
/// user can sign up — to catch that first authenticated emission.
///
/// Only an actual sign-up sets the pending flag, so a returning user signing
/// in (their account already accepted) never re-records. Social sign-in from
/// the sign-in view carries no checkbox and so records nothing here — the
/// gate lives on the email/password sign-up view (M7.4 scope).
class SignUpConsentBinder {
  /// Creates a [SignUpConsentBinder], subscribing to [accounts] immediately.
  SignUpConsentBinder({
    required Stream<AuthAccount?> accounts,
    required ConsentRecorder recorder,
  }) : _recorder = recorder {
    _subscription = accounts.listen(_onAccount);
  }

  final ConsentRecorder _recorder;
  late final StreamSubscription<AuthAccount?> _subscription;

  String? _pendingVersion;

  /// Signals that the user ticked the consent box and submitted the sign-up
  /// form for legal documents at [documentVersion]. The acceptance is recorded
  /// against whichever account authenticates next. A command, not a property
  /// mutation — the stored version is internal bookkeeping, so it stays a
  /// method rather than a setter.
  // ignore: use_setters_to_change_properties
  void markPending(String documentVersion) => _pendingVersion = documentVersion;

  void _onAccount(AuthAccount? account) {
    final version = _pendingVersion;
    if (account == null || version == null) return;
    // Consume the intent so a later re-emission of the same account (or a
    // subsequent sign-in) doesn't re-record.
    _pendingVersion = null;
    unawaited(
      _recorder.recordAcceptance(
        userId: account.uid,
        documentVersion: version,
      ),
    );
  }

  /// Cancels the account subscription. Call when the owning scope (e.g. the
  /// app's DI container) is torn down.
  Future<void> dispose() => _subscription.cancel();
}
