import 'package:core_ui/core_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSpacing', () {
    test('exposes the expected scale', () {
      expect(AppSpacing.xs, 4);
      expect(AppSpacing.sm, 8);
      expect(AppSpacing.md, 16);
      expect(AppSpacing.lg, 24);
      expect(AppSpacing.xl, 32);
    });
  });

  group('AppRadii', () {
    test('exposes the expected scale', () {
      expect(AppRadii.sm, 8);
      expect(AppRadii.md, 12);
      expect(AppRadii.card, 16);
    });
  });
}
