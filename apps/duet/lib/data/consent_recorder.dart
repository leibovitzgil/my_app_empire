import 'package:core_utils/core_utils.dart';

/// A user's recorded acceptance of the app's legal documents (Terms of
/// Service + Privacy Policy) presented at sign-up.
///
/// The *minimal in-house consent record* the factory defaults to (M7.4): a
/// timestamped acceptance stored with the account — deliberately chosen over a
/// full Consent Management Platform (CMP), since Duet ships no ad/tracking
/// SDKs. Revisit with a real CMP only if that ever changes.
class ConsentRecord {
  /// Creates a [ConsentRecord].
  const ConsentRecord({
    required this.userId,
    required this.documentVersion,
    required this.acceptedAt,
  });

  /// The account that accepted the documents.
  final String userId;

  /// The version of the legal documents the user accepted, so a later policy
  /// change can detect stale consent and re-prompt.
  final String documentVersion;

  /// When the user accepted (UTC).
  final DateTime acceptedAt;

  @override
  String toString() =>
      'ConsentRecord(userId: $userId, documentVersion: $documentVersion, '
      'acceptedAt: $acceptedAt)';
}

/// Records a user's acceptance of the legal documents at sign-up.
///
/// When the user ticks the acceptance box on the sign-up screen, the app
/// persists a timestamped [ConsentRecord] against their account. This is an
/// app-level service seam (like `AccountPurge`): the app picks the
/// implementation at the DI layer — a Firestore-backed one under
/// `useFirebase: true`, an in-memory fake otherwise, which is what keeps the
/// headless gate Firebase-free (G2).
// ignore: one_member_abstracts
abstract class ConsentRecorder {
  /// Records that [userId] accepted the legal documents at version
  /// [documentVersion], stamped with the acceptance time (a trusted server
  /// clock in production). Fire-and-forget at the call site, so failures ride
  /// the [Result] rather than throwing across the seam (G4).
  Future<Result<void>> recordAcceptance({
    required String userId,
    required String documentVersion,
  });
}
