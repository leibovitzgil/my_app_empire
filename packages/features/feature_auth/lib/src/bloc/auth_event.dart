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

/// The user submitted the account-creation form.
final class AuthSignUpRequested extends AuthEvent {
  const AuthSignUpRequested(this.email, this.password, {this.displayName});
  final String email;
  final String password;
  final String? displayName;
  @override
  List<Object?> get props => [email, password, displayName];
}

/// The user tapped "Continue with Google".
final class AuthGoogleSignInRequested extends AuthEvent {}

/// The user tapped "Continue with Apple".
final class AuthAppleSignInRequested extends AuthEvent {}
