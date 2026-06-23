import 'package:bloc_test/bloc_test.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:monetization/monetization.dart';

class MockMonetizationService extends Mock implements MonetizationService {}

class MockOfferings extends Mock implements Offerings {}

class MockOffering extends Mock implements Offering {}

class MockPackage extends Mock implements Package {}

class MockCustomerInfo extends Mock implements CustomerInfo {}

void main() {
  setUpAll(() => registerFallbackValue(MockPackage()));

  group('PaywallBloc', () {
    late MonetizationService monetization;

    setUp(() => monetization = MockMonetizationService());

    PaywallBloc build() => PaywallBloc(monetizationService: monetization);

    test('initial state is initial', () {
      expect(build().state.status, PaywallStatus.initial);
    });

    blocTest<PaywallBloc, PaywallState>(
      'loads packages from the current offering',
      build: () {
        final package = MockPackage();
        final offering = MockOffering();
        final offerings = MockOfferings();
        when(() => offering.availablePackages).thenReturn([package]);
        when(() => offerings.current).thenReturn(offering);
        when(() => monetization.getOfferings())
            .thenAnswer((_) async => offerings);
        return build();
      },
      act: (bloc) => bloc.add(const PaywallStarted()),
      expect: () => [
        isA<PaywallState>()
            .having((s) => s.status, 'status', PaywallStatus.loading),
        isA<PaywallState>()
            .having((s) => s.status, 'status', PaywallStatus.ready)
            .having((s) => s.packages.length, 'packages', 1),
      ],
    );

    blocTest<PaywallBloc, PaywallState>(
      'emits [purchasing, purchased] on a successful purchase',
      build: () {
        when(() => monetization.purchasePackage(any()))
            .thenAnswer((_) async => MockCustomerInfo());
        return build();
      },
      act: (bloc) => bloc.add(PaywallPackagePurchased(MockPackage())),
      expect: () => [
        isA<PaywallState>()
            .having((s) => s.status, 'status', PaywallStatus.purchasing),
        isA<PaywallState>()
            .having((s) => s.status, 'status', PaywallStatus.purchased),
      ],
    );

    blocTest<PaywallBloc, PaywallState>(
      'emits [purchasing, failure] when the purchase returns null',
      build: () {
        when(() => monetization.purchasePackage(any()))
            .thenAnswer((_) async => null);
        return build();
      },
      act: (bloc) => bloc.add(PaywallPackagePurchased(MockPackage())),
      expect: () => [
        isA<PaywallState>()
            .having((s) => s.status, 'status', PaywallStatus.purchasing),
        isA<PaywallState>()
            .having((s) => s.status, 'status', PaywallStatus.failure),
      ],
    );
  });
}
