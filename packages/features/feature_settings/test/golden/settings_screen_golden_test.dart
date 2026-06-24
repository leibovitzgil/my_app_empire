@Tags(['golden'])
library;

import 'package:bloc_test/bloc_test.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// A network-free theme (AppTheme pulls google_fonts, which fetches at runtime).
final _theme = ThemeData(useMaterial3: true);

class _StubSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

Future<void> _pump(WidgetTester tester, SettingsState state) async {
  final bloc = _StubSettingsBloc();
  whenListen(
    bloc,
    const Stream<SettingsState>.empty(),
    initialState: state,
  );
  await tester.pumpWidget(
    MaterialApp(
      theme: _theme,
      home: BlocProvider<SettingsBloc>.value(
        value: bloc,
        child: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('SettingsScreen goldens', () {
    testWidgets('off', (tester) async {
      await _pump(tester, const SettingsState.loaded(pushEnabled: false));
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings_screen_off.png'),
      );
    });

    testWidgets('on', (tester) async {
      await _pump(tester, const SettingsState.loaded(pushEnabled: true));
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings_screen_on.png'),
      );
    });

    testWidgets('blocked', (tester) async {
      await _pump(tester, const SettingsState.blocked());
      await expectLater(
        find.byType(SettingsScreen),
        matchesGoldenFile('goldens/settings_screen_blocked.png'),
      );
    });
  });
}
