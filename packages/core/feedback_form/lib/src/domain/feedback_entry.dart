import 'package:equatable/equatable.dart';

/// A single piece of user feedback: a star [rating] and a free-text
/// [message].
///
/// Named `FeedbackEntry` rather than `Feedback` to avoid colliding with
/// Flutter's built-in `Feedback` (haptic/sound feedback) widget class.
class FeedbackEntry extends Equatable {
  /// Creates feedback. [rating] must be between 1 and 5 inclusive; [message]
  /// must not be empty.
  const FeedbackEntry({required this.message, required this.rating})
    : assert(rating >= 1 && rating <= 5, 'rating must be between 1 and 5'),
      assert(message != '', 'message must not be empty');

  /// The free-text feedback message.
  final String message;

  /// The star rating, from 1 to 5.
  final int rating;

  @override
  List<Object?> get props => [message, rating];
}
