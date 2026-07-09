import 'package:bloc_test/bloc_test.dart';
import 'package:feature_settings/feature_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsBloc extends MockBloc<SettingsEvent, SettingsState>
    implements SettingsBloc {}

// A network-free theme (AppTheme pulls google_fonts, which fetches at runtime).
final _theme = ThemeData(useMaterial3: true);

void main() {
  setUpAll(() {
    registerFallbackValue(const SettingsReconcileRequested());
  });

  late SettingsBloc bloc;

  setUp(() {
    bloc = _MockSettingsBloc();
  });

  Future<void> pump(WidgetTester tester, SettingsState state) async {
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
    await tester.pump();
  }

  group('SettingsScreen', () {
    // AC1: a clearly labelled push-notifications toggle is present.
    testWidgets('renders the Push notifications toggle', (tester) async {
      await pump(tester, const SettingsState.loaded(pushEnabled: false));

      expect(find.text('Push notifications'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);
    });

    // AC1/AC7: off state reads "Off" and the switch is off + interactive.
    testWidgets('loaded(off) shows Off and an interactive switch', (
      tester,
    ) async {
      await pump(tester, const SettingsState.loaded(pushEnabled: false));

      expect(find.text('Off'), findsOneWidget);
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.value, isFalse);
      expect(tile.onChanged, isNotNull);
    });

    // AC2/AC7: on state reads "On" and the switch is on.
    testWidgets('loaded(on) shows On and the switch is on', (tester) async {
      await pump(tester, const SettingsState.loaded(pushEnabled: true));

      expect(find.text('On'), findsOneWidget);
      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.value, isTrue);
    });

    // AC2: tapping an off switch dispatches a toggle-on event.
    testWidgets('tapping the switch dispatches SettingsPushToggled(true)', (
      tester,
    ) async {
      await pump(tester, const SettingsState.loaded(pushEnabled: false));

      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();

      verify(
        () => bloc.add(const SettingsPushToggled(enabled: true)),
      ).called(1);
    });

    // AC6/AC7: blocked must NOT read as on; switch off + non-interactive,
    // shows the blocked subtitle and an escape hatch to system settings.
    testWidgets('blocked: switch off, disabled, shows Open settings', (
      tester,
    ) async {
      await pump(tester, const SettingsState.blocked());

      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.value, isFalse, reason: 'must not falsely show on');
      expect(tile.onChanged, isNull, reason: 'switch is disabled when blocked');
      expect(find.text('Blocked in system settings'), findsOneWidget);
      expect(find.text('Open settings'), findsOneWidget);
    });

    // AC5/AC6: the "Open settings" button routes to the gateway via its event.
    testWidgets('blocked: Open settings dispatches the open-settings event', (
      tester,
    ) async {
      await pump(tester, const SettingsState.blocked());

      await tester.tap(find.text('Open settings'));
      await tester.pump();

      verify(
        () => bloc.add(const SettingsOpenSystemSettingsRequested()),
      ).called(1);
    });

    // While a permission decision is pending, the switch is locked.
    testWidgets('pending: switch is non-interactive', (tester) async {
      await pump(tester, const SettingsState.pending(pushEnabled: true));

      final tile = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(tile.onChanged, isNull);
    });

    // Failure surfaces a retry affordance and keeps the toggle interactive.
    testWidgets('failure shows a Retry snackbar and stays interactive', (
      tester,
    ) async {
      whenListen(
        bloc,
        Stream<SettingsState>.fromIterable([
          const SettingsState.failure(
            'Something went wrong.',
            pushEnabled: false,
          ),
        ]),
        initialState: const SettingsState.loading(),
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
      await tester.pump();

      expect(find.text('Something went wrong.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    // extraTile is the app-glue slot for e.g. Duet's "Manage plan"
    // row — absent by default, rendered when supplied.
    testWidgets('renders no extra row by default', (tester) async {
      await pump(tester, const SettingsState.loaded(pushEnabled: false));

      expect(find.text('Manage plan'), findsNothing);
    });

    testWidgets('renders extraTile below the notifications toggle', (
      tester,
    ) async {
      whenListen(
        bloc,
        const Stream<SettingsState>.empty(),
        initialState: const SettingsState.loaded(pushEnabled: false),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: _theme,
          home: BlocProvider<SettingsBloc>.value(
            value: bloc,
            child: const SettingsScreen(
              extraTile: ListTile(title: Text('Manage plan')),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Manage plan'), findsOneWidget);
    });
  });
}
