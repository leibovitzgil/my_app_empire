import 'package:core_utils/core_utils.dart';
import 'package:notifications/src/domain/user_message.dart';

/// Contract for sending a [UserMessage] to a specific user's inbox and
/// streaming/consuming that inbox — the seam a feature (e.g.
/// `feature_pairing`'s collaborator invites) drives without needing to know
/// whether delivery is a real push, a Firestore-inbox bridge, or (in the
/// default/headless gate) purely in-memory.
abstract class UserMessageGateway {
  /// Sends [message] to `message.toUid`'s inbox.
  ///
  /// v1 delivery note: this is a foreground/warm-start-only bridge, not a
  /// background push — see each implementation's doc for detail (the
  /// Firebase emulator used for local development has no FCM sender, and
  /// Cloud Functions don't run headless in this container).
  Future<Result<void>> sendToUser(UserMessage message);

  /// Streams the current *unread* messages addressed to [uid], updating as
  /// new ones arrive or existing ones are marked read via [markRead].
  Stream<List<UserMessage>> inboxFor(String uid);

  /// Marks the message [id] addressed to [uid] as read, removing it from
  /// the live [inboxFor] snapshot. A no-op if [id] is unknown or already
  /// read.
  Future<Result<void>> markRead(String uid, String id);
}
