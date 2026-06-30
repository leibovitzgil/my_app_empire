import 'package:feature_grocery_list/src/data/invite_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('invite identity', () {
    test('isValidEmail accepts plausible addresses and rejects junk', () {
      expect(isValidEmail('a@b.com'), isTrue);
      expect(isValidEmail('  dana.lee@example.co.uk '), isTrue);
      expect(isValidEmail('nope'), isFalse);
      expect(isValidEmail('a@b'), isFalse);
      expect(isValidEmail('a @b.com'), isFalse);
      expect(isValidEmail(''), isFalse);
    });

    test('collaboratorForEmail is deterministic, normalized and titled', () {
      final a = collaboratorForEmail('dana.lee@example.com');
      final b = collaboratorForEmail('DANA.LEE@example.com');
      expect(a.id, 'dana.lee@example.com');
      expect(a.name, 'Dana Lee');
      expect(a, b); // same identity + avatar colour regardless of case
    });

    test('a single-word local part still gets a name', () {
      expect(collaboratorForEmail('sam@x.com').name, 'Sam');
    });
  });
}
