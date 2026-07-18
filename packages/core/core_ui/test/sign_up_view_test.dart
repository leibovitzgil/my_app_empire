import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignUpView', () {
    testWidgets('submits entered name, email and password', (tester) async {
      String? email;
      String? password;
      String? name;

      await tester.pumpWidget(
        MaterialApp(
          home: SignUpView(
            title: 'Demo',
            logo: const AppLogoMark(icon: Icons.bolt),
            onSignUp: (e, p, n) {
              email = e;
              password = p;
              name = n;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), 'Jane Doe');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(2), 'pw');
      final submit = find.text('Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(email, 'a@b.com');
      expect(password, 'pw');
      expect(name, 'Jane Doe');
    });

    testWidgets('a blank name submits as null', (tester) async {
      String? name = 'sentinel';

      await tester.pumpWidget(
        MaterialApp(
          home: SignUpView(onSignUp: (_, _, n) => name = n),
        ),
      );

      await tester.enterText(find.byType(TextField).at(0), '   ');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.com');
      await tester.enterText(find.byType(TextField).at(2), 'pw');
      final submit = find.text('Create account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(name, isNull);
    });

    testWidgets('renders errorText', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpView(
            onSignUp: (_, _, _) {},
            errorText: 'Email in use',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Email in use'), findsOneWidget);
    });

    testWidgets('wires the back-to-sign-in footer when provided', (
      tester,
    ) async {
      var backTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpView(
            onSignUp: (_, _, _) {},
            onSignIn: () => backTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final back = find.text('I already have an account');
      expect(back, findsOneWidget);
      await tester.ensureVisible(back);
      await tester.tap(back);
      await tester.pumpAndSettle();

      expect(backTaps, 1);
    });

    testWidgets('omits the footer when onSignIn is absent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignUpView(onSignUp: (_, _, _) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('I already have an account'), findsNothing);
    });

    testWidgets('no consent checkbox is shown when consentLabel is absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(home: SignUpView(onSignUp: (_, _, _) {})),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('signUpConsentCheckbox')), findsNothing);
    });

    group('with a consentLabel (required acceptance)', () {
      Future<void> fillForm(WidgetTester tester) async {
        await tester.enterText(find.byType(TextField).at(1), 'a@b.com');
        await tester.enterText(find.byType(TextField).at(2), 'pw');
      }

      testWidgets('sign-up is blocked until the box is ticked', (tester) async {
        var signUps = 0;
        var consents = 0;
        await tester.pumpWidget(
          MaterialApp(
            home: SignUpView(
              consentLabel: const Text('I agree'),
              onConsentAccepted: () => consents++,
              onSignUp: (_, _, _) => signUps++,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await fillForm(tester);

        // Box unticked: tapping the (disabled) button does nothing.
        final submit = find.text('Create account');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(signUps, 0);
        expect(consents, 0);

        // Tick the box, then the same tap goes through.
        await tester.tap(find.byKey(const Key('signUpConsentCheckbox')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(signUps, 1);
        expect(consents, 1);
      });

      testWidgets('onConsentAccepted fires immediately before onSignUp', (
        tester,
      ) async {
        final calls = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: SignUpView(
              consentLabel: const Text('I agree'),
              onConsentAccepted: () => calls.add('consent'),
              onSignUp: (_, _, _) => calls.add('signup'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await fillForm(tester);
        await tester.tap(find.byKey(const Key('signUpConsentCheckbox')));
        await tester.pumpAndSettle();
        final submit = find.text('Create account');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();

        expect(calls, <String>['consent', 'signup']);
      });
    });
  });
}
