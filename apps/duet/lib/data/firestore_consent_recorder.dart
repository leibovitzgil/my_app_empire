import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/consent_recorder.dart';

/// Firestore-backed [ConsentRecorder]: writes the user's timestamped
/// acceptance to `consent/{uid}` (one doc per account, overwritten on
/// re-acceptance) with a trusted server timestamp.
///
/// NOT YET BOUND (G6 — rules before client writes): the `consent/{uid}`
/// security rules + rules-tests haven't landed, so `injection.dart` binds the
/// in-memory recorder in both branches for now. This implementation is written
/// and unit-tested against a fake Firestore so flipping it on under
/// `useFirebase` is a one-liner once the rules ship (M7.4 ▸B / Track B) —
/// mirroring the deferred-Firebase precedent already used for remote config,
/// crash reporting, analytics, and perf traces.
class FirestoreConsentRecorder implements ConsentRecorder {
  /// Creates a [FirestoreConsentRecorder] over [firestore].
  FirestoreConsentRecorder({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  @override
  Future<Result<void>> recordAcceptance({
    required String userId,
    required String documentVersion,
  }) {
    return Result.guard<void>(() async {
      await _firestore.collection('consent').doc(userId).set(<String, Object>{
        'documentVersion': documentVersion,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}
