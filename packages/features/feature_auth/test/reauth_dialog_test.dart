import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pumps a screen with a button that opens the dialog, recording the
/// credential each [reauthenticate] call carries and the dialog's result.
class _Harness {
  _Harness({this.failure});

  /// When set, the first [calls] fail with it; subsequent ones succeed.
  final AuthFailure? failure;

  final List<String?> calls = <String?>[];
  bool? dialogResult;

  Future<Result<void>> reauthenticate({String? password}) async {
    calls.add(password);
    if (failure != null && calls.length == 1) {
      return ResultFailure(failure!);
    }
    return const Success(null);
  }

  Widget build(AuthProviderKind provider) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                dialogResult = await showReauthDialog(
                  context,
                  provider: provider,
                  reauthenticate: reauthenticate,
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openDialog(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('ReauthDialog', () {
    testWidgets('password variant confirms with the entered password', (
      tester,
    ) async {
      final harness = _Harness();
      await _openDialog(tester, harness.build(AuthProviderKind.password));

      expect(find.text("Confirm it's you"), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(harness.calls, ['secret']);
      expect(harness.dialogResult, isTrue);
      expect(find.text("Confirm it's you"), findsNothing);
    });

    testWidgets('a wrong password renders inline and allows retry', (
      tester,
    ) async {
      final harness = _Harness(failure: const AuthFailure.invalidCredentials());
      await _openDialog(tester, harness.build(AuthProviderKind.password));

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      // Failure stays in the dialog as typed human copy.
      expect(find.text('Email or password is incorrect.'), findsOneWidget);
      expect(find.text("Confirm it's you"), findsOneWidget);

      // Retry succeeds (harness only fails the first call).
      await tester.enterText(find.byType(TextField), 'secret');
      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(harness.calls, ['nope', 'secret']);
      expect(harness.dialogResult, isTrue);
    });

    testWidgets('provider variant re-runs the flow without a password', (
      tester,
    ) async {
      final harness = _Harness();
      await _openDialog(tester, harness.build(AuthProviderKind.google));

      expect(find.byType(TextField), findsNothing);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(harness.calls, [null]);
      expect(harness.dialogResult, isTrue);
    });

    testWidgets('the Apple variant labels its button accordingly', (
      tester,
    ) async {
      final harness = _Harness();
      await _openDialog(tester, harness.build(AuthProviderKind.apple));

      expect(find.text('Continue with Apple'), findsOneWidget);
    });

    testWidgets('cancel resolves false without calling reauthenticate', (
      tester,
    ) async {
      final harness = _Harness();
      await _openDialog(tester, harness.build(AuthProviderKind.password));

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(harness.calls, isEmpty);
      expect(harness.dialogResult, isFalse);
    });
  });
}
