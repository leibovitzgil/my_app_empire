import 'dart:async';
import 'dart:ui' as ui;

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

/// The reader's left-hand page-thumbnails rail: a real rendered thumbnail
/// per page (via [thumbnailFor]), with per-page ink/audio presence dots.
///
/// While a page's thumbnail is loading — or when [thumbnailFor] is absent
/// or resolves `null` — the card falls back to a stylized placeholder, so
/// the rail always matches the design and stays golden-safe.
class PageThumbnailRail extends StatelessWidget {
  /// Creates a [PageThumbnailRail].
  const PageThumbnailRail({
    required this.pageCount,
    required this.currentPage,
    required this.presence,
    required this.onSelectPage,
    this.thumbnailFor,
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

  /// Resolves the decoded thumbnail for a zero-based page index — the
  /// returned image is owned (and disposed) by the rail. Resolve `null`
  /// (or omit the callback entirely) to keep the stylized placeholder
  /// card. The reader wires this to its `ThumbnailCache`.
  final Future<ui.Image?> Function(int pageIndex)? thumbnailFor;

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
            thumbnailFor: thumbnailFor,
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
    required this.thumbnailFor,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final PageInkPresence? presence;
  final Future<ui.Image?> Function(int pageIndex)? thumbnailFor;
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
                        clipBehavior: Clip.antiAlias,
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
                        child: thumbnailFor == null
                            ? const _PlaceholderPage()
                            : _ThumbImage(
                                pageIndex: index,
                                load: thumbnailFor!,
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

/// The stylized page card: the loading/unavailable placeholder for a real
/// thumbnail (and the whole card when the rail has no [_ThumbImage] source).
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(7),
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
    );
  }
}

/// Loads and shows one page's real thumbnail, owning (and disposing) the
/// [ui.Image] it receives from [load]; shows [_PlaceholderPage] until the
/// image arrives (or forever, if the load resolves `null`).
class _ThumbImage extends StatefulWidget {
  const _ThumbImage({required this.pageIndex, required this.load});

  final int pageIndex;
  final Future<ui.Image?> Function(int pageIndex) load;

  @override
  State<_ThumbImage> createState() => _ThumbImageState();
}

class _ThumbImageState extends State<_ThumbImage> {
  ui.Image? _image;

  @override
  void initState() {
    super.initState();
    _request();
  }

  @override
  void didUpdateWidget(covariant _ThumbImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pageIndex != widget.pageIndex) {
      _image?.dispose();
      _image = null;
      _request();
    }
  }

  void _request() {
    final requested = widget.pageIndex;
    unawaited(
      widget.load(requested).then((image) {
        if (image == null) return;
        // A late arrival for an unmounted card — or one whose element was
        // recycled onto another page — is dropped (and disposed), never
        // shown.
        if (!mounted || requested != widget.pageIndex) {
          image.dispose();
          return;
        }
        setState(() => _image = image);
      }),
    );
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final image = _image;
    if (image == null) return const _PlaceholderPage();
    return RawImage(image: image, fit: BoxFit.cover);
  }
}
