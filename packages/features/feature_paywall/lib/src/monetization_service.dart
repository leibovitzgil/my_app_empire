import 'package:purchases_flutter/purchases_flutter.dart';

abstract class MonetizationService {
  Future<void> initialize(String apiKey, {String? appUserId});

  Future<void> logIn(String appUserId);

  Future<void> logOut();

  Future<Offerings?> getOfferings();

  Future<CustomerInfo?> purchasePackage(Package package);

  /// Helper to purchase the monthly package from the current offering.
  Future<CustomerInfo?> purchaseMonthly();

  /// Helper to purchase the annual package from the current offering.
  Future<CustomerInfo?> purchaseAnnual();

  Future<CustomerInfo?> restorePurchases();

  Stream<CustomerInfo> get customerInfoStream;

  /// Checks if the user has the active entitlement (default: 'pro').
  Future<bool> isProUser({String entitlementIdentifier = 'pro'});

  /// Stream of pro user status.
  Stream<bool> isProUserStream({String entitlementIdentifier = 'pro'});
}
