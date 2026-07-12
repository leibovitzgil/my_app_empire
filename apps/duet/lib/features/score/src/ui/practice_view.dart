import 'package:core_ui/core_ui.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/score/src/participant_layer.dart';
import 'package:duet/features/score/src/ui/reader_theme.dart';
import 'package:duet/features/score/src/ui/widgets/ink_overlay.dart';
import 'package:duet/features/score/src/ui/widgets/ink_palette.dart';
import 'package:duet/features/score/src/ui/widgets/score_page_canvas.dart';
import 'package:duet/features/score/src/ui/widgets/sync_status_badge.dart';
import 'package:flutter/material.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

/// Focused practice on one passage — the music-stand view.
///
/// Centers and zooms to the chosen [region] on the reader's dark stage
/// (same forced-dark theme, so pushing here never flashes the host app's
/// light theme), with the orientation aids a player actually needs
/// mid-practice:
///
/// * **Steppers** on either side glide the window to the previous/next
///   passage — one window-height at a time, rolling across page boundaries —
///   so hands only leave the keys for one tap.
/// * A **mini-map** in the corner shows where on the page the window sits
///   ("focus without losing orientation"); tapping it moves the window
///   there.
/// * **Ink dots** in the top bar toggle each participant's annotations —
///   e.g. hide your partner's fingerings while running a passage clean,
///   one tap to bring them back.
///
/// View-only: no drawing/recording tools. "Edit here" pops back to the
/// Score Viewer.
class PracticeView extends StatefulWidget {
  /// Creates a [PracticeView] focused on [region].
  const PracticeView({
    required this.region,
    required this.renderService,
    required this.layers,
    required this.pageCount,
    this.pieceTitle,
    super.key,
  });

  /// The passage being practiced (the initial focus window).
  final Region region;

  /// The already-opened PDF render service.
  final PdfRenderService renderService;

  /// Every participant's ink layer; each layer's `visible` flag seeds this
  /// view's own per-layer toggles.
  final List<ParticipantLayer> layers;

  /// The piece's total page count, bounding cross-page stepping.
  final int pageCount;

