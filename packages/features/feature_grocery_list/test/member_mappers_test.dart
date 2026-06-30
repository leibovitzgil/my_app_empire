import 'package:feature_grocery_list/feature_grocery_list.dart';
import 'package:feature_grocery_list/src/data/firestore_mappers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ListMember round-trips through Firestore maps', () {
    final member = ListMember(
      collaborator: const Collaborator(
        id: 'pat@example.com',
        name: 'Pat',
        colorValue: 0xFF8B5CF6,
      ),
      role: MemberRole.editor,
      status: MemberStatus.invited,
      since: DateTime(2026, 6, 28, 12),
    );

    final restored = memberFromMap(memberToMap(member));

    expect(restored, member);
  });

  test('unknown role/status names fall back to sensible defaults', () {
    expect(roleFromName('bogus'), MemberRole.editor);
    expect(roleFromName('owner'), MemberRole.owner);
    expect(memberStatusFromName(null), MemberStatus.active);
    expect(memberStatusFromName('invited'), MemberStatus.invited);
  });
}
