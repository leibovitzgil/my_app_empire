import 'package:core_ui/core_ui.dart';
import 'package:feature_score/src/participant_layer.dart';
import 'package:feature_score/src/ui/widgets/ink_palette.dart';
import 'package:flutter/material.dart';

/// A horizontally-scrollable row of visibility toggles below the Score
/// Viewer's app bar: one colour-coded chip per participant's ink layer (in
/// collaboration mode a piece can have several), followed by a single audio-
/// pins chip.
///
/// Each ink chip shows its participant's auto-assigned layer colour and, for
/// the signed-in user's own layer, an owned indicator.
class LayerToggleBar extends StatelessWidget {
  /// Creates a [LayerToggleBar].
  const LayerToggleBar({
    required this.layers,
    required this.audioPinsVisible,
    required this.onInkToggle,
    required this.onAudioToggle,
    super.key,
  });

  /// The participant ink layers, one chip each, in participant order.
  final List<ParticipantLayer> layers;

  /// Whether the audio pins chip is currently selected (visible).
  final bool audioPinsVisible;

  /// Called with a layer's `ownerId` when its ink chip is tapped.
  final ValueChanged<String> onInkToggle;

  /// Called when the audio pins chip is tapped.
  final VoidCallback onAudioToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          for (final layer in layers) ...[
            _InkLayerChip(
              layer: layer,
              onTap: () => onInkToggle(layer.ownerId),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          _AudioPinsChip(
            selected: audioPinsVisible,
            onTap: onAudioToggle,
          ),
        ],
      ),
    );
  }
}

/// A single participant's ink toggle: a colour dot matching their layer
/// colour, their name, and (for the signed-in user) an owned indicator.
class _InkLayerChip extends StatelessWidget {
  const _InkLayerChip({required this.layer, required this.onTap});

  final ParticipantLayer layer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = layer.visible
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Semantics(
        button: true,
        label:
            '${layer.label} layer${layer.isOwn ? ' (yours)' : ''}, '
            '${layer.visible ? 'shown' : 'hidden'}. Double tap to '
            '${layer.visible ? 'hide' : 'show'}.',
        child: Center(
          child: Material(
            color: layer.visible
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh,
            borderRadius: AppRadii.smRadius,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadii.smRadius,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: inkColorForId(layer.colorId),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(layer.label, style: TextStyle(color: foreground)),
                    if (layer.isOwn) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.edit, size: 12, color: foreground),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioPinsChip extends StatelessWidget {
  const _AudioPinsChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      child: Semantics(
        button: true,
        label:
            'Audio pins layer, ${selected ? 'shown' : 'hidden'}. '
            'Double tap to ${selected ? 'hide' : 'show'}.',
        child: Center(
          child: LabeledToggleChip(
            label: 'Audio pins',
            icon: Icons.mic_none_outlined,
            selected: selected,
            onTap: onTap,
          ),
        ),
      ),
    );
  }
}
