import 'dart:async';

import 'package:core_ui/core_ui.dart';
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
  Future<Result<void>> signUp(
    String email,
    String password, {
    String? displayName,
  }) async {
    calls.add('signup:$email:$password:${displayName ?? '<none>'}');
    return _result;
  }

  @override
  Future<Result<void>> sendPasswordReset(String email) async {
    calls.add('reset:$email');
    return _result;
  }

  @override
  Future<Result<void>> sendEmailVerification() async {
    calls.add('verify');
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

  testWidgets('the create-account footer switches to sign-up and submits', (
    tester,
  ) async {
    final repo = _RecordingAuthRepository();
    await _pumpLoginScreen(tester, repo);

    final create = find.text('Create account');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    // Now on the sign-up view: name + email + password fields.
    expect(find.text('Name (optional)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), 'Jane');
    await tester.enterText(find.byType(TextField).at(1), 'new@b.com');
    await tester.enterText(find.byType(TextField).at(2), 'pw');
    final submit = find.widgetWithText(PrimaryButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(repo.calls, contains('signup:new@b.com:pw:Jane'));
  });

  testWidgets('the sign-up footer returns to sign-in', (tester) async {
    final repo = _RecordingAuthRepository();
    await _pumpLoginScreen(tester, repo);

    final create = find.text('Create account');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    final back = find.text('I already have an account');
    await tester.ensureVisible(back);
    await tester.tap(back);
    await tester.pumpAndSettle();

    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Name (optional)'), findsNothing);
  });

  testWidgets('a duplicate-email sign-up renders the human message', (
    tester,
  ) async {
    final repo = _RecordingAuthRepository(
      failure: const AuthFailure.emailInUse(),
    );
    await _pumpLoginScreen(tester, repo);

    final create = find.text('Create account');
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(1), 'dup@b.com');
    await tester.enterText(find.byType(TextField).at(2), 'pw');
    final submit = find.widgetWithText(PrimaryButton, 'Create account');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(
      find.text('An account already exists for that email.'),
      findsOneWidget,
    );
  });

  testWidgets('forgot password opens the dialog and sends the reset link', (
    tester,
  ) async {
    final repo = _RecordingAuthRepository();
    await _pumpLoginScreen(tester, repo);

    final forgot = find.text('Forgot password?');
    await tester.ensureVisible(forgot);
    await tester.tap(forgot);
    await tester.pumpAndSettle();

    expect(find.text('Reset password'), findsOneWidget);
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      ' reset@b.com ',
    );
    await tester.tap(find.text('Send link'));
    await tester.pumpAndSettle();

    // Email is trimmed, the repo is hit, and the confirmation snackbar
    // renders on success.
    expect(repo.calls, contains('reset:reset@b.com'));
    expect(
      find.text('Password reset link sent to reset@b.com.'),
      findsOneWidget,
    );
  });

  testWidgets('cancelling the reset dialog sends nothing', (tester) async {
    final repo = _RecordingAuthRepository();
    await _pumpLoginScreen(tester, repo);

    final forgot = find.text('Forgot password?');
    await tester.ensureVisible(forgot);
    await tester.tap(forgot);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(repo.calls, isEmpty);
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
