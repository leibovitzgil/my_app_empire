/// Formatting helpers for the Home / Piece List screen. Kept dependency-free
/// (no `intl`) to match this factory's existing convention (see
/// `feature_grocery_list`'s `GroceryFormat.relativeTime`).
abstract final class LibraryFormat {
  /// A short, friendly relative time for a piece's last activity, e.g.
  /// "just now", "5 min ago", "3 d ago".
  static String relativeTime(DateTime time, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final diff = ref.difference(time);
    if (diff.isNegative || diff.inSeconds < 45) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} d ago';
  }

  /// Initials derived from an opaque id, used as an avatar placeholder.
  ///
  /// GAP: there is no identity/profile lookup service yet to resolve a
  /// owner/collaborator id to a real display name or avatar colour (unlike
  /// `feature_grocery_list`'s `Collaborator`, which carries name/colour
  /// directly on the domain model it fetches from Firestore). A later phase
  /// should add a small `UserProfile`/directory service (e.g. alongside
  /// `feature_auth`) that both `feature_library` and `feature_pairing` can
  /// depend on to show real names instead of this placeholder.
  static String initialsFor(String id) {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, trimmed.length < 2 ? 1 : 2).toUpperCase();
  }

  /// A stable placeholder avatar colour derived from an opaque id.
  static int colorValueFor(String id) {
    const palette = <int>[
      0xFF8B5CF6,
      0xFFF59E0B,
      0xFF14B8A6,
      0xFFEF4444,
      0xFF6366F1,
      0xFF84CC16,
    ];
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash + unit) % palette.length;
    }
    return palette[hash];
  }
}
