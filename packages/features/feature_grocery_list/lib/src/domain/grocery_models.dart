import 'package:equatable/equatable.dart';

/// Sentinel used by `copyWith` so callers can distinguish "leave unchanged"
/// from "set to null" on nullable fields (e.g. clearing a flag).
const Object _unset = Object();

/// A person who can view and edit a shared grocery list. Identity is reused
/// from auth in a real backend; here it carries just enough to render
/// attribution (name + avatar colour).
class Collaborator extends Equatable {
  /// Creates a [Collaborator].
  const Collaborator({
    required this.id,
    required this.name,
    required this.colorValue,
  });

  /// Stable unique id.
  final String id;

  /// Display name shown in attribution chips and presence.
  final String name;

  /// ARGB colour used for this person's avatar (kept as an int so the domain
  /// stays free of the Flutter `Color` type).
  final int colorValue;

  /// One or two-letter initials for a compact avatar.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts[1][0]).toUpperCase();
  }

  @override
  List<Object?> get props => [id, name, colorValue];
}

/// Where an item is in the shared shop. The core of Tandem: a co-shopper can
/// tell "still to grab" from "already in the cart" at a glance.
enum ItemStatus {
  /// Still needs to be picked up.
  needed,

  /// Someone has it in their cart right now.
  inCart,

  /// Bought — collapses into the "Got it" section.
  done,
}

/// A lightweight, conversational signal layered on top of [ItemStatus].
enum ItemFlag {
  /// The shelf was empty.
  outOfStock,

  /// Grab more than usual.
  getExtra,

  /// Needed urgently / don't forget.
  urgent,
}

/// Aisle grouping used to order the list the way a store is walked.
enum ItemCategory {
  /// Fruit & veg.
  produce,

  /// Milk, cheese, eggs.
  dairy,

  /// Bread & baked goods.
  bakery,

  /// Meat & poultry.
  meat,

  /// Fish & seafood.
  seafood,

  /// Frozen foods.
  frozen,

  /// Tins, dry goods, staples.
  pantry,

  /// Crisps, sweets, snacks.
  snacks,

  /// Drinks.
  beverages,

  /// Cleaning & household.
  household,

  /// Anything uncategorised.
  other,
}

/// A single line on a shared grocery list. Immutable; mutations produce a new
/// instance via [copyWith] so blocs can diff cleanly.
class GroceryItem extends Equatable {
  /// Creates a [GroceryItem].
  const GroceryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.addedBy,
    required this.addedAt,
    required this.status,
    required this.statusBy,
    required this.statusAt,
    required this.updatedAt,
    this.flag,
    this.flagBy,
    this.reactions = const <Collaborator>[],
    this.isDeleted = false,
    this.deletedBy,
  });

  /// Stable client-generated id (also the idempotency key for adds).
  final String id;

  /// Human label, e.g. "Milk".
  final String name;

  /// Auto-assigned aisle category.
  final ItemCategory category;

  /// Who first added the item.
  final Collaborator addedBy;

  /// When the item was added.
  final DateTime addedAt;

  /// Current status.
  final ItemStatus status;

  /// Who set the current status (drives the inline attribution chip).
  final Collaborator statusBy;

  /// When the current status was set.
  final DateTime statusAt;

  /// Last time any field changed (used for "just now" rendering).
  final DateTime updatedAt;

  /// Optional conversational flag.
  final ItemFlag? flag;

  /// Who raised the current [flag], if any.
  final Collaborator? flagBy;

  /// People who tapped "On it" on this item's flag.
  final List<Collaborator> reactions;

  /// Tombstone marker: deletes are reversible, never destructive.
  final bool isDeleted;

  /// Who deleted the item, if tombstoned.
  final Collaborator? deletedBy;

  /// Whether this item carries an active flag.
  bool get isFlagged => flag != null && !isDeleted;

  /// Returns a copy with the given overrides. Nullable fields use a sentinel so
  /// `null` can be passed explicitly to clear them.
  GroceryItem copyWith({
    String? name,
    ItemCategory? category,
    ItemStatus? status,
    Collaborator? statusBy,
    DateTime? statusAt,
    DateTime? updatedAt,
    Object? flag = _unset,
    Object? flagBy = _unset,
    List<Collaborator>? reactions,
    bool? isDeleted,
    Object? deletedBy = _unset,
  }) {
    return GroceryItem(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      addedBy: addedBy,
      addedAt: addedAt,
      status: status ?? this.status,
      statusBy: statusBy ?? this.statusBy,
      statusAt: statusAt ?? this.statusAt,
      updatedAt: updatedAt ?? this.updatedAt,
      flag: identical(flag, _unset) ? this.flag : flag as ItemFlag?,
      flagBy: identical(flagBy, _unset) ? this.flagBy : flagBy as Collaborator?,
      reactions: reactions ?? this.reactions,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedBy: identical(deletedBy, _unset)
          ? this.deletedBy
          : deletedBy as Collaborator?,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    category,
    addedBy,
    addedAt,
    status,
    statusBy,
    statusAt,
    updatedAt,
    flag,
    flagBy,
    reactions,
    isDeleted,
    deletedBy,
  ];
}

/// A shared grocery list and all of its items (including tombstoned ones, so
/// the recently-deleted view is driven by the same stream).
class GroceryList extends Equatable {
  /// Creates a [GroceryList].
  const GroceryList({
    required this.id,
    required this.name,
    required this.items,
  });

  /// Stable list id.
  final String id;

  /// Display name, e.g. "Weekly shop".
  final String name;

  /// Every item ever added, including tombstones.
  final List<GroceryItem> items;

  /// Items still to grab or in a cart (not done, not deleted).
  List<GroceryItem> get active =>
      items.where((i) => !i.isDeleted && i.status != ItemStatus.done).toList();

  /// Bought items, kept on the list under "Got it".
  List<GroceryItem> get done =>
      items.where((i) => !i.isDeleted && i.status == ItemStatus.done).toList();

  /// Tombstoned items, newest first.
  List<GroceryItem> get deleted {
    final tombstoned = items.where((i) => i.isDeleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return tombstoned;
  }

  /// How many *active* items currently carry a flag. Scoped to [active] (not
  /// done, not deleted) so it stays consistent with the flags-only filter — a
  /// flag on a done item is considered resolved.
  int get attentionCount => active.where((i) => i.flag != null).length;

  /// Returns a copy with replaced [items].
  GroceryList copyWith({List<GroceryItem>? items}) =>
      GroceryList(id: id, name: name, items: items ?? this.items);

  @override
  List<Object?> get props => [id, name, items];
}

/// A collaborator who is actively shopping the list right now. Equality is by
/// collaborator only so heartbeats don't churn presence state.
class Shopper extends Equatable {
  /// Creates a [Shopper].
  const Shopper({required this.collaborator, required this.since});

  /// Who is shopping.
  final Collaborator collaborator;

  /// When they entered shopping mode.
  final DateTime since;

  @override
  List<Object?> get props => [collaborator];
}
