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
    _userSubscription = _authRepository.user.listen(
      (user) => add(AuthStatusChanged(
        user != null ? AuthStatus.authenticated : AuthStatus.unauthenticated,
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
        // In a real app we might fetch user details here
        return emit(const AuthState.authenticated('test_user'));
    }
  }

  void _onAuthLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) {
    _authRepository.logout();
  }

  @override
  Future<void> close() {
    _userSubscription.cancel();
    return super.close();
  }
}
