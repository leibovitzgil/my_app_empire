part of 'auth_bloc.dart';

enum AuthStatus { authenticated, unauthenticated, failure }

final class AuthState extends Equatable {
  const AuthState._({
    this.status = AuthStatus.unauthenticated,
    this.user,
    this.error,
  });

  const AuthState.unknown() : this._();

  const AuthState.authenticated(String user)
    : this._(status: AuthStatus.authenticated, user: user);

  const AuthState.unauthenticated()
    : this._(status: AuthStatus.unauthenticated);

  const AuthState.failure(AuthFailure error)
    : this._(status: AuthStatus.failure, error: error);

  final AuthStatus status;
  final String? user;

  /// The typed failure when [status] is [AuthStatus.failure]; UI maps it to
  /// human copy (see `AuthFailureMessage`).
  final AuthFailure? error;

  @override
  List<Object?> get props => [status, user, error];
}
