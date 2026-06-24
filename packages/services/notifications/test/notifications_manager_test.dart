import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:notifications/notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

@GenerateNiceMocks([
  MockSpec<FirebaseMessaging>(),
  MockSpec<SharedPreferences>(),
  MockSpec<NotificationSettings>(),
])
import 'notifications_manager_test.mocks.dart';

void main() {
  group('NotificationsManager', () {
    late MockFirebaseMessaging mockFirebaseMessaging;
    late MockSharedPreferences mockSharedPreferences;
    late NotificationsManager notificationsManager;
    late MockNotificationSettings mockSettings;

    setUp(() {
      mockFirebaseMessaging = MockFirebaseMessaging();
      mockSharedPreferences = MockSharedPreferences();
      notificationsManager = NotificationsManager(
        mockFirebaseMessaging,
        mockSharedPreferences,
      );
      mockSettings = MockNotificationSettings();
    });

    test('requestPermission returns true if already authorized', () async {
      when(
        mockSettings.authorizationStatus,
      ).thenReturn(AuthorizationStatus.authorized);
      when(
        mockFirebaseMessaging.getNotificationSettings(),
      ).thenAnswer((_) async => mockSettings);

      final result = await notificationsManager.requestPermission();
      expect(result, isTrue);
      verifyNever(
        mockFirebaseMessaging.requestPermission(
          alert: anyNamed('alert'),
          badge: anyNamed('badge'),
          sound: anyNamed('sound'),
        ),
      );
    });

    test('requestPermission returns false if already denied', () async {
      when(
        mockSettings.authorizationStatus,
      ).thenReturn(AuthorizationStatus.denied);
      when(
        mockFirebaseMessaging.getNotificationSettings(),
      ).thenAnswer((_) async => mockSettings);

      final result = await notificationsManager.requestPermission();
      expect(result, isFalse);
    });

    group('permissionStatus', () {
      void stubStatus(AuthorizationStatus status) {
        when(mockSettings.authorizationStatus).thenReturn(status);
        when(
          mockFirebaseMessaging.getNotificationSettings(),
        ).thenAnswer((_) async => mockSettings);
      }

      test('maps authorized -> authorized', () async {
        stubStatus(AuthorizationStatus.authorized);
        expect(
          await notificationsManager.permissionStatus(),
          NotificationPermissionStatus.authorized,
        );
      });

      test('maps provisional -> authorized', () async {
        stubStatus(AuthorizationStatus.provisional);
        expect(
          await notificationsManager.permissionStatus(),
          NotificationPermissionStatus.authorized,
        );
      });

      test('maps denied -> denied', () async {
        stubStatus(AuthorizationStatus.denied);
        expect(
          await notificationsManager.permissionStatus(),
          NotificationPermissionStatus.denied,
        );
      });

      test('maps notDetermined -> notDetermined', () async {
        stubStatus(AuthorizationStatus.notDetermined);
        expect(
          await notificationsManager.permissionStatus(),
          NotificationPermissionStatus.notDetermined,
        );
      });

      test('never prompts (no requestPermission call)', () async {
        stubStatus(AuthorizationStatus.notDetermined);
        await notificationsManager.permissionStatus();
        verifyNever(
          mockFirebaseMessaging.requestPermission(
            alert: anyNamed('alert'),
            badge: anyNamed('badge'),
            sound: anyNamed('sound'),
          ),
        );
      });
    });
  });
}
