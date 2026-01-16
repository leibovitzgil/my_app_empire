part of 'auth_bloc.dart';

sealed class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

final class AuthStatusChanged extends AuthEvent {
  const AuthStatusChanged(this.status, {this.user});

  final AuthStatus status;
  final String? user;

  @override
  List<Object?> get props => [status, user];
}

final class AuthLogoutRequested extends AuthEvent {}

final class AuthLoginRequested extends AuthEvent {
  const AuthLoginRequested(this.email, this.password);
  final String email;
  final String password;
  @override
  List<Object?> get props => [email, password];
}