  /// The piece's title, for the top bar subtitle.
  final String? pieceTitle;

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView> {
  late Region _region = widget.region;
  late final Set<String> _hiddenOwnerIds = {
    for (final layer in widget.layers)
      if (!layer.visible) layer.ownerId,
  };

  static const double _edgeTolerance = 0.001;

  bool get _canStepBack =>
      _region.top > _edgeTolerance || _region.pageIndex > 0;

  bool get _canStepForward =>
      _region.top + _region.height < 1 - _edgeTolerance ||
      _region.pageIndex < widget.pageCount - 1;

  /// Moves the focus window one window-height along the page's reading
  /// order ([direction] −1 up / +1 down), rolling onto the previous/next
  /// page at the edges.
  void _step(int direction) {
    final region = _region;
    final newTop = region.top + direction * region.height;
    if (newTop > -_edgeTolerance &&
        newTop + region.height < 1 + _edgeTolerance) {
      _moveWindow(top: newTop);
      return;
    }
    if (direction > 0 && region.pageIndex < widget.pageCount - 1) {
      _moveWindow(pageIndex: region.pageIndex + 1, top: 0);
    } else if (direction < 0 && region.pageIndex > 0) {
      _moveWindow(pageIndex: region.pageIndex - 1, top: 1 - region.height);
    }
  }

  void _moveWindow({int? pageIndex, double? top, double? left}) {
    final region = _region;
    setState(() {
      _region = Region(
        pageIndex: pageIndex ?? region.pageIndex,
        left: (left ?? region.left).clamp(0, 1 - region.width),
        top: (top ?? region.top).clamp(0, 1 - region.height),
        width: region.width,
        height: region.height,
      );
    });
  }

  /// Centers the focus window on [fraction] (a 0-1 point on the mini-map's
  /// page), clamped to stay on the page.
  void _moveWindowTo(Offset fraction) {
    _moveWindow(
      left: fraction.dx - _region.width / 2,
      top: fraction.dy - _region.height / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = readerTheme(context);
    final scheme = theme.colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Theme(
      data: theme,
      child: Scaffold(
        body: Column(
          children: [
            _PracticeTopBar(
              pieceTitle: widget.pieceTitle,
              pageLabel: 'Page ${_region.pageIndex + 1} of ${widget.pageCount}',
              compact: compact,
              layers: widget.layers,
              hiddenOwnerIds: _hiddenOwnerIds,
              onToggleLayer: (ownerId) => setState(() {
                if (!_hiddenOwnerIds.remove(ownerId)) {
                  _hiddenOwnerIds.add(ownerId);
                }
              }),
              onBack: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: ScorePageCanvas(
                        renderService: widget.renderService,
                        pageIndex: _region.pageIndex,
                        focusRegion: _region,
                        boundaryMargin: const EdgeInsets.all(480),
                        overlays: [
                          for (final layer in widget.layers)
                            if (!_hiddenOwnerIds.contains(layer.ownerId))
                              InkOverlay(
                                strokes: layer.strokes,
                                pageIndex: _region.pageIndex,
                                color: inkColorForId(layer.colorId),
                              ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: _PassageStepper(
                        icon: Icons.chevron_left,
                        caption: 'Previous',
                        semanticLabel: 'Previous passage',
                        onPressed: _canStepBack ? () => _step(-1) : null,
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: _PassageStepper(
                        icon: Icons.chevron_right,
                        caption: 'Next',
                        semanticLabel: 'Next passage',
                        onPressed: _canStepForward ? () => _step(1) : null,
                      ),
                    ),
                  ),
                  if (!compact)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          right: AppSpacing.lg,
                          bottom: AppSpacing.lg,
                        ),
                        child: _PracticeMiniMap(
                          region: _region,
                          pageLabel:
                              'Page ${_region.pageIndex + 1} of '
                              '${widget.pageCount}',
                          accentColor: scheme.primary,
                          onTapFraction: _moveWindowTo,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The practice view's 64px top bar: back, "Practice" + piece subtitle, a
/// where-am-I chip, per-layer ink toggles, and the "Edit here" exit.
class _PracticeTopBar extends StatelessWidget {
  const _PracticeTopBar({
    required this.pieceTitle,
    required this.pageLabel,
    required this.compact,
    required this.layers,
    required this.hiddenOwnerIds,
    required this.onToggleLayer,
    required this.onBack,
  });

  final String? pieceTitle;
  final String pageLabel;
  final bool compact;
  final List<ParticipantLayer> layers;
  final Set<String> hiddenOwnerIds;
  final ValueChanged<String> onToggleLayer;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Back to the score',
            child: SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: onBack,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Practice',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                  ),
                ),
                if (pieceTitle != null)
                  Text(
                    pieceTitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: AppSpacing.sm),
            StatusPill(label: pageLabel, tint: scheme.primary),
          ],
          const Spacer(),
          if (layers.isNotEmpty) ...[
            for (final layer in layers)
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: _LayerDot(
                  label: layer.label,
                  color: inkColorForId(layer.colorId),
                  visible: !hiddenOwnerIds.contains(layer.ownerId),
                  onTap: () => onToggleLayer(layer.ownerId),
                ),
              ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Semantics(
            button: true,
            label: 'Edit here — back to the score at this spot',
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                side: BorderSide(color: scheme.outlineVariant),
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                shape: const StadiumBorder(),
              ),
              onPressed: onBack,
              icon: const Icon(Icons.draw_outlined, size: 19),
              label: const Text(
                'Edit here',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One participant's ink toggle: a small ring in their ink colour, filled
/// while shown, hollow-and-dim while hidden.
class _LayerDot extends StatelessWidget {
  const _LayerDot({
    required this.label,
    required this.color,
    required this.visible,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool visible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ring = visible ? color : color.withValues(alpha: 0.45);
    return Semantics(
      button: true,
      label:
          "$label's ink, ${visible ? 'shown' : 'hidden'}. Double tap to "
          '${visible ? 'hide' : 'show'}.',
      child: Tooltip(
        message: label,
        child: Material(
          color: visible ? color.withValues(alpha: 0.25) : Colors.transparent,
          shape: CircleBorder(side: BorderSide(color: ring, width: 2)),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ring,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the previous/next passage steppers: a floating circular button
/// with a small caption beneath.
class _PassageStepper extends StatelessWidget {
  const _PassageStepper({
    required this.icon,
    required this.caption,
    required this.semanticLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String caption;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: scheme.surfaceContainerHigh,
            shape: CircleBorder(
              side: BorderSide(color: scheme.outlineVariant),
            ),
            elevation: enabled ? 4 : 0,
            child: InkWell(
              onTap: onPressed,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  icon,
                  size: 26,
                  color: enabled
                      ? scheme.onSurfaceVariant
                      : scheme.onSurfaceVariant.withValues(alpha: 0.35),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ExcludeSemantics(
            child: Text(
              caption,
              style: TextStyle(
                fontSize: 11.5,
                color: enabled
                    ? scheme.onSurfaceVariant
                    : scheme.onSurfaceVariant.withValues(alpha: 0.35),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The corner mini-map: a stylized page card with the focus window drawn at
/// its true fractional position, so "where am I on the page" survives being
/// zoomed into a two-system window. Tapping moves the window there.
class _PracticeMiniMap extends StatelessWidget {
  const _PracticeMiniMap({
    required this.region,
    required this.pageLabel,
    required this.accentColor,
    required this.onTapFraction,
  });

  final Region region;
  final String pageLabel;
  final Color accentColor;
  final ValueChanged<Offset> onTapFraction;

  static const double _width = 116;
  static const double _height = 150;
  static const Color _paperColor = Color(0xFFF4F2EC);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label:
          'Page map. The focused passage is highlighted; double tap to move '
          'the focus.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: _paperColor,
            elevation: 6,
            shadowColor: scheme.shadow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: scheme.outlineVariant),
            ),
            clipBehavior: Clip.antiAlias,
            child: GestureDetector(
              // Opaque so taps in the gaps between the stylized staff bands
              // still land on the map instead of falling through to the
              // page canvas beneath.
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) => onTapFraction(
                Offset(
                  (details.localPosition.dx / _width).clamp(0, 1),
                  (details.localPosition.dy / _height).clamp(0, 1),
                ),
              ),
              child: SizedBox(
                width: _width,
                height: _height,
                child: Stack(
                  children: [
                    // Stylized staff bands, echoing the thumbnail rail's
                    // page cards (not a live render — this is a map, not a
                    // preview).
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 13,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (var i = 0; i < 6; i++)
                              Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(1.5),
                                  color: Colors.black.withValues(alpha: 0.16),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: region.left * _width,
                      top: region.top * _height,
                      width: region.width * _width,
                      height: region.height * _height,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: accentColor, width: 2),
                            color: accentColor.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          ExcludeSemantics(
            child: Text(
              pageLabel,
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
