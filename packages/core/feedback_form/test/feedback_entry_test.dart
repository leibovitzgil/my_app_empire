import 'package:feedback_form/feedback_form.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FeedbackEntry', () {
    test('supports value equality', () {
      expect(
        const FeedbackEntry(message: 'Great app', rating: 5),
        const FeedbackEntry(message: 'Great app', rating: 5),
      );
    });

    test('differs when message or rating differ', () {
      expect(
        const FeedbackEntry(message: 'Great app', rating: 5),
        isNot(const FeedbackEntry(message: 'Great app', rating: 4)),
      );
      expect(
        const FeedbackEntry(message: 'Great app', rating: 5),
        isNot(const FeedbackEntry(message: 'Meh', rating: 5)),
      );
    });

    test('asserts rating is between 1 and 5', () {
      expect(
        () => FeedbackEntry(message: 'x', rating: 0),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => FeedbackEntry(message: 'x', rating: 6),
        throwsA(isA<AssertionError>()),
      );
    });

    test('asserts message is not empty', () {
      expect(
        () => FeedbackEntry(message: '', rating: 3),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}
