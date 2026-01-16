import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:rxdart/rxdart.dart';
import 'monetization_service.dart';

class RevenueCatService implements MonetizationService {
  final BehaviorSubject<CustomerInfo> _customerInfoSubject = BehaviorSubject<CustomerInfo>();

  RevenueCatService() {
    Purchases.addCustomerInfoUpdateListener((customerInfo) {
      if (!_customerInfoSubject.isClosed) {
        _customerInfoSubject.add(customerInfo);
      }
    });

    // Also try to fetch initial info
    _fetchInitialCustomerInfo();
  }

  Future<void> _fetchInitialCustomerInfo() async {
    try {
      final info = await Purchases.getCustomerInfo();
      if (!_customerInfoSubject.isClosed) {
        _customerInfoSubject.add(info);
      }
    } catch (_) {
      // Ignore initial fetch error
    }
  }

  @override
  Stream<CustomerInfo> get customerInfoStream => _customerInfoSubject.stream;

  @override
  Future<void> initialize(String apiKey, {String? appUserId}) async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration configuration = PurchasesConfiguration(apiKey);
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
    } catch (e) {
      // TODO: Add proper error handling/logging
      return null;
    }
  }

  @override
  Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      return await Purchases.purchasePackage(package);
    } catch (e) {
      // TODO: Add proper error handling/logging
      return null;
    }
  }

  @override
  Future<CustomerInfo?> purchaseMonthly() async {
    final offerings = await getOfferings();
    final monthly = offerings?.current?.monthly;
    if (monthly != null) {
      return await purchasePackage(monthly);
    }
    return null;
  }

  @override
  Future<CustomerInfo?> purchaseAnnual() async {
    final offerings = await getOfferings();
    final annual = offerings?.current?.annual;
    if (annual != null) {
      return await purchasePackage(annual);
    }
    return null;
  }

  @override
  Future<CustomerInfo?> restorePurchases() async {
    try {
      return await Purchases.restorePurchases();
    } catch (e) {
      // TODO: Add proper error handling/logging
      return null;
    }
  }

  @override
  Future<bool> isProUser({String entitlementIdentifier = 'pro'}) async {
    try {
      // If we have a cached value in subject, check it first to avoid async delay if possible?
      // But method is async, so better fetch fresh.
      // However, usually we can rely on cached value if we trust the listener.
      // Let's stick to checking fresh info or latest from subject.
      if (_customerInfoSubject.hasValue) {
        return _customerInfoSubject.value.entitlements.all[entitlementIdentifier]?.isActive ?? false;
      }

      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.all[entitlementIdentifier]?.isActive ?? false;
    } catch (e) {
      return false;
    }
  }

  @override
  Stream<bool> isProUserStream({String entitlementIdentifier = 'pro'}) {
    return _customerInfoSubject.stream.map((info) =>
      info.entitlements.all[entitlementIdentifier]?.isActive ?? false
    ).distinct();
  }

  void dispose() {
    _customerInfoSubject.close();
  }
}
