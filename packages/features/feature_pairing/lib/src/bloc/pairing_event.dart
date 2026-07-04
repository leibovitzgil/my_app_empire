part of 'pairing_bloc.dart';

sealed class PairingEvent extends Equatable {
  const PairingEvent();

  @override
  List<Object?> get props => [];
}

final class PairingRequested extends PairingEvent {
  const PairingRequested();
}
