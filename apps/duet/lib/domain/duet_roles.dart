import 'package:feature_library/feature_library.dart' show DuetPermissions;
import 'package:user_roles/user_roles.dart';

/// Duet's app-wide Teacher/Student roles and their permission wiring,
/// registered against `LocalUserRoleRepository`'s `rolePermissions`/
/// `knownRoles` constructor parameters in `injection.dart` — per
/// `feature_library`'s `DuetPermissions` doc, which flags that the app-glue
/// layer owns this registration.
///
/// Teacher and Student are peers, not a rank (see that same doc), so both
/// share [AppRole.rank]; only [rolePermissions] distinguishes what each can
/// do.
abstract final class DuetRoles {
  /// A user who imports pieces and invites students.
  static const AppRole teacher = AppRole(name: 'teacher', rank: 10);

  /// A user who was invited to collaborate on a teacher's piece.
  static const AppRole student = AppRole(name: 'student', rank: 10);

  /// Every role `LocalUserRoleRepository` should recognize when resolving a
  /// persisted role name back to an [AppRole] — must include [AppRole.guest]
  /// (the pre-role-selection default) alongside Duet's own roles, or a
  /// restored session would silently forget a previously-selected role.
  static const List<AppRole> knownRoles = [AppRole.guest, teacher, student];

  /// Only the teacher role gets the teacher-only capability tokens; the
  /// student role is intentionally mapped to an empty set.
  static const Map<String, Set<Permission>> rolePermissions = {
    'teacher': {DuetPermissions.importPiece, DuetPermissions.inviteStudent},
    'student': {},
  };
}
