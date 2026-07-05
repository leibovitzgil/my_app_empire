import 'package:equatable/equatable.dart';

/// A generic, addressed-to-one-user message delivered via
/// `UserMessageGateway`. Deliberately domain-agnostic: it carries no
/// invite-specific fields — `feature_pairing` (or any other feature that
/// needs to notify a specific user) owns the mapping to/from its own
/// richer message types via [data], keyed by a `type` entry it defines.
class UserMessage extends Equatable {
  /// Creates a [UserMessage].
  const UserMessage({
    required this.id,
    required this.toUid,
    required this.title,
    required this.body,
    required this.sentAt,
    this.data = const <String, String>{},
  });

  /// A stable identifier for this message, unique per recipient inbox.
  final String id;

  /// The uid of the user this message is addressed to.
  final String toUid;

  /// The notification title shown to the recipient.
  final String title;

  /// The notification body shown to the recipient.
  final String body;

  /// Sender-defined payload (e.g. `{'type': 'invite', 'pieceId': '...'}`),
  /// letting a feature encode its own domain data over this generic
  /// envelope without `services/notifications` needing to know about it.
  final Map<String, String> data;

  /// When this message was sent.
  final DateTime sentAt;

  @override
  List<Object?> get props => [id, toUid, title, body, data, sentAt];
}
