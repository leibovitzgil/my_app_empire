part of 'score_bloc.dart';

enum ScoreStatus { initial, loading, loaded, failure }

final class ScoreState extends Equatable {
  const ScoreState._({
    this.status = ScoreStatus.initial,
    this.value,
    this.error,
  });

  const ScoreState.initial() : this._();

  const ScoreState.loading() : this._(status: ScoreStatus.loading);

  const ScoreState.loaded(String value)
    : this._(status: ScoreStatus.loaded, value: value);

  const ScoreState.failure(String error)
    : this._(status: ScoreStatus.failure, error: error);

  final ScoreStatus status;
  final String? value;
  final String? error;

  @override
  List<Object?> get props => [status, value, error];
}
