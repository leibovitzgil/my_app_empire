import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/domain/item_catalog.dart';

/// A static, on-device [ItemCatalog]: a curated list of common groceries with
/// their aisle category, plus a learned-frequency boost for items this
/// household actually adds.
class StaticItemCatalog implements ItemCatalog {
  /// Creates a [StaticItemCatalog].
  StaticItemCatalog();

  /// Known item -> category. Lower-cased keys; lookups are case-insensitive.
  static const Map<String, ItemCategory> _known = <String, ItemCategory>{
    'apples': ItemCategory.produce,
    'bananas': ItemCategory.produce,
    'avocado': ItemCategory.produce,
    'tomatoes': ItemCategory.produce,
    'onions': ItemCategory.produce,
    'potatoes': ItemCategory.produce,
    'carrots': ItemCategory.produce,
    'lettuce': ItemCategory.produce,
    'spinach': ItemCategory.produce,
    'garlic': ItemCategory.produce,
    'lemons': ItemCategory.produce,
    'peppers': ItemCategory.produce,
    'cucumber': ItemCategory.produce,
    'broccoli': ItemCategory.produce,
    'milk': ItemCategory.dairy,
    'eggs': ItemCategory.dairy,
    'butter': ItemCategory.dairy,
    'cheese': ItemCategory.dairy,
    'yogurt': ItemCategory.dairy,
    'cream': ItemCategory.dairy,
    'bread': ItemCategory.bakery,
    'bagels': ItemCategory.bakery,
    'croissants': ItemCategory.bakery,
    'tortillas': ItemCategory.bakery,
    'muffins': ItemCategory.bakery,
    'chicken': ItemCategory.meat,
    'beef': ItemCategory.meat,
    'mince': ItemCategory.meat,
    'bacon': ItemCategory.meat,
    'sausages': ItemCategory.meat,
    'ham': ItemCategory.meat,
    'turkey': ItemCategory.meat,
    'salmon': ItemCategory.seafood,
    'tuna': ItemCategory.seafood,
    'shrimp': ItemCategory.seafood,
    'cod': ItemCategory.seafood,
    'ice cream': ItemCategory.frozen,
    'frozen peas': ItemCategory.frozen,
    'frozen pizza': ItemCategory.frozen,
    'fish fingers': ItemCategory.frozen,
    'rice': ItemCategory.pantry,
    'pasta': ItemCategory.pantry,
    'flour': ItemCategory.pantry,
    'sugar': ItemCategory.pantry,
    'salt': ItemCategory.pantry,
    'olive oil': ItemCategory.pantry,
    'cereal': ItemCategory.pantry,
    'beans': ItemCategory.pantry,
    'peanut butter': ItemCategory.pantry,
    'honey': ItemCategory.pantry,
    'crisps': ItemCategory.snacks,
    'chips': ItemCategory.snacks,
    'chocolate': ItemCategory.snacks,
    'biscuits': ItemCategory.snacks,
    'nuts': ItemCategory.snacks,
    'popcorn': ItemCategory.snacks,
    'water': ItemCategory.beverages,
    'coffee': ItemCategory.beverages,
    'tea': ItemCategory.beverages,
    'juice': ItemCategory.beverages,
    'soda': ItemCategory.beverages,
    'wine': ItemCategory.beverages,
    'beer': ItemCategory.beverages,
    'toilet paper': ItemCategory.household,
    'paper towels': ItemCategory.household,
    'dish soap': ItemCategory.household,
    'detergent': ItemCategory.household,
    'sponges': ItemCategory.household,
    'foil': ItemCategory.household,
    'bin bags': ItemCategory.household,
  };

  /// Keyword -> category fallback for names not in [_known]. Matched by
  /// substring so "chicken breast" still resolves to meat.
  static const Map<String, ItemCategory> _keywords = <String, ItemCategory>{
    'fruit': ItemCategory.produce,
    'veg': ItemCategory.produce,
    'berry': ItemCategory.produce,
    'berries': ItemCategory.produce,
    'salad': ItemCategory.produce,
    'milk': ItemCategory.dairy,
    'cheese': ItemCategory.dairy,
    'yog': ItemCategory.dairy,
    'bread': ItemCategory.bakery,
    'roll': ItemCategory.bakery,
    'chicken': ItemCategory.meat,
    'beef': ItemCategory.meat,
    'pork': ItemCategory.meat,
    'fish': ItemCategory.seafood,
    'prawn': ItemCategory.seafood,
    'frozen': ItemCategory.frozen,
    'pasta': ItemCategory.pantry,
    'sauce': ItemCategory.pantry,
    'oil': ItemCategory.pantry,
    'snack': ItemCategory.snacks,
    'choc': ItemCategory.snacks,
    'water': ItemCategory.beverages,
    'juice': ItemCategory.beverages,
    'coffee': ItemCategory.beverages,
    'tea': ItemCategory.beverages,
    'soap': ItemCategory.household,
    'clean': ItemCategory.household,
    'paper': ItemCategory.household,
  };

  final Map<String, int> _frequency = <String, int>{};

  @override
  List<String> suggest(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const <String>[];
    final names = <String>{..._frequency.keys, ..._known.keys};
    final matches = names.where((n) => n.contains(q)).toList()
      ..sort((a, b) {
        final byFreq = (_frequency[b] ?? 0).compareTo(_frequency[a] ?? 0);
        if (byFreq != 0) return byFreq;
        // Prefer prefix matches, then alphabetical.
        final aPrefix = a.startsWith(q) ? 0 : 1;
        final bPrefix = b.startsWith(q) ? 0 : 1;
        if (aPrefix != bPrefix) return aPrefix - bPrefix;
        return a.compareTo(b);
      });
    return matches.take(6).map(_titleCase).toList();
  }

  @override
  ItemCategory categorize(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return ItemCategory.other;
    final exact = _known[n];
    if (exact != null) return exact;
    for (final entry in _keywords.entries) {
      if (n.contains(entry.key)) return entry.value;
    }
    return ItemCategory.other;
  }

  @override
  void remember(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return;
    _frequency[n] = (_frequency[n] ?? 0) + 1;
  }

  static String _titleCase(String value) => value
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}
