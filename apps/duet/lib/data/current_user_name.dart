import 'dart:async';

/// Tracks the current user's latest known display name from
/// `MockAuthRepository.displayName`, exposing it synchronously via [call] —
/// mirrors `CurrentUser`'s pattern exactly (see that file's doc for why
/// eager construction/subscription matters), but for a display name rather
/// than an id.
///
/// Not part of the shared `AuthRepository` contract (see
/// `MockAuthRepository.displayName`'s doc for why), so this is constructed
/// directly against that concrete stream in `injection.dart` rather than
/// resolved through the `AuthRepository` interface.
///
/// Consumed by `feature_library`'s import flow and `feature_pairing`'s
/// invite/accept flow to attach a real display name to a `Piece` instead of
/// leaving `teacherName`/`studentName` null (which falls back to an
/// initials-from-id placeholder in the UI).
class CurrentUserName {
  /// Creates a [CurrentUserName], subscribing to [nameStream] immediately.
  CurrentUserName(Stream<String?> nameStream) {
    _subscription = nameStream.listen((name) => _name = name);
  }

  late final StreamSubscription<String?> _subscription;
  String? _name;

  /// The latest known display name, or `null` when signed out / not yet
  /// known / unresolvable — callers should fall back to a placeholder rather
  /// than treat `null` as an error.
  String? call() => _name;

  /// Releases the subscription to the display name stream.
  Future<void> dispose() => _subscription.cancel();
}
