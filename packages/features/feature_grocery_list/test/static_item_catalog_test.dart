import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StaticItemCatalog', () {
    late StaticItemCatalog catalog;

    setUp(() => catalog = StaticItemCatalog());

    test('categorizes known items (F5)', () {
      expect(catalog.categorize('Milk'), ItemCategory.dairy);
      expect(catalog.categorize('bananas'), ItemCategory.produce);
      expect(catalog.categorize('Chicken breast'), ItemCategory.meat);
    });

    test('falls back to other for an unrecognised item (F5)', () {
      expect(catalog.categorize('Flux capacitor'), ItemCategory.other);
    });

    test('suggests matching items, remembered ones first (F5)', () {
      expect(catalog.suggest('mil'), contains('Milk'));
      catalog.remember('milkshake');
      final suggestions = catalog.suggest('milk');
      expect(suggestions.first.toLowerCase(), 'milkshake');
    });

    test('returns no suggestions for an empty query', () {
      expect(catalog.suggest('   '), isEmpty);
    });
  });
}
