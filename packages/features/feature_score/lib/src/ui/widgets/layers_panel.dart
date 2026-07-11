import 'package:core_ui/core_ui.dart';
import 'package:feature_score/src/participant_layer.dart';
import 'package:feature_score/src/ui/widgets/ink_palette.dart';
import 'package:flutter/material.dart';

/// The reader's Layers panel: one row per participant's ink layer, an audio
/// pins row, a clean-workspace switch, and (when annotations haven't been
/// shared yet) a bottom share prompt.
///
/// Docked inline at ≥840dp, opened from a Layers button via `endDrawer` at
/// 600-839dp, or shown in a bottom sheet below 600dp — this widget itself
/// doesn't know which; it just expects a bounded-height parent (see
/// `score_viewer_screen.dart`). Replaces `LayerToggleBar`.
class LayersPanel extends StatelessWidget {
  /// Creates a [LayersPanel].
  const LayersPanel({
    required this.layers,
    required this.audioPinsVisible,
    required this.audioPinCountOnPage,
    required this.cleanWorkspace,
    required this.onInkToggle,
    required this.onAudioToggle,
    required this.onCleanWorkspaceToggle,
    this.onClose,
    this.closeIcon = Icons.close,
    this.onShare,
    this.annotationsShared = false,
    super.key,
  });

  /// Every participant's ink layer, in participant order.
  final List<ParticipantLayer> layers;

  /// Whether the audio-pins layer is currently shown.
  final bool audioPinsVisible;

  /// How many audio notes are pinned to the page currently shown.
  final int audioPinCountOnPage;

  /// Whether the clean-workspace mask is on.
  final bool cleanWorkspace;

  /// Called with a layer's `ownerId` when its row is tapped.
  final ValueChanged<String> onInkToggle;

  /// Called when the audio pins row is tapped.
  final VoidCallback onAudioToggle;

  /// Called when the clean-workspace switch is toggled.
  final VoidCallback onCleanWorkspaceToggle;

  /// Called when the header's close affordance is tapped. `null` hides it
  /// (e.g. when shown in a drawer/bottom sheet that already has its own
  /// dismiss gesture).
  final VoidCallback? onClose;

  /// The close affordance's glyph — a plain X by default; the docked host
  /// passes a collapse-to-the-right glyph instead, since closing there
  /// tucks the panel away rather than dismissing an overlay.
  final IconData closeIcon;

  /// Called when the bottom "Share" prompt is tapped. `null` (or
  /// [annotationsShared]) hides the whole prompt.
  final VoidCallback? onShare;

  /// Whether annotations have already been shared — hides the bottom share
  /// prompt when true.
  final bool annotationsShared;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(onClose: onClose, closeIcon: closeIcon),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (final layer in layers)
                  _LayerRow(
                    layer: layer,
                    onTap: () => onInkToggle(layer.ownerId),
                  ),
                _AudioPinsRow(
                  visible: audioPinsVisible,
                  countOnPage: audioPinCountOnPage,
                  onTap: onAudioToggle,
                ),
                Divider(height: 1, color: scheme.outlineVariant),
                _CleanWorkspaceRow(
                  value: cleanWorkspace,
                  onChanged: (_) => onCleanWorkspaceToggle(),
                ),
              ],
            ),
          ),
          if (!annotationsShared && onShare != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _ShareCard(onShare: onShare!),
            ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.closeIcon, this.onClose});

  final VoidCallback? onClose;
  final IconData closeIcon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(Icons.layers_outlined, color: scheme.primary, size: 21),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Layers',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onClose != null)
            Semantics(
              button: true,
              label: 'Close layers panel',
              child: SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  icon: Icon(closeIcon),
                  onPressed: onClose,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// One participant's ink-layer row: colour dot, name (+ own-badge stylus),
/// stroke-count subtitle, and a trailing visibility eye. Hidden layers dim
/// via lower-emphasis colours, never a wrapping `Opacity`, so the row keeps
/// its own compositing (and stays screen-reader legible) either way.
class _LayerRow extends StatelessWidget {
  const _LayerRow({required this.layer, required this.onTap});

  final ParticipantLayer layer;
  final VoidCallback onTap;

  static String _strokeCount(ParticipantLayer layer) {
    final count = layer.strokes.length;
    return count == 1 ? '1 stroke' : '$count strokes';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hidden = !layer.visible;
    final dotColor = hidden
        ? inkColorForId(layer.colorId).withValues(alpha: 0.4)
        : inkColorForId(layer.colorId);
    final nameColor = hidden ? scheme.onSurfaceVariant : scheme.onSurface;
    final subColor = hidden
        ? scheme.onSurfaceVariant.withValues(alpha: 0.7)
        : scheme.onSurfaceVariant;
    final eyeColor = hidden
        ? scheme.onSurfaceVariant.withValues(alpha: 0.6)
        : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label:
          '${layer.label} layer${layer.isOwn ? ' (yours)' : ''}, '
          '${layer.visible ? 'shown' : 'hidden'}. Double tap to '
          '${layer.visible ? 'hide' : 'show'}.',
      child: SizedBox(
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: dotColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              layer.label,
                              style: TextStyle(
                                color: nameColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (layer.isOwn) ...[
                              const SizedBox(width: AppSpacing.xs),
                              Icon(Icons.edit, size: 14, color: subColor),
                            ],
                          ],
                        ),
                        Text(
                          // "· pen" only on the layer the pen actually
                          // writes into — yours.
                          layer.isOwn
                              ? '${_strokeCount(layer)} · pen'
                              : _strokeCount(layer),
                          style: TextStyle(color: subColor, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      layer.visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: eyeColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioPinsRow extends StatelessWidget {
  const _AudioPinsRow({
    required this.visible,
    required this.countOnPage,
    required this.onTap,
  });

  final bool visible;
  final int countOnPage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          'Audio pins layer, ${visible ? 'shown' : 'hidden'}. Double tap to '
          '${visible ? 'hide' : 'show'}. $countOnPage on this page.',
      child: SizedBox(
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.mic_none_outlined,
                    size: 18,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Audio pins',
                          style: TextStyle(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '$countOnPage on this page',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ExcludeSemantics(
                    child: Icon(
                      visible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CleanWorkspaceRow extends StatelessWidget {
  const _CleanWorkspaceRow({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Clean workspace',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Hide all annotations',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            label: value
                ? 'Clean workspace on. Double tap to show annotations again.'
                : 'Clean workspace off. Double tap to hide all annotations.',
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  const _ShareCard({required this.onShare});

  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 19,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Annotations not shared yet',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
          Semantics(
            button: true,
            label: 'Share annotations',
            child: AppTextButton(label: 'Share', onPressed: onShare),
          ),
        ],
      ),
    );
  }
}
