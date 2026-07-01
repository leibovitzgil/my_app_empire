import 'package:equatable/equatable.dart';

/// An app-wide role, ordered by [rank] for coarse-grained access checks.
class AppRole extends Equatable {
  /// Creates a role with the given [name] and [rank].
  const AppRole({required this.name, required this.rank});

  /// The stable, storage-friendly identifier for this role.
  final String name;

  /// Higher rank means more privileged. Used for `>=`/`>` comparisons.
  final int rank;

  /// The default, unassigned/signed-out role.
  static const AppRole guest = AppRole(name: 'guest', rank: 0);

  /// A standard authenticated user.
  static const AppRole member = AppRole(name: 'member', rank: 10);

  /// A privileged, administrative user.
  static const AppRole admin = AppRole(name: 'admin', rank: 100);

  /// Built-in roles, lowest rank first. Used to resolve a persisted role name
  /// back to an [AppRole] for the default (name-only) local store.
  static const List<AppRole> defaults = [guest, member, admin];

  /// True if this role's rank is at least [other]'s rank.
  bool operator >=(AppRole other) => rank >= other.rank;

  /// True if this role's rank exceeds [other]'s rank.
  bool operator >(AppRole other) => rank > other.rank;

  /// True if this role's rank is at most [other]'s rank.
  bool operator <=(AppRole other) => rank <= other.rank;

  /// True if this role's rank is below [other]'s rank.
  bool operator <(AppRole other) => rank < other.rank;

  @override
  List<Object?> get props => [name, rank];
}
