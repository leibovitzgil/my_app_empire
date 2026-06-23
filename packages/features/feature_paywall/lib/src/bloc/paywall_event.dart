part of 'paywall_bloc.dart';

sealed class PaywallEvent extends Equatable {
  const PaywallEvent();

  @override
  List<Object?> get props => [];
}

/// Load the available offerings.
final class PaywallStarted extends PaywallEvent {
  const PaywallStarted();
}

/// Purchase a specific [package].
final class PaywallPackagePurchased extends PaywallEvent {
  const PaywallPackagePurchased(this.package);

  final Package package;

  @override
  List<Object?> get props => [package];
}

/// Restore previous purchases.
final class PaywallRestoreRequested extends PaywallEvent {
  const PaywallRestoreRequested();
}
