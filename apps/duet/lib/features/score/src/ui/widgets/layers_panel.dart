import 'package:core_ui/core_ui.dart';
import 'package:duet/features/score/src/participant_layer.dart';
import 'package:duet/features/score/src/ui/widgets/ink_palette.dart';
import 'package:flutter/material.dart';

/// The reader's Layers panel: one row per participant's ink layer, an audio
/// pins row, a clean-workspace switch, and (when there's a collaborator to
/// nudge) a bottom "let them know you added notes" prompt.
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
    this.onNudge,
    this.nudgeTargetName,
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

  /// Called when the bottom "Nudge" prompt is tapped. `null` (or a null
  /// [nudgeTargetName]) hides the whole prompt.
  final VoidCallback? onNudge;

  /// The collaborator(s) a nudge would reach, named in the prompt copy
  /// (`Let <name> know you added notes`). `null` — a solo sheet with no one to
  /// nudge — hides the prompt.
  final String? nudgeTargetName;

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
          if (onNudge != null && nudgeTargetName != null)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: _NudgeCard(name: nudgeTargetName!, onNudge: onNudge!),
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
          '${layer.label} layer${layer.isOwn ? ' (yours)' : ''}'
          '${layer.hasNewInk ? ', new annotations' : ''}, '
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
                            // "New since you last looked" dot (M4.3) — only on
                            // another participant's changed layer.
                            if (layer.hasNewInk) ...[
                              const SizedBox(width: AppSpacing.sm),
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.primary,
                                ),
                              ),
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

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({required this.name, required this.onNudge});

  final String name;
  final VoidCallback onNudge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Icon(
            Icons.notifications_none_outlined,
            size: 19,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Let $name know you added notes',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            ),
          ),
          Semantics(
            button: true,
            label: 'Nudge $name',
            child: AppTextButton(label: 'Nudge', onPressed: onNudge),
          ),
        ],
      ),
    );
  }
}
