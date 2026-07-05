import 'package:equatable/equatable.dart';

/// A discoverable-by-email identity in the cross-user directory, used to
/// resolve a collaborator invite's recipient email to an existing account.
class DirectoryUser extends Equatable {
  /// Creates a [DirectoryUser].
  const DirectoryUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.discoverable = true,
  });

  /// The directory entry's account id.
  final String uid;

  /// The email this entry is keyed by.
  final String email;

  /// The account's display name, if known.
  final String? displayName;

  /// Whether this user has consented to being found by email lookup. A
  /// directory lookup only ever resolves an entry where this is `true` — a
  /// non-discoverable entry looks identical to no entry at all, so an
  /// invite flow can never distinguish "no account" from "an account that
  /// opted out", by design.
  final bool discoverable;

  @override
  List<Object?> get props => [uid, email, displayName, discoverable];
}
