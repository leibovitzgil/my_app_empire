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
  return MaterialApp(
    theme: theme,
    home: Scaffold(
      body: Center(child: child),
    ),
  );
}

const List<AvatarStackPerson> _twoPeople = [
  (initials: 'GL', color: Colors.indigo),
  (initials: 'AM', color: Colors.teal),
];

const List<AvatarStackPerson> _threePeople = [
  (initials: 'GL', color: Colors.indigo),
  (initials: 'AM', color: Colors.teal),
  (initials: 'JD', color: Colors.orange),
];

const List<AvatarStackPerson> _overflowPeople = [
  (initials: 'GL', color: Colors.indigo),
  (initials: 'AM', color: Colors.teal),
  (initials: 'JD', color: Colors.orange),
  (initials: 'RK', color: Colors.pink),
  (initials: 'SM', color: Colors.blue),
];

void main() {
  group('core_ui goldens', () {
    testWidgets('AvatarStack (2 people, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, const AvatarStack(people: _twoPeople)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AvatarStack),
        matchesGoldenFile('goldens/avatar_stack_two_light.png'),
      );
    });

    testWidgets('AvatarStack (3 people, dark)', (tester) async {
      await tester.pumpWidget(
        _wrap(_darkTheme, const AvatarStack(people: _threePeople)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AvatarStack),
        matchesGoldenFile('goldens/avatar_stack_three_dark.png'),
      );
    });

    testWidgets('AvatarStack (overflow +N, light)', (tester) async {
      await tester.pumpWidget(
        _wrap(_theme, const AvatarStack(people: _overflowPeople)),
      );
      await tester.pumpAndSettle();
      await expectLater(
        find.byType(AvatarStack),
        matchesGoldenFile('goldens/avatar_stack_overflow_light.png'),
      );
    });
  });
}
