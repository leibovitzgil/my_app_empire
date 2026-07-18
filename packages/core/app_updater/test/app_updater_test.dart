import 'package:app_updater/app_updater.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remote_config/remote_config.dart';

/// Builds an [AppUpdateService] over an in-memory remote config seeded with
/// [minVersion]/[storeUrl], reporting [currentVersion] as the running app.
AppUpdateService _service({
  required String minVersion,
  String currentVersion = '1.0.0',
  String storeUrl = '',
}) {
  return AppUpdateService(
    remoteConfig: InMemoryRemoteConfigService(
      overrides: <String, Object>{
        RemoteConfigKeys.minSupportedVersion: minVersion,
        RemoteConfigKeys.storeUrl: storeUrl,
      },
    ),
    currentVersion: () async => currentVersion,
  );
}

void main() {
  group('AppUpdateService', () {
    test('update not required when min version is empty', () async {
      expect(await _service(minVersion: '').isUpdateRequired(), isFalse);
    });

    test(
      'update not required on the committed default (0.0.0 never blocks)',
      () async {
        final service = AppUpdateService(
          remoteConfig: InMemoryRemoteConfigService(),
          currentVersion: () async => '1.0.0',
        );
        expect(await service.isUpdateRequired(), isFalse);
      },
    );

    test('update required when current version < min version', () async {
      expect(await _service(minVersion: '1.0.1').isUpdateRequired(), isTrue);
    });

    test('update not required when current version == min version', () async {
      expect(await _service(minVersion: '1.0.0').isUpdateRequired(), isFalse);
    });

    test('update not required when current version > min version', () async {
      expect(await _service(minVersion: '0.9.9').isUpdateRequired(), isFalse);
    });

    test('handles semantic versioning correctly', () async {
      Future<bool> required(String min) =>
          _service(minVersion: min, currentVersion: '1.2.3').isUpdateRequired();

      expect(await required('1.2.4'), isTrue);
      expect(await required('1.3.0'), isTrue);
      expect(await required('2.0.0'), isTrue);
      expect(await required('1.2.2'), isFalse);
    });

    test(
      'fails open when the current version cannot be determined '
      '(e.g. headless — no platform channel)',
      () async {
        final service = AppUpdateService(
          remoteConfig: InMemoryRemoteConfigService(
            overrides: const <String, Object>{
              RemoteConfigKeys.minSupportedVersion: '99.0.0',
            },
          ),
          currentVersion: () async => throw StateError('no platform'),
        );
        expect(await service.isUpdateRequired(), isFalse);
      },
    );

    test('exposes the configured store url', () {
      final service = _service(
        minVersion: '1.0.0',
        storeUrl: 'https://store.example/app',
      );
      expect(service.getStoreUrl(), 'https://store.example/app');
    });
  });

  group('ForceUpdateWidget', () {
    testWidgets('blocks with the update screen below the minimum', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForceUpdateWidget(
            appUpdateService: _service(
              minVersion: '99.0.0',
              storeUrl: 'https://store.example/app',
            ),
            child: const Text('app content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Update Required'), findsOneWidget);
      expect(find.text('Update Now'), findsOneWidget);
      expect(find.text('app content'), findsNothing);
    });

    testWidgets('renders the child at/above the minimum', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForceUpdateWidget(
            appUpdateService: _service(minVersion: '1.0.0'),
            child: const Text('app content'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('app content'), findsOneWidget);
      expect(find.text('Update Required'), findsNothing);
    });
  });
}
