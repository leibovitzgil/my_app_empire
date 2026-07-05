import 'package:user_roles/user_roles.dart';

/// Capability token gating the teacher-only "Invite student" action.
///
/// GAP: `feature_library` defines the same token (see its own
/// `duet_permissions.dart`) with the identical literal value. The two
/// packages can't depend on each other, so this is a duplicated constant
/// rather than a shared import — flagged here rather than silently risking
/// drift. A later phase should promote these to a tiny shared
/// `core/duet_permissions` package (or fold them into `user_roles` itself)
/// once a third feature needs the same vocabulary.
abstract final class DuetPermissions {
  /// Invite a student to collaborate on a piece. Must match
  /// `feature_library`'s `DuetPermissions.inviteStudent` exactly.
  static const Permission inviteStudent = 'duet.invite_student';
}
