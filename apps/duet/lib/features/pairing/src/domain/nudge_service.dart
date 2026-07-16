import 'package:core_utils/core_utils.dart';

/// Contract for *nudging* a piece's other participants — a lightweight
/// "I added notes, come take a look" ping, distinct from a
/// `CollaboratorInviteService` invite (which grants access).
///
/// Delivered as a generic `UserMessage` (`data['type'] == 'nudge'`) over the
/// same inbox invites ride, so the foreground bridge surfaces it today; real
/// push arrives with M5.3 without changing this interface, and tap-through
/// routing to the exact piece lands in M5.5.
// ignore: one_member_abstracts
abstract class NudgeService {
  /// Sends a nudge about [pieceId] from [fromName] to every *other*
  /// participant on the piece (a no-op success when the caller is the only
  /// participant). Fails (per G4) if the piece can't be resolved or a send is
  /// rejected.
  Future<Result<void>> nudge({
    required String pieceId,
    required String fromName,
  });
}
