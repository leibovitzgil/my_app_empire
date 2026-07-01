/// A named capability token. Thin type alias for type-safety at call sites.
typedef Permission = String;

/// Well-known permission tokens shared across apps.
abstract final class Permissions {
  /// Access to app-wide administrative screens.
  static const String viewAdminPanel = 'view_admin_panel';

  /// Ability to create/edit/remove premium content.
  static const String managePremiumContent = 'manage_premium_content';

  /// Ability to view premium/gated content.
  static const String accessPremiumContent = 'access_premium_content';
}

/// Default role.name -> permission set. Apps override via the repository
/// constructor. Keyed by role NAME so custom roles slot in without identity
/// coupling.
const Map<String, Set<Permission>> defaultRolePermissions = {
  'guest': {},
  'member': {Permissions.accessPremiumContent},
  'admin': {
    Permissions.accessPremiumContent,
    Permissions.managePremiumContent,
    Permissions.viewAdminPanel,
  },
};
