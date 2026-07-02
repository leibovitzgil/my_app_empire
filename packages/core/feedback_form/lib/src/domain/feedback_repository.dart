import 'package:core_utils/core_utils.dart';
import 'package:feedback_form/src/domain/feedback_entry.dart';

/// Contract for submitting user feedback to a backend. Kept as an abstract
/// class (rather than a top-level function) so apps can swap implementations
/// via DI, matching the repository seam used across this factory.
// ignore: one_member_abstracts
abstract class FeedbackRepository {
  /// Submits [feedback]. Succeeds with no value, or fails with the captured
  /// error.
  Future<Result<void>> submitFeedback(FeedbackEntry feedback);
}
