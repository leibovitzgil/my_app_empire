import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:core_utils/core_utils.dart';
import 'package:equatable/equatable.dart';
import 'package:feature_auth/src/domain/auth_failure.dart';
import 'package:feature_auth/src/domain/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(const AuthState.unknown()) {
    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    on<AuthSignUpRequested>(_onAuthSignUpRequested);
    on<AuthPasswordResetRequested>(_onAuthPasswordResetRequested);
    on<AuthGoogleSignInRequested>(_onAuthGoogleSignInRequested);
    on<AuthAppleSignInRequested>(_onAuthAppleSignInRequested);
    _userSubscription = _authRepository.user.listen(
      (user) => add(
        AuthStatusChanged(
          user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
          user: user,
        ),
      ),
    );
  }

  final AuthRepository _authRepository;
  late StreamSubscription<String?> _userSubscription;

  Future<void> _onAuthStatusChanged(
    AuthStatusChanged event,
    Emitter<AuthState> emit,
  ) async {
    switch (event.status) {
      case AuthStatus.unauthenticated:
        return emit(const AuthState.unauthenticated());
      case AuthStatus.authenticated:
        final user = event.user;
        if (user != null) {
          return emit(AuthState.authenticated(user));
        }
        return emit(const AuthState.unauthenticated());
      case AuthStatus.failure:
        return emit(const AuthState.failure(AuthFailure.unknown()));
    }
  }

  Future<void> _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Fire-and-forget: a failed sign-out has no surface on the login screen,
    // and flipping status to failure while still authenticated would fight
    // the routers' auth redirects. Settings owns sign-out UX (M1.5) and
    // surfaces failures there.
    await _authRepository.logout();
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    _emitOnFailure(
      await _authRepository.login(event.email, event.password),
      emit,
    );
  }

  Future<void> _onAuthSignUpRequested(
    AuthSignUpRequested event,
    Emitter<AuthState> emit,
  ) async {
    _emitOnFailure(
      await _authRepository.signUp(
        event.email,
        event.password,
        displayName: event.displayName,
      ),
      emit,
    );
  }

  Future<void> _onAuthPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    // Clear any previous confirmation first, so re-sending (even to the
    // same address) always produces a fresh state transition for listeners.
    if (state.passwordResetSentTo != null) {
      emit(
        AuthState._(status: state.status, user: state.user),
      );
    }
    final result = await _authRepository.sendPasswordReset(event.email);
    switch (result) {
      case Success<void>():
        emit(
          AuthState._(
            status: state.status,
            user: state.user,
            passwordResetSentTo: event.email,
          ),
        );
      case ResultFailure<void>(:final error):
        emit(
          AuthState.failure(
            error is AuthFailure ? error : AuthFailure.unknown(error),
          ),
        );
    }
  }

  Future<void> _onAuthGoogleSignInRequested(
    AuthGoogleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    _emitOnFailure(await _authRepository.signInWithGoogle(), emit);
  }

  Future<void> _onAuthAppleSignInRequested(
    AuthAppleSignInRequested event,
    Emitter<AuthState> emit,
  ) async {
    _emitOnFailure(await _authRepository.signInWithApple(), emit);
  }

  /// Folds a failed [result] into [AuthState.failure]; success emits nothing
  /// (the [AuthRepository.user] stream flips the state to authenticated).
  ///
  /// A user-initiated cancel also lands here as `AuthFailure.cancelled()` —
  /// consumers keying off `status == failure` must treat that kind as benign
  /// (LoginScreen maps it to no message at all).
  void _emitOnFailure(Result<void> result, Emitter<AuthState> emit) {
    if (result case ResultFailure<void>(:final error)) {
      emit(
        AuthState.failure(
          error is AuthFailure ? error : AuthFailure.unknown(error),
        ),
      );
    }
  }

  @override
  Future<void> close() async {
    await _userSubscription.cancel();
    return super.close();
  }
}
