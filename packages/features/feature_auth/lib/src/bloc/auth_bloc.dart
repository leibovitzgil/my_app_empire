import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import '../domain/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({required AuthRepository authRepository})
      : _authRepository = authRepository,
        super(const AuthState.unknown()) {
    on<AuthStatusChanged>(_onAuthStatusChanged);
    on<AuthLogoutRequested>(_onAuthLogoutRequested);
    on<AuthLoginRequested>(_onAuthLoginRequested);
    _userSubscription = _authRepository.user.listen(
      (user) => add(AuthStatusChanged(
        user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
        user: user,
      )),
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
        return emit(const AuthState.failure("Unknown error"));
    }
  }

  void _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) {
    _authRepository.logout();
  }

  Future<void> _onAuthLoginRequested(
    AuthLoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    try {
      await _authRepository.login(event.email, event.password);
    } catch (e) {
      emit(AuthState.failure(e.toString()));
    }
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
