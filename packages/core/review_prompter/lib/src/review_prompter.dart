import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewPrompter {
  static const String _kAppOpenCountKey = 'review_prompter_app_open_count';
  static const String _kCoreActionCompletedKey = 'review_prompter_core_action_completed';
  static const String _kReviewRequestedKey = 'review_prompter_review_requested';

  final InAppReview _inAppReview;
  final SharedPreferences _prefs;

  ReviewPrompter({
    InAppReview? inAppReview,
    required SharedPreferences prefs,
  })  : _inAppReview = inAppReview ?? InAppReview.instance,
        _prefs = prefs;

  /// Increments the app open count and checks if the review prompt should be shown.
  /// Should be called on app startup.
  Future<void> incrementAppOpenCount() async {
    final currentCount = _prefs.getInt(_kAppOpenCountKey) ?? 0;
    await _prefs.setInt(_kAppOpenCountKey, currentCount + 1);
    await _tryPrompt();
  }

  /// Logs that a core action has been completed and checks if the review prompt should be shown.
  Future<void> logCoreActionCompleted() async {
    await _prefs.setBool(_kCoreActionCompletedKey, true);
    await _tryPrompt();
  }

  /// Internal method to check conditions and prompt if appropriate.
  Future<void> _tryPrompt() async {
    // If we already requested a review, don't ask again.
    final alreadyRequested = _prefs.getBool(_kReviewRequestedKey) ?? false;
    if (alreadyRequested) return;

    final openCount = _prefs.getInt(_kAppOpenCountKey) ?? 0;
    final coreActionCompleted = _prefs.getBool(_kCoreActionCompletedKey) ?? false;

    // Logic: 5 opens AND core action completed
    if (openCount >= 5 && coreActionCompleted) {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.requestReview();
        // Mark as requested so we don't spam the user.
        await _prefs.setBool(_kReviewRequestedKey, true);
      }
    }
  }
}
