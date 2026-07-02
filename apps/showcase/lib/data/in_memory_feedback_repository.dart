import 'package:core_utils/core_utils.dart';
import 'package:feedback_form/feedback_form.dart';

/// An in-memory [FeedbackRepository] so the showcase runs without a real
/// backend.
class InMemoryFeedbackRepository implements FeedbackRepository {
  final List<FeedbackEntry> submissions = [];

  @override
  Future<Result<void>> submitFeedback(FeedbackEntry feedback) async {
    submissions.add(feedback);
    return const Success<void>(null);
  }
}
