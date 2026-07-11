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
  });
}
