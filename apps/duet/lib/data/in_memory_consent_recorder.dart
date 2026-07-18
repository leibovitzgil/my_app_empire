import 'package:core_utils/core_utils.dart';
import 'package:duet/data/consent_recorder.dart';

/// In-memory [ConsentRecorder] for the headless gate and local/mock runs
/// (G2): keeps each acceptance in a list instead of writing Firestore, so
/// nothing here constructs a Firebase object.
///
/// The most-recent acceptance wins per user (a later re-acceptance overwrites
/// the earlier record for that uid). Exposed [records] lets tests assert what
/// was recorded.
class InMemoryConsentRecorder implements ConsentRecorder {
  final Map<String, ConsentRecord> _byUser = <String, ConsentRecord>{};

  /// Every recorded acceptance, most-recent-per-user, in insertion order.
  List<ConsentRecord> get records => List<ConsentRecord>.unmodifiable(
    _byUser.values,
  );

  @override
  Future<Result<void>> recordAcceptance({
    required String userId,
    required String documentVersion,
  }) async {
    _byUser[userId] = ConsentRecord(
      userId: userId,
      documentVersion: documentVersion,
      acceptedAt: DateTime.now().toUtc(),
    );
    return const Success<void>(null);
  }
}
