import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required WidgetBuilder builder,
  String? title,
  bool isDismissible = true,
  void Function(Future<bool?>)? onOpened,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) {
          return ElevatedButton(
            onPressed: () {
              final result = AppBottomSheet.show<bool>(
                context,
                title: title,
                isDismissible: isDismissible,
                builder: builder,
              );
              onOpened?.call(result);
            },
            child: const Text('Open'),
          );
        },
      ),
    ),
  );
}

void main() {
  group('AppBottomSheet', () {
    testWidgets('resolves to the value passed to Navigator.pop', (
      tester,
    ) async {
      late Future<bool?> result;

      await tester.pumpWidget(
        _harness(
          title: 'Pick one',
          onOpened: (f) => result = f,
          builder: (sheetContext) => ElevatedButton(
            onPressed: () => Navigator.of(sheetContext).pop(true),
            child: const Text('Confirm'),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm'));
      await tester.pumpAndSettle();

      expect(await result, isTrue);
    });

    testWidgets('tapping the close button dismisses the sheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          title: 'Details',
          builder: (context) => const Text('Sheet content'),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Sheet content'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Sheet content'), findsNothing);
    });

    testWidgets('omits the close button when isDismissible is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          title: 'Details',
          isDismissible: false,
          builder: (context) => const Text('Sheet content'),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Sheet content'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing);
    });

    testWidgets('grows bottom padding to clear the keyboard inset', (
      tester,
    ) async {
      addTearDown(tester.view.resetViewInsets);

      await tester.pumpWidget(
        _harness(
          title: 'Details',
          builder: (context) => const Text('Sheet content'),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final noInsetRect = tester.getRect(find.text('Sheet content'));
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final withInsetRect = tester.getRect(find.text('Sheet content'));

      // With a large keyboard inset, the content's bottom padding grows to
      // clear it, so the content itself sits higher on screen (a smaller
      // `bottom` coordinate) than with no inset at all.
      expect(withInsetRect.bottom, lessThan(noInsetRect.bottom));
    });
  });
}
