import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:notifications/notifications.dart';

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
      notificationsManager = NotificationsManager(mockFirebaseMessaging, mockSharedPreferences);
      mockSettings = MockNotificationSettings();
    });

    test('requestPermission returns true if already authorized', () async {
      when(mockSettings.authorizationStatus).thenReturn(AuthorizationStatus.authorized);
      when(mockFirebaseMessaging.getNotificationSettings()).thenAnswer((_) async => mockSettings);

      final result = await notificationsManager.requestPermission();
      expect(result, isTrue);
      verifyNever(mockFirebaseMessaging.requestPermission(
          alert: anyNamed('alert'),
          badge: anyNamed('badge'),
          sound: anyNamed('sound')));
    });

    test('requestPermission returns false if already denied', () async {
      when(mockSettings.authorizationStatus).thenReturn(AuthorizationStatus.denied);
      when(mockFirebaseMessaging.getNotificationSettings()).thenAnswer((_) async => mockSettings);

      final result = await notificationsManager.requestPermission();
      expect(result, isFalse);
    });
  });
}
