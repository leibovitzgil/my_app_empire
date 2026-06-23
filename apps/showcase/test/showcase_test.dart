import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:showcase/app.dart';
import 'package:showcase/injection.dart';

void main() {
  tearDown(() async => getIt.reset());

  testWidgets('shows onboarding on first launch', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await configureDependencies();

    await tester.pumpWidget(const ShowcaseApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets('skips onboarding once completed', (tester) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await configureDependencies();

    await tester.pumpWidget(const ShowcaseApp());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Past onboarding -> auth gate shows the login screen.
    expect(find.text('Login'), findsOneWidget);
  });
}
