import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required AppSnackbarVariant variant,
  String message = 'Something happened',
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () => AppSnackbar.show(
              context,
              message: message,
              variant: variant,
              actionLabel: actionLabel,
              onAction: onAction,
            ),
            child: const Text('Trigger'),
          );
        },
      ),
    ),
  );
}

void main() {
  group('AppSnackbar', () {
    testWidgets('shows exactly one SnackBar with the given message', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(variant: AppSnackbarVariant.info, message: 'Hello there'),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Hello there'), findsOneWidget);
    });

    testWidgets('rapid-fire calls never stack multiple snackbars', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(variant: AppSnackbarVariant.error, message: 'Failed'),
      );

      await tester.tap(find.byType(ElevatedButton));
      // Deliberately no pump/settle between taps: simulate rapid-fire calls
      // before the first snackbar has finished animating in.
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('tapping the action button fires onAction', (tester) async {
      var actionCount = 0;
      await tester.pumpWidget(
        _harness(
          variant: AppSnackbarVariant.success,
          message: 'Saved',
          actionLabel: 'Undo',
          onAction: () => actionCount++,
        ),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsOneWidget);
      await tester.tap(find.text('Undo'));
      await tester.pump();

      expect(actionCount, 1);
    });

    testWidgets('renders the success variant icon and text', (tester) async {
      await tester.pumpWidget(
        _harness(variant: AppSnackbarVariant.success, message: 'Saved'),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    });

    testWidgets('renders the error variant icon and text', (tester) async {
      await tester.pumpWidget(
        _harness(variant: AppSnackbarVariant.error, message: 'Oh no'),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('renders the info variant icon and text', (tester) async {
      await tester.pumpWidget(
        _harness(variant: AppSnackbarVariant.info, message: 'FYI'),
      );

      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });
  });
}
