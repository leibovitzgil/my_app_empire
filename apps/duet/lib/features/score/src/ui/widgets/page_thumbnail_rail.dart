import 'package:core_ui/core_ui.dart';
import 'package:flutter/material.dart';

/// One page's ink/audio presence summary, for [PageThumbnailRail]'s dots.
///
/// `inkColors` is already deduped and capped by the caller (one
/// `inkColorForId` colour per participant with at least one stroke on that
/// page) — this widget just renders whatever it's given. `hasNew` is set when
/// the page carries ink or a note that's new since the viewer last looked
/// (M4.3), driving a corner accent hint.
typedef PageInkPresence = ({bool hasAudio, List<Color> inkColors, bool hasNew});

/// The reader's left-hand page-thumbnails rail: a stylized (not real-PDF)
/// thumbnail per page, with per-page ink/audio presence dots.
///
/// Real PDF thumbnails are a follow-up (see the TODO where this is
/// constructed in `score_viewer_screen.dart`); stylized cards keep this
/// golden-safe and match the design without an extra render pass per page.
class PageThumbnailRail extends StatelessWidget {
  /// Creates a [PageThumbnailRail].
  const PageThumbnailRail({
    required this.pageCount,
    required this.currentPage,
    required this.presence,
    required this.onSelectPage,
    this.dimmed = false,
    super.key,
  });

  /// The piece's total page count.
  final int pageCount;

  /// The zero-based page currently shown.
  final int currentPage;

  /// One entry per page (by index); shorter than [pageCount] is tolerated
  /// (missing pages just show no dots).
  final List<PageInkPresence> presence;

  /// Called with the tapped page's zero-based index.
  final ValueChanged<int> onSelectPage;

  /// Whether the rail is dimmed and non-interactive (draw mode).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rail = Container(
      width: 92,
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        itemCount: pageCount,
        itemBuilder: (context, index) => Center(
          child: _PageThumb(
            index: index,
            selected: index == currentPage,
            presence: index < presence.length ? presence[index] : null,
            onTap: dimmed ? null : () => onSelectPage(index),
          ),
        ),
      ),
    );
    return dimmed ? Opacity(opacity: 0.5, child: rail) : rail;
  }
}

class _PageThumb extends StatelessWidget {
  const _PageThumb({
    required this.index,
    required this.selected,
    required this.presence,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final PageInkPresence? presence;
  final VoidCallback? onTap;

  static const Color _paperColor = Color(0xFFF4F2EC);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelColor = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final inkColors = presence?.inkColors ?? const <Color>[];
    final hasAudio = presence?.hasAudio ?? false;
    final hasNew = presence?.hasNew ?? false;
    return Semantics(
      button: true,
      selected: selected,
      label:
          'Page ${index + 1}${selected ? ', current page' : ''}'
          '${hasNew ? ', new annotations' : ''}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 56,
                        height: 72,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: _paperColor,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: selected
                                ? scheme.primary
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            for (var i = 0; i < 4; i++)
                              Container(
                                height: 2,
                                width: double.infinity,
                                color: Colors.black.withValues(alpha: 0.28),
                              ),
                          ],
                        ),
                      ),
                      // "New on this page" corner hint (M4.3).
                      if (hasNew)
                        Positioned(
                          top: -2,
                          right: -2,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: scheme.primary,
                              border: Border.all(
                                color: scheme.surface,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ExcludeSemantics(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 11,
                            color: labelColor,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                        for (final color in inkColors)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: color,
                              ),
                            ),
                          ),
                        if (hasAudio)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Icon(
                              Icons.mic,
                              size: 7,
                              color: labelColor,
                            ),
                          ),
                      ],
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
