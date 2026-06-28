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

    testWidgets('shows social buttons only when callbacks are provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(onEmailSignIn: (_, _) {}),
        ),
      );

      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Continue with Apple'), findsNothing);

      var google = 0;
      var apple = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SignInView(
            onEmailSignIn: (_, _) {},
            onGoogleSignIn: () => google++,
            onAppleSignIn: () => apple++,
          ),
        ),
      );

      final googleBtn = find.text('Continue with Google');
      final appleBtn = find.text('Continue with Apple');
      expect(googleBtn, findsOneWidget);
      expect(appleBtn, findsOneWidget);

      await tester.ensureVisible(googleBtn);
      await tester.tap(googleBtn);
      await tester.ensureVisible(appleBtn);
      await tester.tap(appleBtn);
      await tester.pumpAndSettle();

      expect(google, 1);
      expect(apple, 1);
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
  });
}
