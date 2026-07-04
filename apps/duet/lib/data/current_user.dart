import 'dart:async';

/// Tracks the latest signed-in user id from `AuthRepository.user`, exposing
/// it synchronously via [call] for repositories/blocs across the app that
/// need a plain `String Function()` (e.g. `LocalPieceRepository`,
/// `ScoreBloc`) rather than a stream.
///
/// Must be constructed eagerly — before the user can possibly log in (see
/// `injection.dart`, which registers it as an eager singleton right after
/// `AuthRepository`) — so its subscription is already attached by the time
/// the first `user` event fires. `AuthRepository.user` is a broadcast stream
/// with no replay-to-late-subscribers semantics, so a [CurrentUser] built
/// after login has already happened would never learn who's signed in.
class CurrentUser {
  /// Creates a [CurrentUser], subscribing to [userStream] immediately.
  CurrentUser(Stream<String?> userStream) {
    _subscription = userStream.listen((id) => _userId = id);
  }

  late final StreamSubscription<String?> _subscription;
  String? _userId;

  /// The latest known signed-in user id, or `''` when signed out / not yet
  /// known. An empty string is a safe (if inert) default for repositories
  /// that key persisted data by this id, rather than threading a nullable
  /// type through every constructor.
  String call() => _userId ?? '';

  /// Releases the subscription to the user id stream.
  Future<void> dispose() => _subscription.cancel();
}
