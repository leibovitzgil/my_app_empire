import 'package:flutter_test/flutter_test.dart';
import 'package:user_roles/user_roles.dart';

void main() {
  group('AppRole', () {
    test('admin ranks above member and guest', () {
      expect(AppRole.admin >= AppRole.member, isTrue);
      expect(AppRole.admin >= AppRole.guest, isTrue);
      expect(AppRole.member >= AppRole.guest, isTrue);
    });

    test('admin strictly outranks member and guest', () {
      expect(AppRole.admin > AppRole.member, isTrue);
      expect(AppRole.admin > AppRole.guest, isTrue);
      expect(AppRole.member > AppRole.guest, isTrue);
    });

    test('guest does not outrank member or admin', () {
      expect(AppRole.guest >= AppRole.member, isFalse);
      expect(AppRole.guest > AppRole.member, isFalse);
      expect(AppRole.guest <= AppRole.member, isTrue);
      expect(AppRole.guest < AppRole.member, isTrue);
    });

    test('a role is >= and <= itself, but not > or < itself', () {
      expect(AppRole.member >= AppRole.member, isTrue);
      expect(AppRole.member <= AppRole.member, isTrue);
      expect(AppRole.member > AppRole.member, isFalse);
      expect(AppRole.member < AppRole.member, isFalse);
    });

    test('equality is based on name and rank', () {
      const a = AppRole.member;
      const b = AppRole.member;
      const c = AppRole(name: 'member', rank: 11);
      const d = AppRole(name: 'moderator', rank: 10);

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });

    test('defaults contains guest, member, admin, lowest rank first', () {
      expect(AppRole.defaults, [AppRole.guest, AppRole.member, AppRole.admin]);
    });
  });
}
