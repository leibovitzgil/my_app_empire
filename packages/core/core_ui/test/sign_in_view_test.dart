import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SignInView', () {
    testWidgets('submits entered email and password', (tester) async {
      String? email;
      String? password;

      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(
            title: 'Demo',
            logo: const AppLogoMark(icon: Icons.bolt),
            onEmailSignIn: (e, p) {
              email = e;
              password = p;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'a@b.com');
      await tester.enterText(find.byType(TextField).last, 'pw');
      final login = find.text('Log in');
      await tester.ensureVisible(login);
      await tester.tap(login);
      await tester.pumpAndSettle();

      expect(email, 'a@b.com');
      expect(password, 'pw');
    });

    testWidgets('renders no divider/social section when none provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(onEmailSignIn: (_, _) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LabeledDivider), findsNothing);
      expect(find.text('Continue with Google'), findsNothing);
    });

    testWidgets('lays out and wires provided social buttons', (tester) async {
      var google = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(
            onEmailSignIn: (_, _) {},
            socialButtons: [
              SocialSignInButton.google(onPressed: () => google++),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LabeledDivider), findsOneWidget);
      final googleBtn = find.text('Continue with Google');
      expect(googleBtn, findsOneWidget);

      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(google, 1);
    });

    testWidgets('renders errorText', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(
            onEmailSignIn: (_, _) {},
            errorText: 'Wrong password',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wrong password'), findsOneWidget);
    });

    testWidgets('wires the create-account footer when provided', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(
            onEmailSignIn: (_, _) {},
            onCreateAccount: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final create = find.text('Create account');
      expect(create, findsOneWidget);
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('omits the create-account footer when absent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(onEmailSignIn: (_, _) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create account'), findsNothing);
    });

    testWidgets('wires the forgot-password link when provided', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(
            onEmailSignIn: (_, _) {},
            onForgotPassword: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final forgot = find.text('Forgot password?');
      expect(forgot, findsOneWidget);
      await tester.ensureVisible(forgot);
      await tester.tap(forgot);
      await tester.pumpAndSettle();

      expect(taps, 1);
    });

    testWidgets('omits the forgot-password link when absent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(onEmailSignIn: (_, _) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Forgot password?'), findsNothing);
    });
  });
}
