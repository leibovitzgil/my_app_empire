import 'dart:async';
import 'dart:developer' as developer;

import 'package:monetization/src/monetization_service.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:rxdart/rxdart.dart';

class RevenueCatService implements MonetizationService {
  RevenueCatService() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      if (!_customerInfoSubject.isClosed) {
        _customerInfoSubject.add(customerInfo);
      }
    });

    // Also try to fetch initial info
    unawaited(_fetchInitialCustomerInfo());
  }
  final BehaviorSubject<CustomerInfo> _customerInfoSubject =
      BehaviorSubject<CustomerInfo>();

  Future<void> _fetchInitialCustomerInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      if (!_customerInfoSubject.isClosed) {
        _customerInfoSubject.add(info);
      }
    } on Object catch (_) {
      // Ignore initial fetch error
    }
  }

  @override
  Stream<CustomerInfo> get customerInfoStream => _customerInfoSubject.stream;

  @override
  Future<void> initialize(String apiKey, {String? appUserId}) async {
    await Purchases.setLogLevel(LogLevel.debug);

    final configuration = PurchasesConfiguration(apiKey);
    if (appUserId != null) {
      configuration.appUserID = appUserId;
    }

    await Purchases.configure(configuration);

    // Refresh info after config
    await _fetchInitialCustomerInfo();
  }

  @override
  Future<void> logIn(String appUserId) async {
    await Purchases.logIn(appUserId);
    await _fetchInitialCustomerInfo();
  }

  @override
  Future<void> logOut() async {
    await Purchases.logOut();
    await _fetchInitialCustomerInfo();
  }

  @override
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } on Object catch (e, s) {
      developer.log(
        'getOfferings failed',
        name: 'monetization',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  @override
  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return result.customerInfo;
    } on Object catch (e, s) {
      developer.log(
        'purchasePackage failed',
        name: 'monetization',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  @override
  Future<CustomerInfo?> purchaseMonthly() async {
    final offerings = await getOfferings();
    final monthly = offerings?.current?.monthly;
    if (monthly != null) {
      return purchasePackage(monthly);
    }
    return null;
  }

  @override
  Future<CustomerInfo?> purchaseAnnual() async {
    final offerings = await getOfferings();
    final annual = offerings?.current?.annual;
    if (annual != null) {
      return purchasePackage(annual);
    }
    return null;
  }

  @override
  Future<CustomerInfo?> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } on Object catch (e, s) {
      developer.log(
        'restorePurchases failed',
        name: 'monetization',
        error: e,
        stackTrace: s,
      );
      return null;
    }
  }

  @override
  Future<bool> isProUser({String entitlementIdentifier = 'pro'}) async {
    try {
      // Prefer the cached value from the listener; otherwise fetch fresh.
      if (_customerInfoSubject.hasValue) {
        return _customerInfoSubject
                .value
                .entitlements
                .all[entitlementIdentifier]
                ?.isActive ??
            false;
      }

      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[entitlementIdentifier]?.isActive ??
          false;
    } on Object {
      return false;
    }
  }

  @override
  Stream<bool> isProUserStream({String entitlementIdentifier = 'pro'}) {
    return _customerInfoSubject.stream
        .map(
          (info) =>
              info.entitlements.all[entitlementIdentifier]?.isActive ?? false,
        )
        .distinct();
  }

  void dispose() {
    unawaited(_customerInfoSubject.close());
  }
}
