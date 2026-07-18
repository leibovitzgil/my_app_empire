// Covers FIX-7's actual call site: `DuetNotificationPermissionGateway`
// wraps `NotificationsManager` (whose own `requestPermission` only returns a
// bare bool, with no permission-GRANT stream to subscribe to) and must
// invoke `DeviceTokenSync.registerCurrent()` explicitly right after a grant,
// and must NOT do so when permission stays denied. This is the wiring that
// backs AC-13 ("token registered ... at the permission-grant call site") one
// level up from `device_token_sync_test.dart`'s own coverage of
// `DeviceTokenSync` in isolation.
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/duet_notification_permission_gateway.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:notifications/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFirebaseMessaging extends Mock implements FirebaseMessaging {}

class _MockNotificationSettings extends Mock implements NotificationSettings {}

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
  Future<Result<void>> setPushEnabled(String uid,
          {required bool enabled}) async =>
      const Success(null);
}

void main() {
  group('DuetNotificationPermissionGateway', () {
    late _MockFirebaseMessaging firebaseMessaging;
    late _FakeDeviceTokenRegistry registry;
    late DeviceTokenSync deviceTokenSync;
    late DuetNotificationPermissionGateway gateway;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      firebaseMessaging = _MockFirebaseMessaging();
      registry = _FakeDeviceTokenRegistry();
      deviceTokenSync = DeviceTokenSync(
        registry: registry,
        currentUserId: () => 'uid-1',
        tokenGetter: () async => 'tok-1',
        onTokenRefresh: const Stream<String>.empty(),
      );
      final manager = NotificationsManager(
        firebaseMessaging,
        await SharedPreferences.getInstance(),
      );
      gateway = DuetNotificationPermissionGateway(
        manager,
        deviceTokenSync: deviceTokenSync,
      );
    });

    tearDown(() => deviceTokenSync.dispose());

    test(
      'ensurePermission registers the device token once permission is '
      'granted (FIX-7)',
      () async {
        final notDetermined = _MockNotificationSettings();
        when(
          () => notDetermined.authorizationStatus,
        ).thenReturn(AuthorizationStatus.notDetermined);
        final authorized = _MockNotificationSettings();
        when(
          () => authorized.authorizationStatus,
        ).thenReturn(AuthorizationStatus.authorized);

        // `NotificationsManager.requestPermission` reads the status once
        // up front (notDetermined -> proceeds, since no BuildContext is
        // passed so the soft-prompt branch never triggers), asks the OS
        // (granted), then `ensurePermission` re-reads the now-authorized
        // status to report back precisely.
        var readCount = 0;
        when(() => firebaseMessaging.getNotificationSettings()).thenAnswer((
          _,
        ) async {
          readCount++;
          return readCount == 1 ? notDetermined : authorized;
        });
        when(
          () => firebaseMessaging.requestPermission(),
        ).thenAnswer((_) async => authorized);

        final result = await gateway.ensurePermission();

        expect(
          (result as Success<NotificationPermission>).value,
          NotificationPermission.granted,
        );
        expect(registry.registered, [('uid-1', 'tok-1')]);
      },
    );

    test(
      'ensurePermission does NOT register a device token when permission '
      'stays denied',
      () async {
        final denied = _MockNotificationSettings();
        when(
          () => denied.authorizationStatus,
        ).thenReturn(AuthorizationStatus.denied);
        when(
          () => firebaseMessaging.getNotificationSettings(),
        ).thenAnswer((_) async => denied);

        final result = await gateway.ensurePermission();

        expect(
          (result as Success<NotificationPermission>).value,
          NotificationPermission.permanentlyDenied,
        );
        expect(registry.registered, isEmpty);
        verifyNever(() => firebaseMessaging.requestPermission());
      },
    );
  });
}
