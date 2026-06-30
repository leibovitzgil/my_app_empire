import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';

/// Serialization between the domain models and Firestore documents. Kept as
/// pure functions so they can be unit-tested without a backend and reused by
/// the repository.
///
/// Timestamps are written from the client clock (`Timestamp.fromDate`) for
/// determinism; a production hardening would use `FieldValue.serverTimestamp()`
/// for `updatedAt` to get authoritative last-write-wins ordering.
Map<String, dynamic> collaboratorToMap(Collaborator who) => <String, dynamic>{
  'id': who.id,
  'name': who.name,
  'colorValue': who.colorValue,
};

Collaborator collaboratorFromMap(Map<String, dynamic> map) => Collaborator(
  id: map['id'] as String,
  name: map['name'] as String,
  colorValue: (map['colorValue'] as num).toInt(),
);

Map<String, dynamic> itemToMap(GroceryItem item) => <String, dynamic>{
  'name': item.name,
  'category': item.category.name,
  'addedBy': collaboratorToMap(item.addedBy),
  'addedAt': Timestamp.fromDate(item.addedAt),
  'status': item.status.name,
  'statusBy': collaboratorToMap(item.statusBy),
  'statusAt': Timestamp.fromDate(item.statusAt),
  'updatedAt': Timestamp.fromDate(item.updatedAt),
  'flag': item.flag?.name,
  'flagBy': item.flagBy == null ? null : collaboratorToMap(item.flagBy!),
  'reactions': item.reactions.map(collaboratorToMap).toList(),
  'isDeleted': item.isDeleted,
  'deletedBy': item.deletedBy == null
      ? null
      : collaboratorToMap(item.deletedBy!),
};

GroceryItem itemFromMap(String id, Map<String, dynamic> data) {
  final flagBy = data['flagBy'];
  final deletedBy = data['deletedBy'];
  final reactions = data['reactions'] as List<dynamic>? ?? const <dynamic>[];
  return GroceryItem(
    id: id,
    name: data['name'] as String,
    category: categoryFromName(data['category'] as String?),
    addedBy: collaboratorFromMap(_asMap(data['addedBy'])),
    addedAt: _dateFrom(data['addedAt']),
    status: statusFromName(data['status'] as String?),
    statusBy: collaboratorFromMap(_asMap(data['statusBy'])),
    statusAt: _dateFrom(data['statusAt']),
    updatedAt: _dateFrom(data['updatedAt']),
    flag: flagFromName(data['flag'] as String?),
    flagBy: flagBy == null ? null : collaboratorFromMap(_asMap(flagBy)),
    reactions: reactions.map((e) => collaboratorFromMap(_asMap(e))).toList(),
    isDeleted: data['isDeleted'] as bool? ?? false,
    deletedBy: deletedBy == null
        ? null
        : collaboratorFromMap(_asMap(deletedBy)),
  );
}

Map<String, dynamic> memberToMap(ListMember member) => <String, dynamic>{
  'collaborator': collaboratorToMap(member.collaborator),
  'role': member.role.name,
  'status': member.status.name,
  'since': Timestamp.fromDate(member.since),
};

ListMember memberFromMap(Map<String, dynamic> data) => ListMember(
  collaborator: collaboratorFromMap(_asMap(data['collaborator'])),
  role: roleFromName(data['role'] as String?),
  status: memberStatusFromName(data['status'] as String?),
  since: _dateFrom(data['since']),
);

/// Parses a [MemberRole] by name, defaulting to [MemberRole.editor].
MemberRole roleFromName(String? name) => MemberRole.values.firstWhere(
  (r) => r.name == name,
  orElse: () => MemberRole.editor,
);

/// Parses a [MemberStatus] by name, defaulting to [MemberStatus.active].
MemberStatus memberStatusFromName(String? name) =>
    MemberStatus.values.firstWhere(
      (s) => s.name == name,
      orElse: () => MemberStatus.active,
    );

/// Parses an [ItemStatus] by name, defaulting to [ItemStatus.needed].
ItemStatus statusFromName(String? name) => ItemStatus.values.firstWhere(
  (s) => s.name == name,
  orElse: () => ItemStatus.needed,
);

/// Parses an [ItemCategory] by name, defaulting to [ItemCategory.other].
ItemCategory categoryFromName(String? name) => ItemCategory.values.firstWhere(
  (c) => c.name == name,
  orElse: () => ItemCategory.other,
);

/// Parses an [ItemFlag] by name, or null if absent/unknown.
ItemFlag? flagFromName(String? name) {
  if (name == null) return null;
  for (final flag in ItemFlag.values) {
    if (flag.name == name) return flag;
  }
  return null;
}

Map<String, dynamic> _asMap(Object? value) =>
    Map<String, dynamic>.from(value! as Map<dynamic, dynamic>);

DateTime _dateFrom(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  // Pending serverTimestamp reads back as null on the writer's local snapshot;
  // fall back to "now" until the server value lands.
  return DateTime.now();
}
