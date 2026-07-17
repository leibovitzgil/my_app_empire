// Screenshot/demo harness: boots straight into the Score Viewer against
// in-memory fakes (synthetic staff-paper pages, seeded collaborator ink and
// audio pins, a ticking fake recorder/player) — no Firebase, no PDF engine,
// no sign-in. Exists for the `screenshot` skill's web-build visual review:
//
//   flutter build web --release --no-tree-shake-icons \
//     -t lib/main_screenshot.dart
//
// Scratch tooling — never wired into routing or shipped entry points.
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:audio/audio.dart';
import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

const String _ownerId = 'gil';

void main() => runApp(const _HarnessApp());

class _HarnessApp extends StatelessWidget {
  const _HarnessApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duet reader harness',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const _HarnessScorePage(),
    );
  }
}

class _HarnessScorePage extends StatefulWidget {
  const _HarnessScorePage();

  @override
  State<_HarnessScorePage> createState() => _HarnessScorePageState();
}

class _HarnessScorePageState extends State<_HarnessScorePage> {
  final _annotationRepository = _HarnessAnnotationRepository();
  late final ScoreBloc _bloc = ScoreBloc(
    pieceRepository: _HarnessPieceRepository(),
    annotationRepository: _annotationRepository,
    currentUserId: _ownerId,
  )..add(const ScoreOpened('piece-1'));

  @override
  void dispose() {
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ScoreBloc>.value(
      value: _bloc,
      child: ScoreViewerScreen(
        renderService: _StaffPaperRenderService(),
        recorderService: _HarnessRecorderService(),
        playerService: _HarnessPlayerService(),
        recordingPathBuilder: () => 'rec.m4a',
        audioAssetStore: _HarnessAudioAssetStore(),
        onNudgeRequested: () async {},
      ),
    );
  }
}

// ─── Seeded domain data ──────────────────────────────────────────────────

final Piece _piece = Piece(
  id: 'piece-1',
  title: 'Clair de Lune (Four Hands)',
  basePdfChecksum: 'demo',
  basePdfPath: 'demo.pdf',
  ownerId: _ownerId,
  ownerName: 'Gil L.',
  collaborators: const [
    Collaborator(uid: 'maya', name: 'Maya K.', email: 'maya@example.com'),
    Collaborator(uid: 'tomer', name: 'Tomer R.', email: 'tomer@example.com'),
  ],
  createdAt: DateTime(2025, 6),
  updatedAt: DateTime(2025, 7),
);

List<InkPoint> _wave(double left, double y, double width, double amp) => [
  for (var i = 0; i <= 24; i++)
    InkPoint(
      x: left + width * i / 24,
      y: y + amp * math.sin(i * math.pi / 4),
    ),
];

List<InkPoint> _ellipse(double cx, double cy, double rx, double ry) => [
  for (var i = 0; i <= 28; i++)
    InkPoint(
      x: cx + rx * math.cos(i * 2 * math.pi / 28),
      y: cy + ry * math.sin(i * 2 * math.pi / 28),
    ),
];

