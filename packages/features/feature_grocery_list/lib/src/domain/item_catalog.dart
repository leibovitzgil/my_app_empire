import 'package:feature_grocery_list/src/domain/grocery_models.dart';

/// Suggests common grocery items as the user types and assigns an aisle
/// category to a freshly typed name. In the MVP this is a static, on-device
/// catalogue; later it can learn from a household's history.
abstract class ItemCatalog {
  /// Returns up to a handful of suggestions matching [query]
  /// (case-insensitive), with frequently-added items first.
  List<String> suggest(String query);

  /// Maps a name to its best-guess [ItemCategory], defaulting to
  /// [ItemCategory.other].
  ItemCategory categorize(String name);

  /// Records that [name] was added, so it ranks higher in future suggestions.
  void remember(String name);
}
