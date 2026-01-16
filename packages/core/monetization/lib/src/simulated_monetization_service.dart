import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';
import 'monetization_service.dart';

/// A mock implementation of [MonetizationService] for testing and debugging.
/// Allows simulating "Pro" status without real payments.
class SimulatedMonetizationService implements MonetizationService {
  final StreamController<CustomerInfo> _customerInfoController =
      StreamController<CustomerInfo>.broadcast();

  final StreamController<bool> _isProStreamController =
      StreamController<bool>.broadcast();

  bool _isPro = false;

  // Expose a setter to toggle status for debugging
  void setProStatus(bool isPro) {
    _isPro = isPro;
    _isProStreamController.add(_isPro);
  }

  @override
  Stream<CustomerInfo> get customerInfoStream => _customerInfoController.stream;

  @override
  Future<void> initialize(String apiKey, {String? appUserId}) async {
    // No-op
  }

  @override
  Future<void> logIn(String appUserId) async {
    // No-op
  }

  @override
  Future<void> logOut() async {
    setProStatus(false);
  }

  @override
  Future<Offerings?> getOfferings() async {
    // Return mock offerings if needed, or null.
    return null;
  }

  @override
  Future<CustomerInfo?> purchasePackage(Package package) async {
    setProStatus(true);
    return null; // Return null as we can't easily manufacture a CustomerInfo
  }

  @override
  Future<CustomerInfo?> purchaseMonthly() async {
    setProStatus(true);
    return null;
  }

  @override
  Future<CustomerInfo?> purchaseAnnual() async {
    setProStatus(true);
    return null;
  }

  @override
  Future<CustomerInfo?> restorePurchases() async {
    setProStatus(true);
    return null;
  }

  @override
  Future<bool> isProUser({String entitlementIdentifier = 'pro'}) async {
    return _isPro;
  }

  @override
  Stream<bool> isProUserStream({String entitlementIdentifier = 'pro'}) {
    // Return a stream that starts with the current value
    // We create a new controller that emits current value on listen, then pipes events
    StreamController<bool> controller = StreamController<bool>();
    controller.onListen = () {
      controller.add(_isPro);
      final subscription = _isProStreamController.stream.listen(controller.add);
      controller.onCancel = () {
        subscription.cancel();
      };
    };
    return controller.stream;
  }
}
