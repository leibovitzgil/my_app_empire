import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:monetization/monetization.dart';

part 'paywall_event.dart';
part 'paywall_state.dart';

/// Drives the paywall: loads offerings and runs purchase/restore flows through
/// the [MonetizationService].
class PaywallBloc extends Bloc<PaywallEvent, PaywallState> {
  PaywallBloc({required MonetizationService monetizationService})
    : _monetization = monetizationService,
      super(const PaywallState()) {
    on<PaywallStarted>(_onStarted);
    on<PaywallPackagePurchased>(_onPurchased);
    on<PaywallRestoreRequested>(_onRestore);
  }

  final MonetizationService _monetization;

  Future<void> _onStarted(
    PaywallStarted event,
    Emitter<PaywallState> emit,
  ) async {
    emit(state.copyWith(status: PaywallStatus.loading));
    final offerings = await _monetization.getOfferings();
    final packages = offerings?.current?.availablePackages ?? const <Package>[];
    emit(state.copyWith(status: PaywallStatus.ready, packages: packages));
  }

  Future<void> _onPurchased(
    PaywallPackagePurchased event,
    Emitter<PaywallState> emit,
  ) async {
    emit(state.copyWith(status: PaywallStatus.purchasing));
    final info = await _monetization.purchasePackage(event.package);
    if (info != null) {
      emit(state.copyWith(status: PaywallStatus.purchased));
    } else {
      emit(
        state.copyWith(
          status: PaywallStatus.failure,
          error: 'Purchase could not be completed.',
        ),
      );
    }
  }

  Future<void> _onRestore(
    PaywallRestoreRequested event,
    Emitter<PaywallState> emit,
  ) async {
    emit(state.copyWith(status: PaywallStatus.purchasing));
    final info = await _monetization.restorePurchases();
    if (info != null) {
      emit(state.copyWith(status: PaywallStatus.purchased));
    } else {
      emit(
        state.copyWith(
          status: PaywallStatus.failure,
          error: 'Nothing to restore.',
        ),
      );
    }
  }
}
