import 'dart:async';

import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records which auth method the screen drove, so we can assert the LoginScreen
/// wires each button to the right repository call via the bloc.
class _RecordingAuthRepository implements AuthRepository {
  final List<String> calls = <String>[];
  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<void> login(String email, String password) async {
    calls.add('login:$email:$password');
  }

  @override
  Future<void> signInWithGoogle() async => calls.add('google');

  @override
  Future<void> signInWithApple() async => calls.add('apple');

  @override
  Future<void> logout() async => calls.add('logout');
}

void main() {
  testWidgets('LoginScreen wires email, Google and Apple to the bloc', (
    tester,
  ) async {
    final repo = _RecordingAuthRepository();
    final bloc = AuthBloc(authRepository: repo);
    addTearDown(bloc.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<AuthBloc>.value(
          value: bloc,
          child: const LoginScreen(title: 'Test App'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The screen renders the shared, branded SignInView.
    expect(find.text('Test App'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);

    final google = find.text('Continue with Google');
    await tester.ensureVisible(google);
    await tester.tap(google);
    await tester.pumpAndSettle();

    final apple = find.text('Continue with Apple');
    await tester.ensureVisible(apple);
    await tester.tap(apple);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'a@b.com');
    await tester.enterText(find.byType(TextField).last, 'secret');
    final login = find.text('Log in');
    await tester.ensureVisible(login);
    await tester.tap(login);
    await tester.pumpAndSettle();

    expect(repo.calls, contains('google'));
    expect(repo.calls, contains('apple'));
    expect(repo.calls, contains('login:a@b.com:secret'));
  });
}
