/// A typed success-or-failure value, so repositories and services can surface
/// errors without throwing across boundaries.
sealed class Result<T> {
  const Result();

  /// Runs [action], returning [Success] with its value or [ResultFailure]
  /// capturing any thrown error.
  static Future<Result<T>> guard<T>(Future<T> Function() action) async {
    try {
      return Success<T>(await action());
    } on Object catch (error, stackTrace) {
      return ResultFailure<T>(error, stackTrace);
    }
  }

  /// Whether this is a [Success].
  bool get isSuccess => this is Success<T>;

  /// The value if this is a [Success], otherwise null.
  T? get valueOrNull => switch (this) {
    final Success<T> s => s.value,
    ResultFailure<T>() => null,
  };

  /// Folds both cases into a single value.
  R fold<R>(
    R Function(T value) onSuccess,
    R Function(Object error) onFailure,
  ) {
    return switch (this) {
      final Success<T> s => onSuccess(s.value),
      final ResultFailure<T> f => onFailure(f.error),
    };
  }
}

/// A successful [Result] carrying a [value].
final class Success<T> extends Result<T> {
  const Success(this.value);

  /// The success value.
  final T value;
}

/// A failed [Result] carrying the [error] and optional [stackTrace].
final class ResultFailure<T> extends Result<T> {
  const ResultFailure(this.error, [this.stackTrace]);

  /// The captured error.
  final Object error;

  /// The stack trace at the point of failure, if available.
  final StackTrace? stackTrace;
}

/// Convenience for bridging a nested [Result] call into an outer
/// `Result.guard` block, where the only way to propagate a failure is to
/// throw.
extension ResultUnwrap<T> on Result<T> {
  /// Returns the success value, or throws the captured failure. The error is
  /// rethrown as-is when it's already an [Exception] or [Error]; otherwise
  /// it's wrapped in a [StateError] (e.g. `Result`s in tests sometimes carry
  /// a plain `String`), so callers always satisfy `only_throw_errors`.
  T orThrow() {
    final self = this;
    if (self is Success<T>) return self.value;
    final error = (self as ResultFailure<T>).error;
    if (error is Exception) throw error;
    if (error is Error) throw error;
    throw StateError(error.toString());
  }
}
