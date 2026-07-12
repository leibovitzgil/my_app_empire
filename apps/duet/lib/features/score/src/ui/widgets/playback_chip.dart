import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// The top-right chip shown while an audio note is playing: author avatar +
/// "{name}'s note", a thin playback-position bar, and "mm:ss / mm:ss".
///
/// [progress] is a real playback fraction (0.0-1.0) from the audio player,
/// never synthesized amplitude data — this renders a plain
/// [LinearProgressIndicator], not a fake waveform.
class PlaybackChip extends StatelessWidget {
  /// Creates a [PlaybackChip].
  const PlaybackChip({
    required this.authorInitials,
    required this.authorColor,
    required this.authorName,
    required this.positionLabel,
    required this.durationLabel,
    this.progress,
    super.key,
  });

  /// The playing note's author's initials, for [InitialsAvatar].
  final String authorInitials;

  /// The playing note's author's avatar colour.
  final Color authorColor;

  /// The playing note's author's display name.
  final String authorName;

  /// The current playback position, formatted `mm:ss`.
  final String positionLabel;

  /// The note's total duration, formatted `mm:ss`.
  final String durationLabel;

  /// The playback fraction (0.0-1.0), or `null` while indeterminate.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      label: "$authorName's note playing, $positionLabel of $durationLabel",
      child: Material(
        color: scheme.surfaceContainerHigh,
        elevation: 6,
        borderRadius: AppRadii.mdRadius,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + AppSpacing.xs,
          ),
          child: ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                InitialsAvatar(
                  initials: authorInitials,
                  color: authorColor,
                  radius: 15,
                ),
                const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "$authorName's note",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: 120,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 3,
                          backgroundColor: scheme.surfaceContainerHighest,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$positionLabel / $durationLabel',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
