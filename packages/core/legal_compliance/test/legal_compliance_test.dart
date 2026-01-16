import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:legal_compliance/legal_compliance.dart';

void main() {
  group('DeleteAccountButton', () {
    testWidgets('shows dialog and calls onDelete on confirm', (WidgetTester tester) async {
      bool deleteCalled = false;
      Future<void> onDelete() async {
        deleteCalled = true;
      }

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeleteAccountButton(onDelete: onDelete),
        ),
      ));

      // Tap the button
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Delete Account?'), findsOneWidget);

      // Tap Delete in dialog
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(deleteCalled, true);
    });

    testWidgets('shows dialog and does NOT call onDelete on cancel', (WidgetTester tester) async {
      bool deleteCalled = false;
      Future<void> onDelete() async {
        deleteCalled = true;
      }

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: DeleteAccountButton(onDelete: onDelete),
        ),
      ));

      // Tap the button
      await tester.tap(find.text('Delete Account'));
      await tester.pumpAndSettle();

      // Verify dialog is shown
      expect(find.text('Delete Account?'), findsOneWidget);

      // Tap Cancel in dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Verify callback was NOT called
      expect(deleteCalled, false);
      expect(find.text('Delete Account?'), findsNothing);
    });
  });

  group('PrivacyPolicyButton', () {
    testWidgets('renders correctly', (WidgetTester tester) async {
       await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PrivacyPolicyButton(privacyPolicyUrl: 'https://example.com'),
        ),
      ));

      expect(find.text('Privacy Policy'), findsOneWidget);
    });
  });
}
