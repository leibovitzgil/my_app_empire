part of 'auth_bloc.dart';

enum AuthStatus { authenticated, unauthenticated }

final class AuthState extends Equatable {
  const AuthState._({
    this.status = AuthStatus.unauthenticated,
    this.user,
  });

  const AuthState.unknown() : this._();

  const AuthState.authenticated(String user)
      : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated()
      : this._(status: AuthStatus.unauthenticated);

  final AuthStatus status;
  final String? user;

  @override
  List<Object?> get props => [status, user];
}
