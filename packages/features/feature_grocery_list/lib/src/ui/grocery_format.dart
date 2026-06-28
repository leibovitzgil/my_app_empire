import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:flutter/material.dart';

/// Maps domain enums to Material visuals and renders relative timestamps. Keeps
/// the domain layer free of Flutter types while giving the UI one place to
/// style status, categories and flags consistently.
abstract final class GroceryFormat {
  /// Store-walk order for category sections.
  static const List<ItemCategory> categoryOrder = ItemCategory.values;

  /// A short, friendly relative time, e.g. "just now", "5 min ago".
  static String relativeTime(DateTime time, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(time);
    if (diff.isNegative || diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }

  /// The verb shown in an item's attribution chip for a given status.
  static String statusVerb(ItemStatus status) => switch (status) {
    ItemStatus.needed => 'Needed',
    ItemStatus.inCart => 'In cart',
    ItemStatus.done => 'Got it',
  };

  /// Leading icon for a status.
  static IconData statusIcon(ItemStatus status) => switch (status) {
    ItemStatus.needed => Icons.radio_button_unchecked,
    ItemStatus.inCart => Icons.shopping_cart,
    ItemStatus.done => Icons.check_circle,
  };

  /// Human label for a category section header.
  static String categoryLabel(ItemCategory category) => switch (category) {
    ItemCategory.produce => 'Produce',
    ItemCategory.dairy => 'Dairy & eggs',
    ItemCategory.bakery => 'Bakery',
    ItemCategory.meat => 'Meat',
    ItemCategory.seafood => 'Seafood',
    ItemCategory.frozen => 'Frozen',
    ItemCategory.pantry => 'Pantry',
    ItemCategory.snacks => 'Snacks',
    ItemCategory.beverages => 'Drinks',
    ItemCategory.household => 'Household',
    ItemCategory.other => 'Other',
  };

  /// Icon for a category section header.
  static IconData categoryIcon(ItemCategory category) => switch (category) {
    ItemCategory.produce => Icons.eco,
    ItemCategory.dairy => Icons.egg,
    ItemCategory.bakery => Icons.bakery_dining,
    ItemCategory.meat => Icons.kebab_dining,
    ItemCategory.seafood => Icons.set_meal,
    ItemCategory.frozen => Icons.ac_unit,
    ItemCategory.pantry => Icons.rice_bowl,
    ItemCategory.snacks => Icons.cookie,
    ItemCategory.beverages => Icons.local_cafe,
    ItemCategory.household => Icons.cleaning_services,
    ItemCategory.other => Icons.shopping_basket,
  };

  /// Short label for a flag.
  static String flagLabel(ItemFlag flag) => switch (flag) {
    ItemFlag.outOfStock => 'Out of stock',
    ItemFlag.getExtra => 'Get extra',
    ItemFlag.urgent => 'Urgent',
  };

  /// Icon for a flag.
  static IconData flagIcon(ItemFlag flag) => switch (flag) {
    ItemFlag.outOfStock => Icons.remove_shopping_cart,
    ItemFlag.getExtra => Icons.add_shopping_cart,
    ItemFlag.urgent => Icons.priority_high,
  };

  /// Accent colour for a flag. Uses fixed, contrast-checked tones for
  /// out-of-stock/get-extra and the theme error colour for urgent.
  static Color flagColor(ItemFlag flag, ColorScheme scheme) => switch (flag) {
    ItemFlag.outOfStock => const Color(0xFFB45309),
    ItemFlag.getExtra => const Color(0xFF15803D),
    ItemFlag.urgent => scheme.error,
  };

  /// Avatar colour for a collaborator.
  static Color collaboratorColor(Collaborator who) => Color(who.colorValue);

  /// "you" for the current user, otherwise the member's first name.
  static String displayName(Collaborator who, Collaborator currentUser) =>
      who.id == currentUser.id ? 'you' : who.name;
}
