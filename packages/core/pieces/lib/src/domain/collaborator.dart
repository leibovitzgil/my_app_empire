import 'package:equatable/equatable.dart';

/// A participant granted collaborator access to a piece by its owner (the
/// teacher), beyond the owner themself. A piece can have several — each
/// gets their own ink layer (see `AnnotationRepository`/`InkLayer`).
class Collaborator extends Equatable {
  /// Creates a [Collaborator].
  const Collaborator({required this.uid, this.name, this.email});

  /// The collaborator's account id.
  final String uid;

  /// The collaborator's display name, if known at the time they joined.
  final String? name;

  /// The email the collaborator was invited/resolved by, if known.
  final String? email;

  @override
  List<Object?> get props => [uid, name, email];
}
