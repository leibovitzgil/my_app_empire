import 'package:user_roles/user_roles.dart';

/// Capability tokens gating Duet's teacher-only actions in this feature.
///
/// Duet's Teacher/Student roles are peers, not a rank (a student isn't "less
/// privileged" than a teacher — they just can't originate pieces or invites),
/// so these are gated via `user_roles`' capability-based `PermissionGate`
/// rather than `RoleGate`'s rank comparison. Kept as plain [Permission]
/// (String) constants — mirroring `user_roles`' own `Permissions` — rather
/// than adding Duet-specific tokens to that generic package. The app-glue
/// layer registers these against the 'teacher' role name via
/// `LocalUserRoleRepository`'s `rolePermissions` constructor parameter.
///
/// `feature_pairing` needs the [inviteStudent] token too but can't depend on
/// this package (see that package's `duet_permissions.dart`): its copy is a
/// duplicated literal, flagged there as a gap for a later phase (e.g.
/// promoting these to a tiny shared `core/duet_permissions` package once a
/// third feature needs the same tokens).
abstract final class DuetPermissions {
  /// Import a new piece from a PDF.
  static const Permission importPiece = 'duet.import_piece';

  /// Invite a student to collaborate on a piece.
  static const Permission inviteStudent = 'duet.invite_student';
}
