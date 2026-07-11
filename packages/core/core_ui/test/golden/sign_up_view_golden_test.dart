@Tags(['golden'])
library;

import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// AppTheme.testTheme() is network-free (skips google_fonts) but still
// exercises the real token-driven sub-themes.
final ThemeData _theme = AppTheme.testTheme();
final ThemeData _darkTheme = AppTheme.testTheme(brightness: Brightness.dark);

Widget _wrap(ThemeData theme, Widget child) {
  return MaterialApp(theme: theme, home: child);
}

void main() {
  group('core_ui goldens', () {
    testWidgets('SignUpView (light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          SignUpView(
            title: 'Demo',
            logo: const AppLogoMark(icon: Icons.bolt),
            onSignUp: (_, _, _) {},
            onSignIn: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SignUpView),
        matchesGoldenFile('goldens/sign_up_view_light.png'),
      );
    });

    testWidgets('SignUpView (dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _darkTheme,
          SignUpView(
            title: 'Demo',
            logo: const AppLogoMark(icon: Icons.bolt),
            onSignUp: (_, _, _) {},
            onSignIn: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SignUpView),
        matchesGoldenFile('goldens/sign_up_view_dark.png'),
      );
    });

    testWidgets('SignUpView (error, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(
          _theme,
          SignUpView(
            title: 'Demo',
            onSignUp: (_, _, _) {},
            errorText: 'An account already exists for that email.',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(SignUpView),
        matchesGoldenFile('goldens/sign_up_view_error_light.png'),
      );
    });
  });
}
