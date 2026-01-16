import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:review_prompter/review_prompter.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockInAppReview extends Mock implements InAppReview {}
class MockSharedPreferences extends Mock implements SharedPreferences {}

void main() {
  late ReviewPrompter reviewPrompter;
  late MockInAppReview mockInAppReview;
  late MockSharedPreferences mockSharedPreferences;

  setUp(() {
    mockInAppReview = MockInAppReview();
    mockSharedPreferences = MockSharedPreferences();

    // Default mock behaviors
    when(() => mockInAppReview.isAvailable()).thenAnswer((_) async => true);
    when(() => mockInAppReview.requestReview()).thenAnswer((_) async => null);

    // Default shared prefs values (null means not set)
    when(() => mockSharedPreferences.getInt(any())).thenReturn(null);
    when(() => mockSharedPreferences.getBool(any())).thenReturn(null);
    when(() => mockSharedPreferences.setInt(any(), any())).thenAnswer((_) async => true);
    when(() => mockSharedPreferences.setBool(any(), any())).thenAnswer((_) async => true);

    reviewPrompter = ReviewPrompter(
      inAppReview: mockInAppReview,
      prefs: mockSharedPreferences,
    );
  });

  group('ReviewPrompter', () {
    test('increments app open count', () async {
      when(() => mockSharedPreferences.getInt('review_prompter_app_open_count')).thenReturn(0);

      await reviewPrompter.incrementAppOpenCount();

      verify(() => mockSharedPreferences.setInt('review_prompter_app_open_count', 1)).called(1);
    });

    test('does not prompt if conditions are not met (low opens)', () async {
      // Simulate count 3 -> 4
      int count = 3;
      when(() => mockSharedPreferences.getInt('review_prompter_app_open_count')).thenAnswer((_) => count);
      when(() => mockSharedPreferences.setInt('review_prompter_app_open_count', any())).thenAnswer((invocation) async {
        count = invocation.positionalArguments[1];
        return true;
      });
      when(() => mockSharedPreferences.getBool('review_prompter_core_action_completed')).thenReturn(true);

      await reviewPrompter.incrementAppOpenCount();

      // count is now 4. 4 < 5.
      verifyNever(() => mockInAppReview.requestReview());
    });

    test('does not prompt if conditions are not met (no core action)', () async {
      // Simulate count 4 -> 5
      int count = 4;
      when(() => mockSharedPreferences.getInt('review_prompter_app_open_count')).thenAnswer((_) => count);
      when(() => mockSharedPreferences.setInt('review_prompter_app_open_count', any())).thenAnswer((invocation) async {
        count = invocation.positionalArguments[1];
        return true;
      });
      when(() => mockSharedPreferences.getBool('review_prompter_core_action_completed')).thenReturn(false);

      await reviewPrompter.incrementAppOpenCount();

      verifyNever(() => mockInAppReview.requestReview());
    });

    test('prompts when app open count reaches 5 and core action is completed', () async {
      // Setup: Open count is 4, will become 5. Core action is true.
      int count = 4;
      when(() => mockSharedPreferences.getInt('review_prompter_app_open_count')).thenAnswer((_) => count);
      when(() => mockSharedPreferences.setInt('review_prompter_app_open_count', any())).thenAnswer((invocation) async {
        count = invocation.positionalArguments[1];
        return true;
      });
      when(() => mockSharedPreferences.getBool('review_prompter_core_action_completed')).thenReturn(true);

      await reviewPrompter.incrementAppOpenCount();

      verify(() => mockInAppReview.requestReview()).called(1);
      verify(() => mockSharedPreferences.setBool('review_prompter_review_requested', true)).called(1);
    });

    test('prompts when core action is completed and app open count is already 5+', () async {
      when(() => mockSharedPreferences.getInt('review_prompter_app_open_count')).thenReturn(6);
       // core action currently false/null
      bool coreAction = false;
      when(() => mockSharedPreferences.getBool('review_prompter_core_action_completed')).thenAnswer((_) => coreAction);
      when(() => mockSharedPreferences.setBool('review_prompter_core_action_completed', any())).thenAnswer((invocation) async {
         coreAction = invocation.positionalArguments[1];
         return true;
      });

      await reviewPrompter.logCoreActionCompleted();

      verify(() => mockInAppReview.requestReview()).called(1);
    });

    test('does not prompt if already requested', () async {
      when(() => mockSharedPreferences.getBool('review_prompter_review_requested')).thenReturn(true);
      when(() => mockSharedPreferences.getInt('review_prompter_app_open_count')).thenReturn(10);
      when(() => mockSharedPreferences.getBool('review_prompter_core_action_completed')).thenReturn(true);

      await reviewPrompter.incrementAppOpenCount();

      verifyNever(() => mockInAppReview.requestReview());
    });
  });
}
