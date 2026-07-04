part of 'pairing_bloc.dart';

enum PairingStatus { initial, loading, loaded, failure }

final class PairingState extends Equatable {
  const PairingState._({
    this.status = PairingStatus.initial,
    this.value,
    this.error,
  });

  const PairingState.initial() : this._();

  const PairingState.loading() : this._(status: PairingStatus.loading);

  const PairingState.loaded(String value)
    : this._(status: PairingStatus.loaded, value: value);

  const PairingState.failure(String error)
    : this._(status: PairingStatus.failure, error: error);

  final PairingStatus status;
  final String? value;
  final String? error;

  @override
  List<Object?> get props => [status, value, error];
}
