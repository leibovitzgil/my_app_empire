import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';

class _FakeDeviceTokenRegistry implements DeviceTokenRegistry {
  final List<(String uid, String token)> registered = [];

  @override
  Future<Result<void>> register(String uid, String token) async {
    registered.add((uid, token));
    return const Success(null);
  }

  @override
  Future<Result<void>> unregister(String uid, String token) async =>
      const Success(null);

  @override
  Future<Result<void>> setPushEnabled(
    String uid, {
    required bool enabled,
  }) async => const Success(null);
}

void main() {
  group('DeviceTokenSync', () {
    late _FakeDeviceTokenRegistry registry;
    late StreamController<String> refreshController;
    late String? currentToken;
    late DeviceTokenSync sync;

    setUp(() {
      registry = _FakeDeviceTokenRegistry();
      refreshController = StreamController<String>.broadcast();
      currentToken = 'token-initial';
      sync = DeviceTokenSync(
        registry: registry,
        currentUserId: () => 'uid-1',
        tokenGetter: () async => currentToken,
        onTokenRefresh: refreshController.stream,
      );
    });

    tearDown(() async {
      await sync.dispose();
      await refreshController.close();
    });

    test(
      'registerCurrent registers the current token for the current user',
      () async {
        final result = await sync.registerCurrent();

        expect(result, isA<Success<void>>());
        expect(registry.registered, [('uid-1', 'token-initial')]);
      },
    );

    test(
      'registerCurrent is a no-op when the token source has none yet',
      () async {
        currentToken = null;

        final result = await sync.registerCurrent();

        expect(result, isA<Success<void>>());
        expect(registry.registered, isEmpty);
      },
    );

    test('a token refresh re-registers under the current user', () async {
      refreshController.add('token-rotated');
      await pumpEventQueue();

      expect(registry.registered, [('uid-1', 'token-rotated')]);
    });

    test('dispose stops reacting to further token refreshes', () async {
      await sync.dispose();

      refreshController.add('token-after-dispose');
      await pumpEventQueue();

      expect(registry.registered, isEmpty);
    });
  });
}