final PieceAnnotations _seededAnnotations = PieceAnnotations(
  pieceId: 'piece-1',
  layers: [
    InkLayer(
      ownerId: _ownerId,
      role: PieceRole.owner,
      strokes: [
        InkStroke(
          id: 'g1',
          authorId: _ownerId,
          pageIndex: 0,
          colorId: 'p0',
          points: _ellipse(0.3, 0.24, 0.1, 0.045),
        ),
        InkStroke(
          id: 'g2',
          authorId: _ownerId,
          pageIndex: 0,
          colorId: 'p0',
          points: _wave(0.18, 0.585, 0.24, 0.012),
        ),
      ],
    ),
    InkLayer(
      ownerId: 'maya',
      role: PieceRole.collaborator,
      strokes: [
        const InkStroke(
          id: 'm1',
          authorId: 'maya',
          pageIndex: 0,
          colorId: 'p1',
          points: [
            InkPoint(x: 0.62, y: 0.4),
            InkPoint(x: 0.62, y: 0.375),
            InkPoint(x: 0.86, y: 0.375),
            InkPoint(x: 0.86, y: 0.4),
          ],
        ),
        InkStroke(
          id: 'm2',
          authorId: 'maya',
          pageIndex: 0,
          colorId: 'p1',
          points: _wave(0.55, 0.74, 0.2, 0.014),
        ),
      ],
    ),
    const InkLayer(
      ownerId: 'tomer',
      role: PieceRole.collaborator,
      strokes: [],
    ),
  ],
  audioNotes: [
    AudioNote(
      id: 'note-maya',
      authorId: 'maya',
      audioAssetId: 'maya-note.m4a',
      pageIndex: 0,
      durationMs: 19000,
      region: const Region(
        pageIndex: 0,
        left: 0.72,
        top: 0.12,
        width: 0.2,
        height: 0.12,
      ),
      createdAt: DateTime(2025, 7, 9),
    ),
  ],
);

// ─── Fakes ───────────────────────────────────────────────────────────────

