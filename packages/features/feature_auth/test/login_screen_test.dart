import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records which auth method the screen drove, so we can assert the LoginScreen
/// wires each button to the right repository call via the bloc. Each flow can
/// be made to fail with [failure] to exercise the error rendering.
class _RecordingAuthRepository implements AuthRepository {
  _RecordingAuthRepository({this.failure});

  /// When set, every flow fails with this instead of succeeding.
  final AuthFailure? failure;

  final List<String> calls = <String>[];
  final StreamController<String?> _controller =
      StreamController<String?>.broadcast();

  Result<void> get _result {
    final failure = this.failure;
    return failure == null ? const Success(null) : ResultFailure(failure);
  }

  @override
  Stream<String?> get user => _controller.stream;

  @override
  Future<Result<void>> login(String email, String password) async {
    calls.add('login:$email:$password');
    return _result;
  }

  @override
  Future<Result<void>> signInWithGoogle() async {
    calls.add('google');
    return _result;
  }

  @override
  Future<Result<void>> signInWithApple() async {
    calls.add('apple');
    return _result;
  }

  @override
  Future<Result<void>> logout() async {
    calls.add('logout');
    return _result;
  }
}

Future<void> _pumpLoginScreen(
  WidgetTester tester,
  _RecordingAuthRepository repo,
) async {
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
}

Future<void> _submitEmailLogin(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'a@b.com');
  await tester.enterText(find.byType(TextField).last, 'secret');
  final login = find.text('Log in');
  await tester.ensureVisible(login);
  await tester.tap(login);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('LoginScreen wires email, Google and Apple to the bloc', (
    tester,
  ) async {
    final repo = _RecordingAuthRepository();
    await _pumpLoginScreen(tester, repo);

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

    await _submitEmailLogin(tester);

    expect(repo.calls, contains('google'));
    expect(repo.calls, contains('apple'));
    expect(repo.calls, contains('login:a@b.com:secret'));
  });

  testWidgets('a wrong-password login renders the human message', (
    tester,
  ) async {
    final repo = _RecordingAuthRepository(
      failure: const AuthFailure.invalidCredentials(),
    );
    await _pumpLoginScreen(tester, repo);

    await _submitEmailLogin(tester);

    expect(find.text('Email or password is incorrect.'), findsOneWidget);
  });

  testWidgets('a cancelled flow surfaces no error message', (tester) async {
    final repo = _RecordingAuthRepository(
      failure: const AuthFailure.cancelled(),
    );
    await _pumpLoginScreen(tester, repo);

    final google = find.text('Continue with Google');
    await tester.ensureVisible(google);
    await tester.tap(google);
    await tester.pumpAndSettle();

    // The bloc is in failure state, but cancellation maps to no copy at all.
    final bloc = BlocProvider.of<AuthBloc>(
      tester.element(find.byType(LoginScreen)),
    );
    expect(bloc.state, const AuthState.failure(AuthFailure.cancelled()));
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });
}
