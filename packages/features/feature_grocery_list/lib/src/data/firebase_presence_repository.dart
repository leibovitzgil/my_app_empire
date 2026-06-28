import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/domain/presence_repository.dart';
import 'package:firebase_database/firebase_database.dart';

/// A [PresenceRepository] backed by Firebase Realtime Database.
///
/// The key idea: **liveness is the database's job, not the client's.** When a
/// user enters shopping mode we register a server-side `onDisconnect()` on
/// their node, so the moment their socket drops — app killed, network lost,
/// crash — the *server* removes them. A data stream alone can't do this: a
/// client that disconnects never gets to write "I left", which is exactly why
/// the in-memory impl needed a heartbeat + TTL. With `onDisconnect` that's
/// unnecessary, so [heartbeat] is a deliberate no-op here.
///
/// Presence lives at `presence/{listId}/{userId}`.
class FirebasePresenceRepository implements PresenceRepository {
  /// Creates a [FirebasePresenceRepository].
  FirebasePresenceRepository({
    required FirebaseDatabase database,
    required String listId,
  }) : _database = database,
       _listId = listId;

  final FirebaseDatabase _database;
  final String _listId;

  DatabaseReference get _root => _database.ref('presence/$_listId');

  @override
  Stream<List<Shopper>> watchShoppers() =>
      _root.onValue.map((event) => parseShoppers(event.snapshot.value));

  @override
  Future<void> enter(Collaborator who) async {
    final ref = _root.child(who.id);
    // Register the disconnect handler BEFORE writing presence, so a drop in the
    // gap still cleans up.
    await ref.onDisconnect().remove();
    await ref.set(<String, Object?>{
      'name': who.name,
      'colorValue': who.colorValue,
      'since': ServerValue.timestamp,
    });
  }

  @override
  Future<void> heartbeat(String collaboratorId) async {
    // No-op: staleness is handled server-side by onDisconnect(). No periodic
    // heartbeat needed; a pure-Firestore impl would need a real one here.
  }

  @override
  Future<void> leave(String collaboratorId) async {
    final ref = _root.child(collaboratorId);
    await ref.onDisconnect().cancel();
    await ref.remove();
  }

  /// Parses a `presence/{listId}` RTDB node value into [Shopper]s. Public and
  /// pure so it can be unit-tested without a live database.
  static List<Shopper> parseShoppers(Object? value) {
    if (value is! Map<Object?, Object?>) return const <Shopper>[];
    final shoppers = <Shopper>[];
    for (final entry in value.entries) {
      final raw = entry.value;
      if (raw is! Map<Object?, Object?>) continue;
      final name = raw['name'];
      final color = raw['colorValue'];
      if (name is! String || color is! num) continue;
      final since = raw['since'];
      shoppers.add(
        Shopper(
          collaborator: Collaborator(
            id: entry.key.toString(),
            name: name,
            colorValue: color.toInt(),
          ),
          since: since is int
              ? DateTime.fromMillisecondsSinceEpoch(since)
              : DateTime.fromMillisecondsSinceEpoch(0),
        ),
      );
    }
    return shoppers;
  }
}
