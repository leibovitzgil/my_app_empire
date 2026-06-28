import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirebasePresenceRepository.parseShoppers', () {
    test('maps an RTDB presence node into shoppers', () {
      final shoppers = FirebasePresenceRepository.parseShoppers(
        <Object?, Object?>{
          'dana': <Object?, Object?>{
            'name': 'Dana',
            'colorValue': 0xFFEC4899,
            'since': 1000,
          },
          'sam': <Object?, Object?>{'name': 'Sam', 'colorValue': 0xFF10B981},
        },
      );

      expect(
        shoppers.map((s) => s.collaborator.name),
        containsAll(<String>['Dana', 'Sam']),
      );
      final dana = shoppers.firstWhere((s) => s.collaborator.id == 'dana');
      expect(dana.collaborator.colorValue, 0xFFEC4899);
    });

    test('returns empty for null or non-map values', () {
      expect(FirebasePresenceRepository.parseShoppers(null), isEmpty);
      expect(FirebasePresenceRepository.parseShoppers('nope'), isEmpty);
    });

    test('skips malformed entries', () {
      final shoppers = FirebasePresenceRepository.parseShoppers(
        <Object?, Object?>{
          'ok': <Object?, Object?>{'name': 'Ok', 'colorValue': 1},
          'bad': 'not-a-map',
          'missing': <Object?, Object?>{'colorValue': 1},
        },
      );
      expect(shoppers, hasLength(1));
      expect(shoppers.single.collaborator.name, 'Ok');
    });
  });
}
