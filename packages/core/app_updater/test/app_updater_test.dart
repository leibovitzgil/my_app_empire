import 'package:app_updater/app_updater.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:package_info_plus/package_info_plus.dart';

// Simple Mock/Fake implementation
class FakeFirebaseRemoteConfig extends Fake implements FirebaseRemoteConfig {
  final Map<String, String> _values = {};

  @override
  Future<bool> fetchAndActivate() async {
    return true;
  }

  @override
  String getString(String key) {
    return _values[key] ?? '';
  }

  void setString(String key, String value) {
    _values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppUpdateService', () {
    late FakeFirebaseRemoteConfig mockRemoteConfig;
    late AppUpdateService appUpdateService;

    setUp(() {
      mockRemoteConfig = FakeFirebaseRemoteConfig();
      appUpdateService = AppUpdateService(remoteConfig: mockRemoteConfig);

      // Mock PackageInfo
      PackageInfo.setMockInitialValues(
        appName: 'Test App',
        packageName: 'com.example.test',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
    });

    test('update not required when min version is empty', () async {
      mockRemoteConfig.setString('min_supported_version', '');
      expect(await appUpdateService.isUpdateRequired(), isFalse);
    });

    test('update required when current version < min version', () async {
      mockRemoteConfig.setString('min_supported_version', '1.0.1');
      expect(await appUpdateService.isUpdateRequired(), isTrue);
    });

    test('update not required when current version == min version', () async {
      mockRemoteConfig.setString('min_supported_version', '1.0.0');
      expect(await appUpdateService.isUpdateRequired(), isFalse);
    });

    test('update not required when current version > min version', () async {
      mockRemoteConfig.setString('min_supported_version', '0.9.9');
      expect(await appUpdateService.isUpdateRequired(), isFalse);
    });

    test('handles semantic versioning correctly', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Test App',
        packageName: 'com.example.test',
        version: '1.2.3',
        buildNumber: '1',
        buildSignature: '',
      );

      mockRemoteConfig.setString('min_supported_version', '1.2.4');
      expect(await appUpdateService.isUpdateRequired(), isTrue);

      mockRemoteConfig.setString('min_supported_version', '1.3.0');
      expect(await appUpdateService.isUpdateRequired(), isTrue);

      mockRemoteConfig.setString('min_supported_version', '2.0.0');
      expect(await appUpdateService.isUpdateRequired(), isTrue);

      mockRemoteConfig.setString('min_supported_version', '1.2.2');
      expect(await appUpdateService.isUpdateRequired(), isFalse);
    });
  });
}
