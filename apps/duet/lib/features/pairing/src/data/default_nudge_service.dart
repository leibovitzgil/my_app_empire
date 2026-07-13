import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/pairing/src/domain/nudge_service.dart';
import 'package:notifications/notifications.dart';

/// The default [NudgeService]: resolves the piece's participants via
/// [PieceRepository] and sends a nudge [UserMessage] to each *other*
/// participant through [UserMessageGateway] — the same generic inbox invites
/// ride over.
///
/// Backend-agnostic: the headless gate exercises this against the in-memory
/// gateway, so a nudge lands on the recipient's inbox stream in-process. Under
/// Firebase the send is routed through the `sendNudge` callable
/// (`CallableNudgeService`) because clients can't write `userInbox` directly
/// (M2.4 rules), but the participant resolution + payload shape stay identical.
class DefaultNudgeService implements NudgeService {
  /// Creates a [DefaultNudgeService].
  DefaultNudgeService({
    required PieceRepository pieceRepository,
    required UserMessageGateway messageGateway,
    required String Function() currentUserId,
    String Function()? messageIdGenerator,
    DateTime Function()? clock,
  }) : _pieceRepository = pieceRepository,
       _messageGateway = messageGateway,
       _currentUserId = currentUserId,
       _messageIdGenerator = messageIdGenerator ?? _defaultMessageId,
       _now = clock ?? DateTime.now;

  /// The `UserMessage.data['type']` marking a nudge, so a recipient can pick
  /// nudges out of an otherwise-generic inbox (tap-through routing, M5.5).
  static const String nudgeMessageType = 'nudge';

  final PieceRepository _pieceRepository;
  final UserMessageGateway _messageGateway;
  final String Function() _currentUserId;
  final String Function() _messageIdGenerator;
  final DateTime Function() _now;

  static int _messageSeq = 0;
  static String _defaultMessageId() =>
      'nudge_${DateTime.now().microsecondsSinceEpoch}_${_messageSeq++}';

  @override
  Future<Result<void>> nudge({
    required String pieceId,
    required String fromName,
  }) => Result.guard<void>(() async {
    final piece = (await _pieceRepository.getPiece(pieceId)).orThrow();
    final me = _currentUserId();
    for (final uid in piece.participantIds.where((id) => id != me)) {
      (await _messageGateway.sendToUser(
        UserMessage(
          id: _messageIdGenerator(),
          toUid: uid,
          title: '$fromName added notes',
          body: 'Open the sheet to see what changed.',
          sentAt: _now(),
          data: {
            'type': nudgeMessageType,
            'pieceId': pieceId,
            'fromName': fromName,
          },
        ),
      )).orThrow();
    }
  });
}