class _HarnessPieceRepository implements PieceRepository {
  @override
  Future<Result<Piece>> getPiece(String pieceId) async => Success(_piece);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _HarnessAnnotationRepository implements AnnotationRepository {
  final _controller = StreamController<PieceAnnotations>.broadcast();
  PieceAnnotations _current = _seededAnnotations;

  void _emit(PieceAnnotations next) {
    _current = next;
    _controller.add(next);
  }

  @override
  Stream<PieceAnnotations> watch(String pieceId) async* {
    yield _current;
    yield* _controller.stream;
  }

  @override
  Future<PieceAnnotations> snapshotWithTombstones(String pieceId) async =>
      _current;

  @override
  Future<Result<void>> addStroke(String pieceId, InkStroke stroke) async {
    _emit(
      PieceAnnotations(
        pieceId: _current.pieceId,
        layers: [
          for (final layer in _current.layers)
            if (layer.ownerId == stroke.authorId)
              InkLayer(
                ownerId: layer.ownerId,
                role: layer.role,
                strokes: [...layer.strokes, stroke],
              )
            else
              layer,
        ],
        audioNotes: _current.audioNotes,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> eraseStroke(String pieceId, String strokeId) async {
    _emit(
      PieceAnnotations(
        pieceId: _current.pieceId,
        layers: [
          for (final layer in _current.layers)
            InkLayer(
              ownerId: layer.ownerId,
              role: layer.role,
              strokes: [
                for (final stroke in layer.strokes)
                  if (stroke.id != strokeId) stroke,
              ],
            ),
        ],
        audioNotes: _current.audioNotes,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> addAudioNote(String pieceId, AudioNote note) async {
    _emit(
      PieceAnnotations(
        pieceId: _current.pieceId,
        layers: _current.layers,
        audioNotes: [..._current.audioNotes, note],
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAudioNote(String pieceId, String noteId) async {
    _emit(
      PieceAnnotations(
        pieceId: _current.pieceId,
        layers: _current.layers,
        audioNotes: [
          for (final note in _current.audioNotes)
            if (note.id != noteId) note,
        ],
      ),
    );
    return const Success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Renders a synthetic engraved-looking page: warm paper, a title block on
/// page 1, and six grand-staff systems with bar lines.
class _StaffPaperRenderService implements PdfRenderService {
  static const int _pageCount = 6;

  @override
  Future<Result<int>> open(String path) async => const Success(_pageCount);

  @override
  Future<Result<String>> checksum(String path) async => const Success('demo');

  @override
  Future<Result<PdfPageImage>> renderPage(
    int pageIndex, {
    double scale = 1,
  }) async {
    final width = (620 * scale).round();
    final height = (800 * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final w = width.toDouble();
    final h = height.toDouble();

    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFFF7F5EF),
    );

    final line = Paint()
      ..color = const Color(0xFF5F636B)
      ..strokeWidth = math.max(1, 0.9 * scale);

    void staff(double top, double left, double right) {
      final gap = 5.2 * scale;
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(
          Offset(left, top + i * gap),
          Offset(right, top + i * gap),
          line,
        );
      }
    }

    _paragraph(
      canvas,
      pageIndex == 0
          ? 'Clair de Lune  ·  C. Debussy'
          : 'Clair de Lune — ${pageIndex + 1}',
      w / 2,
      26 * scale,
      (pageIndex == 0 ? 15 : 10) * scale,
    );

    final left = 44.0 * scale;
    final right = w - 44.0 * scale;
    final firstTop = 72.0 * scale;
    final systemSpan = (h - firstTop - 40 * scale) / 6;
    for (var system = 0; system < 6; system++) {
      final top = firstTop + system * systemSpan;
      staff(top, left, right);
      staff(top + 34 * scale, left, right);
      // Brace-side and bar lines spanning the grand staff.
      final bottom = top + 34 * scale + 4 * 5.2 * scale;
      for (final x in [
        left,
        left + (right - left) * 0.33,
        left + (right - left) * 0.66,
        right,
      ]) {
        canvas.drawLine(Offset(x, top), Offset(x, bottom), line);
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final bytes = await image.toByteData();
    image.dispose();
    return Success(
      PdfPageImage(
        pageIndex: pageIndex,
        width: width,
        height: height,
        bytes: bytes!.buffer.asUint8List(),
      ),
    );
  }

  void _paragraph(
    Canvas canvas,
    String text,
    double centerX,
    double top,
    double fontSize,
  ) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(
              textAlign: TextAlign.center,
              fontSize: fontSize,
            ),
          )
          ..pushStyle(ui.TextStyle(color: const Color(0xFF3D4046)))
          ..addText(text);
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: centerX * 2));
    canvas.drawParagraph(paragraph, Offset(0, top));
  }
}

class _HarnessRecorderService implements AudioRecorderService {
  final _elapsedController = StreamController<Duration>.broadcast();
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  Future<Result<void>> start(String outputPath, {int maxMillis = 60000}) async {
    _elapsed = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed += const Duration(seconds: 1);
      _elapsedController.add(_elapsed);
    });
    return const Success(null);
  }

  @override
  Future<Result<String>> stop() async {
    _timer?.cancel();
    _timer = null;
    return const Success('rec.m4a');
  }

  @override
  Stream<Duration> get elapsed => _elapsedController.stream;
}

class _HarnessPlayerService implements AudioPlayerService {
  final _progressController = StreamController<PlaybackProgress>.broadcast();
  Timer? _timer;

  @override
  Future<Result<void>> play(String path) async {
    const total = Duration(seconds: 19);
    var position = Duration.zero;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      position += const Duration(milliseconds: 250);
      _progressController.add(
        PlaybackProgress(
          position: position > total ? total : position,
          duration: total,
        ),
      );
    });
    return const Success(null);
  }

  @override
  Future<Result<void>> stop() async {
    _timer?.cancel();
    _timer = null;
    return const Success(null);
  }

  @override
  Stream<PlaybackProgress> get progress => _progressController.stream;
}

class _HarnessAudioAssetStore implements AudioAssetStore {
  @override
  Future<Result<String>> put(
    String sourcePath, {
    required String pieceId,
  }) => Result.guard<String>(() async {
    // Same cap behavior as the real stores (G3, M8.3).
    ensureAudioNoteWithinCap(sourcePath);
    return sourcePath;
  });

  @override
  Future<Result<String>> pathFor(
    String assetId, {
    required String pieceId,
  }) async => Success(assetId);

  @override
  Future<Result<void>> delete(
    String assetId, {
    required String pieceId,
  }) async => const Success(null);
}
