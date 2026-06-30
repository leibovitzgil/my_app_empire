import 'package:core_utils/core_utils.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InMemoryGroceryRepository membership', () {
    final now = DateTime(2026, 6, 28, 12);
    late InMemoryGroceryRepository repo;

    setUp(() {
      repo = InMemoryGroceryRepository(demo: false, clock: () => now);
    });
    tearDown(() async => repo.dispose());

    test('seeds the household roster with you as owner', () async {
      final members = await repo.watchMembers().first;
      expect(members.length, 3);
      final you = members.firstWhere((m) => m.collaborator.id == 'me');
      expect(you.role, MemberRole.owner);
      expect(you.status, MemberStatus.active);
      expect(members.where((m) => m.isOwner).length, 1);
    });

    test('inviteByEmail adds a pending editor', () async {
      final result = await repo.inviteByEmail('jordan.lee@example.com');
      expect(result.isSuccess, isTrue);
      final member = result.valueOrNull!;
      expect(member.status, MemberStatus.invited);
      expect(member.role, MemberRole.editor);
      expect(member.collaborator.name, 'Jordan Lee');

      final members = await repo.watchMembers().first;
      expect(members.any((m) => m.collaborator.name == 'Jordan Lee'), isTrue);
    });

    test('inviteByEmail is idempotent by email (case-insensitive)', () async {
      await repo.inviteByEmail('sam2@example.com');
      await repo.inviteByEmail('SAM2@example.com');
      final members = await repo.watchMembers().first;
      expect(
        members.where((m) => m.collaborator.id == 'sam2@example.com').length,
        1,
      );
    });

    test('inviteByEmail rejects an invalid email', () async {
      final result = await repo.inviteByEmail('not-an-email');
      expect(result.isSuccess, isFalse);
      expect(
        (result as ResultFailure<ListMember>).error,
        isA<MembershipException>(),
      );
    });

    test('removeMember removes an invited editor', () async {
      final invited = (await repo.inviteByEmail('x@example.com')).valueOrNull!;
      final result = await repo.removeMember(invited.collaborator.id);
      expect(result.isSuccess, isTrue);

      final members = await repo.watchMembers().first;
      expect(
        members.any((m) => m.collaborator.id == invited.collaborator.id),
        isFalse,
      );
    });

    test('removeMember refuses to remove the owner', () async {
      final result = await repo.removeMember('me');
      expect(result.isSuccess, isFalse);

      final members = await repo.watchMembers().first;
      expect(members.any((m) => m.collaborator.id == 'me'), isTrue);
    });

    test('watchMembers pushes live updates as a stream', () async {
      final emissions = <List<ListMember>>[];
      final sub = repo.watchMembers().listen(emissions.add);

      await repo.inviteByEmail('live@example.com');
      await pumpEventQueue();

      expect(
        emissions.last.any((m) => m.collaborator.id == 'live@example.com'),
        isTrue,
      );
      await sub.cancel();
    });

    test('inviteLink points at the shared list', () {
      expect(repo.inviteLink(), 'https://tandem.app/join/household');
    });
  });
}
