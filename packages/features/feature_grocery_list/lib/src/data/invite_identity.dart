import 'package:feature_grocery_list/src/domain/grocery_models.dart';

/// Turns an invite email into a stable [Collaborator] so an invited person has
/// an identity (id, display name, avatar colour) before they ever sign in.
/// Deterministic — the same email always maps to the same person — so the
/// in-memory and Firestore repositories agree, and de-duplication by id works.

/// Avatar palette for invited members, kept distinct from the seeded household
/// colours and picked deterministically from the email.
const List<int> _invitePalette = <int>[
  0xFF8B5CF6, // violet
  0xFFF59E0B, // amber
  0xFF14B8A6, // teal
  0xFFEF4444, // red
  0xFF6366F1, // indigo
  0xFF84CC16, // lime
];

/// Whether [email] is a plausible email address (light, client-side check).
bool isValidEmail(String email) =>
    RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim());

/// The stable id used for an invited collaborator — the lower-cased email, so
/// re-inviting the same address is idempotent.
String inviteId(String email) => email.trim().toLowerCase();

/// Builds the [Collaborator] identity for an invite [email].
Collaborator collaboratorForEmail(String email) {
  final normalized = inviteId(email);
  return Collaborator(
    id: normalized,
    name: _displayName(normalized),
    colorValue: _invitePalette[_paletteIndex(normalized)],
  );
}

/// Title-cases the local part into a friendly name
/// ("dana.lee@x.com" -> "Dana Lee").
String _displayName(String email) {
  final local = email.split('@').first;
  final words = local
      .split(RegExp(r'[._\-+]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}');
  final name = words.join(' ');
  return name.isEmpty ? email : name;
}

/// Maps an email onto a stable palette slot.
int _paletteIndex(String email) {
  var hash = 0;
  for (final unit in email.codeUnits) {
    hash = (hash + unit) % _invitePalette.length;
  }
  return hash;
}
