import 'package:core_utils/core_utils.dart';
import 'package:feedback_form/feedback_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFeedbackRepository implements FeedbackRepository {
  _FakeFeedbackRepository({this.shouldFail = false});

  final bool shouldFail;
  FeedbackEntry? submitted;

  @override
  Future<Result<void>> submitFeedback(FeedbackEntry feedback) async {
    if (shouldFail) {
      return ResultFailure<void>(Exception('network error'));
    }
    submitted = feedback;
    return const Success<void>(null);
  }
}

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('FeedbackForm', () {
    testWidgets('shows a validation error when submitted empty', (
      tester,
    ) async {
      final repository = _FakeFeedbackRepository();

      await tester.pumpWidget(wrap(FeedbackForm(repository: repository)));
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();

      expect(
        find.text('Add a message and a star rating before submitting.'),
        findsOneWidget,
      );
      expect(repository.submitted, isNull);
    });

    testWidgets('submits the message and selected rating', (tester) async {
      final repository = _FakeFeedbackRepository();
      var submittedCalled = false;

      await tester.pumpWidget(
        wrap(
          FeedbackForm(
            repository: repository,
            onSubmitted: () => submittedCalled = true,
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Love the app!');
      await tester.tap(find.byKey(const ValueKey('feedback_star_4')));
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();

      expect(
        repository.submitted,
        const FeedbackEntry(message: 'Love the app!', rating: 4),
      );
      expect(submittedCalled, isTrue);
    });

    testWidgets('shows an error message when submission fails', (
      tester,
    ) async {
      final repository = _FakeFeedbackRepository(shouldFail: true);

      await tester.pumpWidget(wrap(FeedbackForm(repository: repository)));

      await tester.enterText(find.byType(TextField), 'Broken feature');
      await tester.tap(find.byKey(const ValueKey('feedback_star_2')));
      await tester.tap(find.text('Submit feedback'));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not send feedback. Please try again.'),
        findsOneWidget,
      );
    });
  });
}
