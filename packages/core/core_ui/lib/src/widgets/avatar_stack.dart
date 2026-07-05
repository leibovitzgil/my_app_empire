import 'package:core_ui/src/widgets/initials_avatar.dart';
import 'package:flutter/material.dart';

/// One avatar's worth of display data for [AvatarStack] — deliberately just
/// initials/colour (not a domain `Collaborator`), so `core_ui` stays
/// dependency-free of any feature's domain model.
typedef AvatarStackPerson = ({String initials, Color color});

/// A row of overlapping [InitialsAvatar]s, with a trailing "+N" badge once
/// [people] exceeds [maxVisible] — the compact "who's on this" affordance
/// used wherever a list of people (piece collaborators, list members) needs a
/// single-glance summary rather than a full roster.
class AvatarStack extends StatelessWidget {
  /// Creates an [AvatarStack] for [people].
  const AvatarStack({
    required this.people,
    this.maxVisible = 3,
    this.radius = 14,
    this.overlap = 10,
    this.semanticLabel,
    super.key,
  });

  /// The people to render, in display order. Only the first [maxVisible] are
  /// drawn as avatars; the remainder are folded into a single "+N" badge.
  final List<AvatarStackPerson> people;

  /// The maximum number of individual avatars drawn before folding the rest
  /// into a "+N" badge.
  final int maxVisible;

  /// Each avatar's radius — see [InitialsAvatar.radius].
  final double radius;

  /// How many logical pixels each subsequent avatar overlaps the previous
  /// one by.
  final double overlap;

  /// An explicit accessibility label for the whole stack. Defaults to a
  /// generated "N collaborators" summary — pass this to customize the
  /// wording (e.g. "N members").
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();

    final visibleCount = people.length > maxVisible
        ? maxVisible
        : people.length;
    final overflow = people.length - visibleCount;
    final diameter = radius * 2;
    final step = diameter - overlap;
    final slots = visibleCount + (overflow > 0 ? 1 : 0);
    final width = step * (slots - 1) + diameter;
    final scheme = Theme.of(context).colorScheme;

    return Semantics(
      label: semanticLabel ?? _defaultLabel(people.length),
      container: true,
      child: SizedBox(
        height: diameter,
        width: width,
        child: Stack(
          children: [
            for (var i = 0; i < visibleCount; i++)
              Positioned(
                left: step * i,
                child: ExcludeSemantics(
                  child: _Ring(
                    ringColor: scheme.surface,
                    child: InitialsAvatar(
                      initials: people[i].initials,
                      color: people[i].color,
                      radius: radius,
                    ),
                  ),
                ),
              ),
            if (overflow > 0)
              Positioned(
                left: step * visibleCount,
                child: ExcludeSemantics(
                  child: _Ring(
                    ringColor: scheme.surface,
                    child: CircleAvatar(
                      radius: radius,
                      backgroundColor: scheme.surfaceContainerHighest,
                      child: Text(
                        '+$overflow',
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: radius * 0.75,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _defaultLabel(int count) =>
      '$count ${count == 1 ? 'collaborator' : 'collaborators'}';
}

/// Wraps [child] in a thin ring matching the surrounding surface, so
/// overlapping avatars read as distinct circles rather than a solid blob.
class _Ring extends StatelessWidget {
  const _Ring({required this.child, required this.ringColor});

  final Widget child;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor, width: 2),
      ),
      child: child,
    );
  }
}
