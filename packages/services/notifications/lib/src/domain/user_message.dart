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
    this.requiresAction = false,
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

  /// Whether the recipient must *act* on this message for it to be consumed,
  /// rather than merely see it.
  ///
  /// Read as "showing this doesn't finish it". A nudge is done the moment
  /// it's surfaced (`false`, the default) — a notification is the whole
  /// point of it. An invite is not: it stays pending until accepted, so a
  /// bridge that surfaces it must leave it unread. Marking such a message
  /// read on display destroys it — `read` means *consumed*, and the accept
  /// path refuses an already-read message.
  final bool requiresAction;

  @override
  List<Object?> get props => [
    id,
    toUid,
    title,
    body,
    data,
    sentAt,
    requiresAction,
  ];
}
