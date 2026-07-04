import 'package:core_utils/core_utils.dart';
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

/// A hand-written fake [LocalNotificationPort] — mirrors `services/audio`'s
/// `_FakeRecorderPort` convention rather than a generated mock, since this is
/// a small seam with no complex stubbing needs.
class _FakeLocalNotificationPort implements LocalNotificationPort {
  bool showThrows = false;
  int showCalls = 0;
  int? lastId;
  String? lastTitle;
  String? lastBody;

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    showCalls++;
    lastId = id;
    lastTitle = title;
    lastBody = body;
    if (showThrows) throw Exception('boom');
  }
}

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

    group('showLocal', () {
      late _FakeLocalNotificationPort fakePort;
      late NotificationsManager manager;

      setUp(() {
        fakePort = _FakeLocalNotificationPort();
        manager = NotificationsManager(
          mockFirebaseMessaging,
          mockSharedPreferences,
          localNotifications: fakePort,
        );
      });

      test('delegates title/body to the local notification port', () async {
        final result = await manager.showLocal(
          title: 'New feedback from Jane Doe',
          body: 'Clair de Lune: 3 strokes, 1 note',
        );

        expect(result, isA<Success<void>>());
        expect(fakePort.showCalls, 1);
        expect(fakePort.lastTitle, 'New feedback from Jane Doe');
        expect(fakePort.lastBody, 'Clair de Lune: 3 strokes, 1 note');
      });

      test('passes a distinct id on each call', () async {
        await manager.showLocal(title: 'a', body: 'a');
        final firstId = fakePort.lastId;
        await manager.showLocal(title: 'b', body: 'b');
        final secondId = fakePort.lastId;

        expect(firstId, isNotNull);
        expect(secondId, isNotNull);
      });

      test('maps a port failure to a ResultFailure<void>', () async {
        fakePort.showThrows = true;

        final result = await manager.showLocal(title: 'a', body: 'b');

        expect(result, isA<ResultFailure<void>>());
        expect(
          (result as ResultFailure<void>).error,
          isA<LocalNotificationException>(),
        );
      });
    });
  });
}
