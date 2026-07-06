import 'package:core_ui/core_ui.dart';
import 'package:feature_score/src/participant_layer.dart';
import 'package:feature_score/src/ui/widgets/ink_overlay.dart';
import 'package:feature_score/src/ui/widgets/ink_palette.dart';
import 'package:feature_score/src/ui/widgets/score_page_canvas.dart';
import 'package:flutter/material.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

/// A full-screen, view-only presentation of a single practice [region]:
/// centers/zooms to it and shows every participant's ink layer, but offers no
/// drawing/recording tools.
///
/// A small "Edit here" text button pops back to the Score Viewer, which
/// stays scrolled/zoomed wherever the user left it (the caller is
/// responsible for restoring focus there if desired).
class PracticeView extends StatelessWidget {
  /// Creates a [PracticeView] focused on [region].
  const PracticeView({
    required this.region,
    required this.renderService,
    required this.layers,
    super.key,
  });

  /// The passage being practiced.
  final Region region;

  /// The already-opened PDF render service.
  final PdfRenderService renderService;

  /// The participant ink layers to render, each in its own colour.
  final List<ParticipantLayer> layers;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: Center(
              child: AppTextButton(
                label: 'Edit here',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      ),
      body: ScorePageCanvas(
        renderService: renderService,
        pageIndex: region.pageIndex,
        focusRegion: region,
        overlays: [
          for (final layer in layers)
            InkOverlay(
              strokes: layer.strokes,
              pageIndex: region.pageIndex,
              color: inkColorForId(layer.colorId),
            ),
        ],
      ),
    );
  }
}
