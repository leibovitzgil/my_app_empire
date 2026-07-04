import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoadingView', () {
    testWidgets('shows a spinner and no label by default', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingView())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('shows the label when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingView(label: 'Loading your list…')),
        ),
      );

      expect(find.text('Loading your list…'), findsOneWidget);
    });

    testWidgets('exposes a live-region semantics label', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: LoadingView(label: 'Loading your list…')),
        ),
      );

      expect(find.bySemanticsLabel('Loading your list…'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('defaults the semantics label to "Loading"', (tester) async {
      final handle = tester.ensureSemantics();

      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: LoadingView())),
      );

      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
    });
  });
}
