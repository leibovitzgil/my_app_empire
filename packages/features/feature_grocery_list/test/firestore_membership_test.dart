import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FirestoreGroceryRepository membership', () {
    const listId = 'household';
    final now = DateTime(2026, 6, 28, 12);
    late FakeFirebaseFirestore firestore;
    late FirestoreGroceryRepository repo;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      repo = FirestoreGroceryRepository(
        firestore: firestore,
        listId: listId,
        clock: () => now,
      );
    });

    Future<void> seedOwner() => firestore
        .collection('households')
        .doc(listId)
        .collection('members')
        .doc('me')
        .set(<String, dynamic>{
          'collaborator': <String, dynamic>{
            'id': 'me',
            'name': 'You',
            'colorValue': 0xFF3B82F6,
          },
          'role': 'owner',
          'status': 'active',
          'since': Timestamp.fromDate(now),
        });

    test(
      'inviteByEmail writes a pending member, watchMembers streams it',
      () async {
        final result = await repo.inviteByEmail('dana.lee@example.com');
        expect(result.isSuccess, isTrue);

        final members = await repo.watchMembers().first;
        expect(members.length, 1);
        expect(members.single.status, MemberStatus.invited);
        expect(members.single.collaborator.name, 'Dana Lee');
      },
    );

    test('inviteByEmail is idempotent by email', () async {
      await repo.inviteByEmail('a@example.com');
      await repo.inviteByEmail('A@example.com');
      final members = await repo.watchMembers().first;
      expect(members.length, 1);
    });

    test('inviteByEmail rejects an invalid email', () async {
      final result = await repo.inviteByEmail('nope');
      expect(result.isSuccess, isFalse);
    });

    test('removeMember deletes an editor', () async {
      final member = (await repo.inviteByEmail('e@example.com')).valueOrNull!;
      await repo.removeMember(member.collaborator.id);
      final members = await repo.watchMembers().first;
      expect(members, isEmpty);
    });

    test('removeMember refuses to remove the owner', () async {
      await seedOwner();
      final result = await repo.removeMember('me');
      expect(result.isSuccess, isFalse);

      final members = await repo.watchMembers().first;
      expect(members.any((m) => m.collaborator.id == 'me'), isTrue);
    });
  });
}
