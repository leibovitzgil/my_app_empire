/// Thrown (surfaced via a `Result` failure) when a participant attempts to
/// modify or delete an annotation they do not own — e.g. a student erasing
/// the teacher's ink stroke.
class OwnershipViolation implements Exception {
  /// Creates an [OwnershipViolation] for [resourceId].
  const OwnershipViolation(this.resourceId, {this.reason});

  /// The id of the resource (stroke, audio note, ...) the caller doesn't
  /// own.
  final String resourceId;

  /// Optional detail about the violation.
  final String? reason;

  @override
  String toString() =>
      'OwnershipViolation: not permitted on $resourceId'
      '${reason != null ? ' ($reason)' : ''}';
}
