import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget banner) {
  return MaterialApp(
    home: Scaffold(
      body: Column(children: [banner]),
    ),
  );
}

const _unverified = AuthAccount(uid: 'u1', email: 'a@b.com');
const _verified = AuthAccount(uid: 'u1', email: 'a@b.com', emailVerified: true);

void main() {
  group('EmailVerificationBanner', () {
    testWidgets('shows for an unverified account and hides once verified', (
      tester,
    ) async {
      final accounts = StreamController<AuthAccount?>.broadcast();
      addTearDown(accounts.close);
      await tester.pumpWidget(
        _wrap(
          EmailVerificationBanner(
            accounts: accounts.stream,
            onResend: () async => const Success(null),
            onRefresh: () async {},
          ),
        ),
      );

      accounts.add(_unverified);
      await tester.pumpAndSettle();
      expect(find.textContaining('Verify your email'), findsOneWidget);

      accounts.add(_verified);
      await tester.pumpAndSettle();
      expect(find.textContaining('Verify your email'), findsNothing);
    });

    testWidgets('renders nothing while signed out', (tester) async {
      final accounts = StreamController<AuthAccount?>.broadcast();
      addTearDown(accounts.close);
      await tester.pumpWidget(
        _wrap(
          EmailVerificationBanner(
            accounts: accounts.stream,
            onResend: () async => const Success(null),
            onRefresh: () async {},
          ),
        ),
      );

      accounts.add(null);
      await tester.pump();
      expect(find.textContaining('Verify your email'), findsNothing);
    });

    testWidgets('dismiss hides it for the session', (tester) async {
      final accounts = StreamController<AuthAccount?>.broadcast();
      addTearDown(accounts.close);
      await tester.pumpWidget(
        _wrap(
          EmailVerificationBanner(
            accounts: accounts.stream,
            onResend: () async => const Success(null),
            onRefresh: () async {},
          ),
        ),
      );

      accounts.add(_unverified);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dismiss'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Verify your email'), findsNothing);

      // Still hidden on later (unverified) emissions this session.
      accounts.add(_unverified);
      await tester.pumpAndSettle();
      expect(find.textContaining('Verify your email'), findsNothing);
    });

    testWidgets('resend calls onResend and confirms via snackbar', (
      tester,
    ) async {
      var resends = 0;
      final accounts = StreamController<AuthAccount?>.broadcast();
      addTearDown(accounts.close);
      await tester.pumpWidget(
        _wrap(
          EmailVerificationBanner(
            accounts: accounts.stream,
            onResend: () async {
              resends++;
              return const Success(null);
            },
            onRefresh: () async {},
          ),
        ),
      );

      accounts.add(_unverified);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resend'));
      await tester.pumpAndSettle();

      expect(resends, 1);
      expect(find.text('Verification email sent.'), findsOneWidget);
    });

    testWidgets('a failed resend surfaces the failure message', (
      tester,
    ) async {
      final accounts = StreamController<AuthAccount?>.broadcast();
      addTearDown(accounts.close);
      await tester.pumpWidget(
        _wrap(
          EmailVerificationBanner(
            accounts: accounts.stream,
            onResend: () async => const ResultFailure(AuthFailure.network()),
            onRefresh: () async {},
          ),
        ),
      );

      accounts.add(_unverified);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resend'));
      await tester.pumpAndSettle();

      expect(
        find.text('No connection. Check your network and retry.'),
        findsOneWidget,
      );
    });

    testWidgets('app resume triggers onRefresh', (tester) async {
      var refreshes = 0;
      final accounts = StreamController<AuthAccount?>.broadcast();
      addTearDown(accounts.close);
      await tester.pumpWidget(
        _wrap(
          EmailVerificationBanner(
            accounts: accounts.stream,
            onResend: () async => const Success(null),
            onRefresh: () async => refreshes++,
          ),
        ),
      );

      tester.binding.handleAppLifecycleStateChanged(
        AppLifecycleState.resumed,
      );
      await tester.pump();

      expect(refreshes, 1);
    });
  });
}
