import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:notifications/src/domain/device_token_registry.dart';
import 'package:notifications/src/domain/user_message.dart';
import 'package:notifications/src/domain/user_message_gateway.dart';

/// A [DeviceTokenRegistry] + [UserMessageGateway] backed by in-memory maps.
/// The default-gate (headless, no-Firebase) fake: bind ONE instance against
/// both contracts (mirroring `apps/tandem`'s shared `InMemoryGroceryRepository`
/// precedent), so an owner's [sendToUser] call is immediately visible on the
/// invitee's [inboxFor] stream within the same process — the trick that lets
/// `duet_flow_test.dart` exercise the full send-to-accept funnel headlessly.
class InMemoryUserMessaging implements DeviceTokenRegistry, UserMessageGateway {
  final Map<String, Set<String>> _tokensByUid = <String, Set<String>>{};
  final Map<String, bool> _pushEnabledByUid = <String, bool>{};
  final Map<String, List<UserMessage>> _inboxByUid =
      <String, List<UserMessage>>{};
  final Map<String, StreamController<List<UserMessage>>> _controllers =
      <String, StreamController<List<UserMessage>>>{};

  StreamController<List<UserMessage>> _controllerFor(String uid) {
    return _controllers.putIfAbsent(
      uid,
      StreamController<List<UserMessage>>.broadcast,
    );
  }

  List<UserMessage> _snapshot(String uid) =>
      List.unmodifiable(_inboxByUid[uid] ?? const <UserMessage>[]);

  void _emit(String uid) {
    final controller = _controllers[uid];
    if (controller != null && !controller.isClosed) {
      controller.add(_snapshot(uid));
    }
  }

  @override
  Future<Result<void>> register(String uid, String token) =>
      Result.guard<void>(() async {
        (_tokensByUid[uid] ??= <String>{}).add(token);
      });

  @override
  Future<Result<void>> unregister(String uid, String token) =>
      Result.guard<void>(() async {
        _tokensByUid[uid]?.remove(token);
      });

  @override
  Future<Result<void>> setPushEnabled(String uid, {required bool enabled}) =>
      Result.guard<void>(() async {
        _pushEnabledByUid[uid] = enabled;
      });

  @override
  Future<Result<void>> sendToUser(UserMessage message) =>
      Result.guard<void>(() async {
        _inboxByUid
            .putIfAbsent(message.toUid, () => <UserMessage>[])
            .add(message);
        _emit(message.toUid);
      });

  @override
  Stream<List<UserMessage>> inboxFor(String uid) async* {
    yield _snapshot(uid);
    yield* _controllerFor(uid).stream;
  }

  @override
  Future<Result<void>> markRead(String uid, String id) =>
      Result.guard<void>(() async {
        final inbox = _inboxByUid[uid];
        if (inbox == null) return;
        final next = inbox.where((message) => message.id != id).toList();
        if (next.length == inbox.length) return;
        _inboxByUid[uid] = next;
        _emit(uid);
      });

  /// The currently-registered tokens for [uid], for tests/debugging.
  Set<String> tokensFor(String uid) =>
      Set.unmodifiable(_tokensByUid[uid] ?? const <String>{});

  /// The last-mirrored push preference for [uid], or `null` if never set —
  /// for tests/debugging (mirrors `deviceTokens/{uid}.pushEnabled`).
  bool? pushEnabledFor(String uid) => _pushEnabledByUid[uid];
}
