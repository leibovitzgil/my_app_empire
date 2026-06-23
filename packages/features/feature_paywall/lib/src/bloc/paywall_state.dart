part of 'paywall_bloc.dart';

enum PaywallStatus { initial, loading, ready, purchasing, purchased, failure }

final class PaywallState extends Equatable {
  const PaywallState({
    this.status = PaywallStatus.initial,
    this.packages = const [],
    this.error,
  });

  final PaywallStatus status;
  final List<Package> packages;
  final String? error;

  PaywallState copyWith({
    PaywallStatus? status,
    List<Package>? packages,
    String? error,
  }) {
    return PaywallState(
      status: status ?? this.status,
      packages: packages ?? this.packages,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, packages, error];
}
