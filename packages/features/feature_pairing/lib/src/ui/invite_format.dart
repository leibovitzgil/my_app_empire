/// Formatting helpers for the Accept Invite screen.
///
/// GAP: duplicates `feature_library`'s `LibraryFormat.initialsFor`/
/// `colorValueFor` placeholders (see that file's doc comment) — the same
/// missing identity/profile lookup service gap applies here, and the two
/// packages can't share this helper without depending on each other.
abstract final class InviteFormat {
  /// Initials derived from an opaque id, used as an avatar placeholder.
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
