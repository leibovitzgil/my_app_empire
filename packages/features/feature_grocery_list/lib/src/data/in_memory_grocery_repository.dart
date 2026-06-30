import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:feature_grocery_list/src/data/grocery_seed.dart';
import 'package:feature_grocery_list/src/data/invite_identity.dart';
import 'package:feature_grocery_list/src/data/static_item_catalog.dart';
import 'package:feature_grocery_list/src/domain/grocery_models.dart';
import 'package:feature_grocery_list/src/domain/grocery_repository.dart';
import 'package:feature_grocery_list/src/domain/item_catalog.dart';
import 'package:feature_grocery_list/src/domain/membership_repository.dart';
import 'package:feature_grocery_list/src/domain/presence_repository.dart';

/// An in-memory [GroceryRepository] + [PresenceRepository] that simulates
/// multi-device, real-time sync. A single shared broadcast stream fans every
/// mutation out to all subscribers, so registering this as a get_it singleton
/// makes two `watchList` subscribers behave like two phones on the same list.
///
/// When `demo` is true it also drives a Dana-shaped simulated collaborator
/// that enters shopping mode, grabs an item, flags another and finishes —
/// proving the live experience with no backend. Tests construct it with
/// `demo: false` so no timers leak.
///
/// The whole class is the swap-to-Firestore seam: a real backend would
/// implement the same two contracts and nothing above the data layer changes.
class InMemoryGroceryRepository
    implements GroceryRepository, PresenceRepository, MembershipRepository {
  /// Creates an [InMemoryGroceryRepository].
  ///
  /// [demo] enables the simulated collaborator. [clock] and [catalog] are
  /// injectable for deterministic tests.
  InMemoryGroceryRepository({
    bool demo = true,
    DateTime Function()? clock,
    ItemCatalog? catalog,
  }) : _demo = demo,
       _now = clock ?? DateTime.now,
       _catalog = catalog ?? StaticItemCatalog() {
    _list = GrocerySeed.initialList(_now());
    _seedMembers();
  }

  /// How long a shopper stays visible after their last heartbeat.
  static const Duration presenceTtl = Duration(seconds: 30);

  final bool _demo;
  final DateTime Function() _now;
  final ItemCatalog _catalog;

  late GroceryList _list;
  final StreamController<GroceryList> _listController =
      StreamController<GroceryList>.broadcast();

  final Map<String, Shopper> _shoppers = <String, Shopper>{};
  final Map<String, DateTime> _lastSeen = <String, DateTime>{};
  final StreamController<List<Shopper>> _presenceController =
      StreamController<List<Shopper>>.broadcast();

  final Map<String, ListMember> _members = <String, ListMember>{};
  final StreamController<List<ListMember>> _membersController =
      StreamController<List<ListMember>>.broadcast();
  final List<Timer> _inviteTimers = <Timer>[];

  final List<Timer> _simTimers = <Timer>[];
  Timer? _ttlTimer;
  bool _simStarted = false;
  String? _simGrabbedId;
  int _seq = 0;

  // --- GroceryRepository -----------------------------------------------------

  @override
  Stream<GroceryList> watchList() async* {
    _maybeStartSimulation();
    yield _list;
    yield* _listController.stream;
  }

  @override
  Future<Result<GroceryItem>> addItem(
    String name, {
    required Collaborator by,
  }) => Result.guard<GroceryItem>(() async => _addCore(name, by));

  @override
  Future<Result<void>> cycleStatus(String itemId, {required Collaborator by}) =>
      Result.guard<void>(() async => _cycleCore(itemId, by));

  @override
  Future<Result<void>> setStatus(
    String itemId,
    ItemStatus status, {
    required Collaborator by,
  }) => Result.guard<void>(() async => _setStatusCore(itemId, status, by));

  @override
  Future<Result<void>> setFlag(
    String itemId,
    ItemFlag? flag, {
    required Collaborator by,
  }) => Result.guard<void>(() async => _setFlagCore(itemId, flag, by));

  @override
  Future<Result<void>> reactOnIt(String itemId, {required Collaborator by}) =>
      Result.guard<void>(() async => _reactCore(itemId, by));

  @override
  Future<Result<void>> deleteItem(String itemId, {required Collaborator by}) =>
      Result.guard<void>(() async => _deleteCore(itemId, by));

  @override
  Future<Result<void>> restoreItem(String itemId) =>
      Result.guard<void>(() async => _restoreCore(itemId));

  @override
  Future<Result<void>> clearDone({required Collaborator by}) =>
      Result.guard<void>(() async => _clearDoneCore(by));

  // --- PresenceRepository ----------------------------------------------------

  @override
  Stream<List<Shopper>> watchShoppers() async* {
    yield _shoppers.values.toList();
    yield* _presenceController.stream;
  }

  @override
  Future<void> enter(Collaborator who) async {
    final now = _now();
    _shoppers[who.id] = Shopper(collaborator: who, since: now);
    _lastSeen[who.id] = now;
    _emitPresence();
  }

  @override
  Future<void> heartbeat(String collaboratorId) async {
    if (_shoppers.containsKey(collaboratorId)) {
      _lastSeen[collaboratorId] = _now();
    }
  }

  @override
  Future<void> leave(String collaboratorId) async {
    final removed = _shoppers.remove(collaboratorId) != null;
    _lastSeen.remove(collaboratorId);
    if (removed) _emitPresence();
  }

  /// Drops shoppers whose heartbeat is older than [presenceTtl]. Driven by a
  /// timer in the demo; also called directly from tests.
  void pruneStalePresence() {
    final now = _now();
    final stale = <String>[
      for (final entry in _lastSeen.entries)
        if (now.difference(entry.value) > presenceTtl) entry.key,
    ];
    if (stale.isEmpty) return;
    for (final id in stale) {
      _shoppers.remove(id);
      _lastSeen.remove(id);
    }
    _emitPresence();
  }

  // --- MembershipRepository --------------------------------------------------

  @override
  Stream<List<ListMember>> watchMembers() async* {
    yield _membersList();
    yield* _membersController.stream;
  }

  @override
  Future<Result<ListMember>> inviteByEmail(
    String email, {
    MemberRole role = MemberRole.editor,
  }) => Result.guard<ListMember>(() async => _inviteCore(email, role));

  @override
  Future<Result<void>> removeMember(String collaboratorId) =>
      Result.guard<void>(() async => _removeMemberCore(collaboratorId));

  @override
  String inviteLink() => 'https://tandem.app/join/${GrocerySeed.listId}';

  /// Seeds the starter household: you (owner) plus the two demo collaborators,
  /// so the share sheet opens onto a real roster — and the simulated Dana is a
  /// member, not a stranger.
  void _seedMembers() {
    final now = _now();
    _members[GrocerySeed.you.id] = ListMember(
      collaborator: GrocerySeed.you,
      role: MemberRole.owner,
      status: MemberStatus.active,
      since: now.subtract(const Duration(days: 30)),
    );
    _members[GrocerySeed.dana.id] = ListMember(
      collaborator: GrocerySeed.dana,
      role: MemberRole.editor,
      status: MemberStatus.active,
      since: now.subtract(const Duration(days: 14)),
    );
    _members[GrocerySeed.sam.id] = ListMember(
      collaborator: GrocerySeed.sam,
      role: MemberRole.editor,
      status: MemberStatus.active,
      since: now.subtract(const Duration(days: 7)),
    );
  }

  List<ListMember> _membersList() {
    return _members.values.toList()..sort((a, b) => a.since.compareTo(b.since));
  }

  ListMember _inviteCore(String email, MemberRole role) {
    if (!isValidEmail(email)) {
      throw const MembershipException('Enter a valid email address');
    }
    final who = collaboratorForEmail(email);
    final existing = _members[who.id];
    if (existing != null) return existing;
    final member = ListMember(
      collaborator: who,
      role: role,
      status: MemberStatus.invited,
      since: _now(),
    );
    _members[member.collaborator.id] = member;
    _emitMembers();
    _maybeSimulateAccept(member);
    return member;
  }

  void _removeMemberCore(String collaboratorId) {
    final member = _members[collaboratorId];
    if (member == null) return;
    if (member.isOwner) {
      throw const MembershipException("The owner can't be removed");
    }
    _members.remove(collaboratorId);
    _emitMembers();
  }

  void _emitMembers() {
    if (!_membersController.isClosed) {
      _membersController.add(_membersList());
    }
  }

  // In the demo, a freshly invited person "accepts" after a short beat so the
  // pending -> active transition is visible live (mirrors the Dana simulation).
  // Off in tests (demo: false), so no timers leak and invites stay pending.
  void _maybeSimulateAccept(ListMember invited) {
    if (!_demo) return;
    _inviteTimers.add(
      Timer(const Duration(milliseconds: 2500), () {
        final current = _members[invited.collaborator.id];
        if (current == null || current.status != MemberStatus.invited) return;
        _members[current.collaborator.id] = current.copyWith(
          status: MemberStatus.active,
          since: _now(),
        );
        _emitMembers();
      }),
    );
  }

  /// Cancels timers and closes streams. Call from tests' tearDown; the app's
  /// get_it singleton lives for the process lifetime.
  Future<void> dispose() async {
    for (final t in _simTimers) {
      t.cancel();
    }
    _simTimers.clear();
    for (final t in _inviteTimers) {
      t.cancel();
    }
    _inviteTimers.clear();
    _ttlTimer?.cancel();
    await _listController.close();
    await _presenceController.close();
    await _membersController.close();
  }

  // --- mutation core (sync, no Result) ---------------------------------------

  GroceryItem _addCore(String name, Collaborator by) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Item name cannot be empty');
    }
    final existing = _activeByName(trimmed);
    if (existing != null) return existing;
    _catalog.remember(trimmed);
    final now = _now();
    final item = GroceryItem(
      id: _nextId(),
      name: _titleCase(trimmed),
      category: _catalog.categorize(trimmed),
      addedBy: by,
      addedAt: now,
      status: ItemStatus.needed,
      statusBy: by,
      statusAt: now,
      updatedAt: now,
    );
    _list = _list.copyWith(items: <GroceryItem>[..._list.items, item]);
    _emit();
    return item;
  }

  void _cycleCore(String id, Collaborator by) {
    final item = _requireItem(id);
    final next = switch (item.status) {
      ItemStatus.needed => ItemStatus.inCart,
      ItemStatus.inCart => ItemStatus.done,
      ItemStatus.done => ItemStatus.needed,
    };
    _setStatusCore(id, next, by);
  }

  void _setStatusCore(String id, ItemStatus status, Collaborator by) {
    final item = _requireItem(id);
    final now = _now();
    _replace(
      item.copyWith(
        status: status,
        statusBy: by,
        statusAt: now,
        updatedAt: now,
      ),
    );
  }

  void _setFlagCore(String id, ItemFlag? flag, Collaborator by) {
    final item = _requireItem(id);
    _replace(
      item.copyWith(
        flag: flag,
        flagBy: flag == null ? null : by,
        reactions: flag == null ? const <Collaborator>[] : item.reactions,
        updatedAt: _now(),
      ),
    );
  }

  void _reactCore(String id, Collaborator by) {
    final item = _requireItem(id);
    if (item.reactions.any((c) => c.id == by.id)) return;
    _replace(
      item.copyWith(
        reactions: <Collaborator>[...item.reactions, by],
        updatedAt: _now(),
      ),
    );
  }

  void _deleteCore(String id, Collaborator by) {
    final item = _requireItem(id);
    _replace(
      item.copyWith(isDeleted: true, deletedBy: by, updatedAt: _now()),
    );
  }

  void _restoreCore(String id) {
    final item = _requireItem(id);
    _replace(
      item.copyWith(isDeleted: false, deletedBy: null, updatedAt: _now()),
    );
  }

  void _clearDoneCore(Collaborator by) {
    final now = _now();
    final doneIds = _list.done.map((i) => i.id).toSet();
    if (doneIds.isEmpty) return;
    _list = _list.copyWith(
      items: <GroceryItem>[
        for (final i in _list.items)
          if (doneIds.contains(i.id))
            i.copyWith(isDeleted: true, deletedBy: by, updatedAt: now)
          else
            i,
      ],
    );
    _emit();
  }

  // --- helpers ---------------------------------------------------------------

  GroceryItem _requireItem(String id) {
    for (final i in _list.items) {
      if (i.id == id) return i;
    }
    throw StateError('No grocery item with id "$id"');
  }

  GroceryItem? _activeByName(String name) {
    final lower = name.toLowerCase();
    for (final i in _list.items) {
      if (!i.isDeleted && i.name.toLowerCase() == lower) return i;
    }
    return null;
  }

  void _replace(GroceryItem updated) {
    _list = _list.copyWith(
      items: <GroceryItem>[
        for (final i in _list.items)
          if (i.id == updated.id) updated else i,
      ],
    );
    _emit();
  }

  void _emit() {
    if (!_listController.isClosed) _listController.add(_list);
  }

  void _emitPresence() {
    if (!_presenceController.isClosed) {
      _presenceController.add(_shoppers.values.toList());
    }
  }

  String _nextId() => 'itm_${_seq++}_${_now().microsecondsSinceEpoch}';

  // --- simulated collaborator ------------------------------------------------

  void _maybeStartSimulation() {
    if (_simStarted || !_demo) return;
    _simStarted = true;
    const dana = GrocerySeed.dana;
    _schedule(const Duration(milliseconds: 1800), () => _simEnter(dana));
    _schedule(const Duration(milliseconds: 3800), () => _simGrab(dana));
    _schedule(const Duration(seconds: 6), () => _simFlag(dana));
    _schedule(const Duration(seconds: 9), () => _simComplete(dana));
    _schedule(const Duration(seconds: 22), () => _simLeave(dana));
    _ttlTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_shoppers.containsKey(GrocerySeed.dana.id)) {
        _lastSeen[GrocerySeed.dana.id] = _now();
      }
      pruneStalePresence();
    });
  }

  void _schedule(Duration delay, void Function() action) =>
      _simTimers.add(Timer(delay, action));

  void _simEnter(Collaborator who) {
    final now = _now();
    _shoppers[who.id] = Shopper(collaborator: who, since: now);
    _lastSeen[who.id] = now;
    _emitPresence();
  }

  void _simLeave(Collaborator who) {
    _shoppers.remove(who.id);
    _lastSeen.remove(who.id);
    _emitPresence();
  }

  void _simGrab(Collaborator who) {
    final target = _firstActiveNeeded(excludeId: null);
    if (target == null) return;
    _simGrabbedId = target.id;
    _setStatusCore(target.id, ItemStatus.inCart, who);
  }

  void _simFlag(Collaborator who) {
    final target = _firstActiveNeeded(excludeId: _simGrabbedId);
    if (target == null) return;
    _setFlagCore(target.id, ItemFlag.outOfStock, who);
  }

  void _simComplete(Collaborator who) {
    final id = _simGrabbedId;
    if (id != null) _setStatusCore(id, ItemStatus.done, who);
  }

  GroceryItem? _firstActiveNeeded({required String? excludeId}) {
    for (final i in _list.active) {
      if (i.id != excludeId &&
          i.status == ItemStatus.needed &&
          i.flag == null) {
        return i;
      }
    }
    return null;
  }

  // Sentence-cases a freshly typed name ("olive oil" -> "Olive oil") to match
  // the seed style, without mangling the user's own capitalisation mid-word.
  static String _titleCase(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}
