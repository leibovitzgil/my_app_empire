// cloud_functions exports its own (unrelated) `Result`; ours is core_utils'.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:core_utils/core_utils.dart';
import 'package:duet/features/pairing/pairing.dart';

/// A [NudgeService] that routes the send through the `sendNudge` Cloud Function
/// (task M4.2) — the server-authoritative path, since under the M2.2 rules a
/// client can't create `userInbox` documents. The callable verifies the caller
/// is a participant on the piece and fans the nudge out to the others.
///
/// `fromName` is resolved server-side from the caller's ID token, so the
/// client argument is ignored here — it's kept only to satisfy the shared
/// [NudgeService] contract that the default in-memory impl also implements.
class CallableNudgeService implements NudgeService {
  /// Creates a [CallableNudgeService] over the region-pinned [functions]
  /// instance.
  CallableNudgeService({required FirebaseFunctions functions})
    : _functions = functions;

  final FirebaseFunctions _functions;

  @override
  Future<Result<void>> nudge({
    required String pieceId,
    required String fromName,
  }) => Result.guard<void>(() async {
    await _functions.httpsCallable('sendNudge').call<Object?>(
      <String, dynamic>{'pieceId': pieceId},
    );
  });
}
