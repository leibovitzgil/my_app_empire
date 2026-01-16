import 'package:flutter_test/flutter_test.dart';
import 'package:local_storage/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalStorageService', () {
    late LocalStorageService localStorageService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      localStorageService = LocalStorageService(prefs);
    });

    test('can set and get bool', () async {
      await localStorageService.setBool('test_bool', true);
      expect(localStorageService.getBool('test_bool'), isTrue);
    });

    test('can set and get string', () async {
      await localStorageService.setString('test_string', 'hello');
      expect(localStorageService.getString('test_string'), 'hello');
    });

    test('can remove key', () async {
      await localStorageService.setString('test_remove', 'value');
      await localStorageService.remove('test_remove');
      expect(localStorageService.getString('test_remove'), isNull);
    });
  });
}
