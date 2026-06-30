import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_grocery_list/src/data/firestore_mappers.dart';
import 'package:feature_grocery_list/src/data/invite_identity.dart';
import 'package:feature_grocery_list/src/data/static_item_catalog.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/domain/grocery_repository.dart';
import 'package:feature_grocery_list/src/domain/item_catalog.dart';
import 'package:feature_grocery_list/src/domain/membership_repository.dart';

/// A [GroceryRepository] backed by Cloud Firestore. Real-time reads are just a
/// `snapshots()` listener — the database does the fan-out, so there is no
/// broadcast plumbing to maintain. Read-modify-write mutations (status cycle,
/// reactions) run in transactions so concurrent shoppers don't clobber each
/// other; the rest are field updates.
///
/// Items live at `households/{listId}/items/{itemId}` and members at
/// `households/{listId}/members/{collaboratorId}`. Bind this in an app's DI in
/// place of `InMemoryGroceryRepository`; nothing above the data layer changes
/// (the blocs depend only on [GroceryRepository] / [MembershipRepository]).
class FirestoreGroceryRepository
    implements GroceryRepository, MembershipRepository {
  /// Creates a [FirestoreGroceryRepository].
  FirestoreGroceryRepository({
    required FirebaseFirestore firestore,
    required String listId,
    String listName = 'Weekly shop',
    ItemCatalog? catalog,
    DateTime Function()? clock,
  }) : _firestore = firestore,
       _listId = listId,
       _listName = listName,
       _catalog = catalog ?? StaticItemCatalog(),
       _now = clock ?? DateTime.now;

  final FirebaseFirestore _firestore;
  final String _listId;
  final String _listName;
  final ItemCatalog _catalog;
  final DateTime Function() _now;

  CollectionReference<Map<String, dynamic>> get _items =>
      _firestore.collection('households').doc(_listId).collection('items');

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection('households').doc(_listId).collection('members');

  @override
  Stream<GroceryList> watchList() {
    return _items.orderBy('addedAt').snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => itemFromMap(doc.id, doc.data()))
          .toList();
      return GroceryList(id: _listId, name: _listName, items: items);
    });
  }

  @override
  Future<Result<GroceryItem>> addItem(
    String name, {
    required Collaborator by,
  }) {
    return Result.guard<GroceryItem>(() async {
      final trimmed = name.trim();
      if (trimmed.isEmpty) {
        throw ArgumentError('Item name cannot be empty');
      }
      final titled = _sentenceCase(trimmed);
      // Idempotent: reuse a live item with the same name (filter isDeleted in
      // code so the query needs no composite index).
      final byName = await _items.where('name', isEqualTo: titled).get();
      for (final doc in byName.docs) {
        if (!(doc.data()['isDeleted'] as bool? ?? false)) {
          return itemFromMap(doc.id, doc.data());
        }
      }
      _catalog.remember(trimmed);
      final now = _now();
      final ref = _items.doc();
      final item = GroceryItem(
        id: ref.id,
        name: titled,
        category: _catalog.categorize(trimmed),
        addedBy: by,
        addedAt: now,
        status: ItemStatus.needed,
        statusBy: by,
        statusAt: now,
        updatedAt: now,
      );
      await ref.set(itemToMap(item));
      return item;
    });
  }

  @override
  Future<Result<void>> cycleStatus(String itemId, {required Collaborator by}) {
    return Result.guard<void>(() async {
      final ref = _items.doc(itemId);
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(ref);
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw StateError('No grocery item with id "$itemId"');
        }
        final current = itemFromMap(snapshot.id, data);
        tx.update(ref, _statusUpdate(_next(current.status), by));
      });
    });
  }

  @override
  Future<Result<void>> setStatus(
    String itemId,
    ItemStatus status, {
    required Collaborator by,
  }) {
    return Result.guard<void>(
      () async => _items.doc(itemId).update(_statusUpdate(status, by)),
    );
  }

  @override
  Future<Result<void>> setFlag(
    String itemId,
    ItemFlag? flag, {
    required Collaborator by,
  }) {
    return Result.guard<void>(() async {
      final now = Timestamp.fromDate(_now());
      await _items.doc(itemId).update(<String, dynamic>{
        'flag': flag?.name,
        'flagBy': flag == null ? null : collaboratorToMap(by),
        if (flag == null) 'reactions': <Map<String, dynamic>>[],
        'updatedAt': now,
      });
    });
  }

  @override
  Future<Result<void>> reactOnIt(String itemId, {required Collaborator by}) {
    return Result.guard<void>(() async {
      final ref = _items.doc(itemId);
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(ref);
        final data = snapshot.data();
        if (!snapshot.exists || data == null) {
          throw StateError('No grocery item with id "$itemId"');
        }
        final item = itemFromMap(snapshot.id, data);
        if (item.reactions.any((c) => c.id == by.id)) return;
        tx.update(ref, <String, dynamic>{
          'reactions': [
            ...item.reactions.map(collaboratorToMap),
            collaboratorToMap(by),
          ],
          'updatedAt': Timestamp.fromDate(_now()),
        });
      });
    });
  }

  @override
  Future<Result<void>> deleteItem(String itemId, {required Collaborator by}) {
    return Result.guard<void>(
      () async => _items.doc(itemId).update(<String, dynamic>{
        'isDeleted': true,
        'deletedBy': collaboratorToMap(by),
        'updatedAt': Timestamp.fromDate(_now()),
      }),
    );
  }

  @override
  Future<Result<void>> restoreItem(String itemId) {
    return Result.guard<void>(
      () async => _items.doc(itemId).update(<String, dynamic>{
        'isDeleted': false,
        'deletedBy': null,
        'updatedAt': Timestamp.fromDate(_now()),
      }),
    );
  }

  @override
  Future<Result<void>> clearDone({required Collaborator by}) {
    return Result.guard<void>(() async {
      final done = await _items
          .where('status', isEqualTo: ItemStatus.done.name)
          .get();
      final live = done.docs.where(
        (d) => !(d.data()['isDeleted'] as bool? ?? false),
      );
      if (live.isEmpty) return;
      final batch = _firestore.batch();
      final now = Timestamp.fromDate(_now());
      for (final doc in live) {
        batch.update(doc.reference, <String, dynamic>{
          'isDeleted': true,
          'deletedBy': collaboratorToMap(by),
          'updatedAt': now,
        });
      }
      await batch.commit();
    });
  }

  // --- MembershipRepository --------------------------------------------------

  @override
  Stream<List<ListMember>> watchMembers() {
    return _members
        .orderBy('since')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => memberFromMap(doc.data())).toList(),
        );
  }

  @override
  Future<Result<ListMember>> inviteByEmail(
    String email, {
    MemberRole role = MemberRole.editor,
  }) {
    return Result.guard<ListMember>(() async {
      if (!isValidEmail(email)) {
        throw const MembershipException('Enter a valid email address');
      }
      final who = collaboratorForEmail(email);
      final ref = _members.doc(who.id);
      final existing = await ref.get();
      final data = existing.data();
      if (existing.exists && data != null) {
        return memberFromMap(data);
      }
      final member = ListMember(
        collaborator: who,
        role: role,
        status: MemberStatus.invited,
        since: _now(),
      );
      await ref.set(memberToMap(member));
      return member;
    });
  }

  @override
  Future<Result<void>> removeMember(String collaboratorId) {
    return Result.guard<void>(() async {
      final ref = _members.doc(collaboratorId);
      final snapshot = await ref.get();
      final data = snapshot.data();
      if (!snapshot.exists || data == null) return;
      if (memberFromMap(data).isOwner) {
        throw const MembershipException("The owner can't be removed");
      }
      await ref.delete();
    });
  }

  @override
  String inviteLink() => 'https://tandem.app/join/$_listId';

  Map<String, dynamic> _statusUpdate(ItemStatus status, Collaborator by) {
    final now = Timestamp.fromDate(_now());
    return <String, dynamic>{
      'status': status.name,
      'statusBy': collaboratorToMap(by),
      'statusAt': now,
      'updatedAt': now,
    };
  }

  static ItemStatus _next(ItemStatus status) => switch (status) {
    ItemStatus.needed => ItemStatus.inCart,
    ItemStatus.inCart => ItemStatus.done,
    ItemStatus.done => ItemStatus.needed,
  };

  static String _sentenceCase(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
