// Shared harness for the Duet "core loop" flow: import -> annotate ->
// record an audio note -> toggle layers -> clean workspace -> close/reopen.
//
// Deliberately does *not* go through `injection.dart`/`App` (which wires
// real, platform-backed `PdfrxRenderService`/`RecordAudioRecorderService`/
// `JustAudioPlayerService` — none of which function without a platform
// channel, the same limitation documented in
// `packages/services/pdf_rendering/test/pdfx_render_service_test.dart`).
//
// It also deliberately uses **in-memory fakes** for `PieceRepository`/
// `AnnotationRepository`/`AudioAssetStore` rather than the real
// `Local*` implementations: those do genuine `dart:io` filesystem work,
// which — verified empirically while building this test — never completes
// inside a `testWidgets` body in this sandbox (a plain `test()` body has no
// such problem, which is exactly why `packages/core/pieces/test/*.dart`
// exercises the real repositories' persistence/ownership guarantees that
// way instead). Mirrors this repo's own convention of mocking the
// repository contract at the bloc/widget-test level (see `score_bloc_test
// .dart`, `review_sync`'s `_FakeAnnotationRepository`) — genuine on-disk
// persistence and the ownership guard are covered independently, at the
// repository level, in `packages/core/pieces/test/`.
//
// [runDuetImportFlow] (Library -> Import, real UI throughout) is shared by
// both `test/duet_flow_test.dart` (headless, in the standard gate) and
// `integration_test/app_flow_test.dart` (device/`flutter drive`), so the
// import portion can never drift out of sync — see the `flutter-e2e` skill.
//
// The two diverge after that for the Score Viewer portion. Verified
// empirically: mounting the real `ScoreViewerScreen` — specifically
// `ScorePageCanvas`, which decodes its page image via
// `ui.decodeImageFromPixels` in `initState` — is flaky-to-hanging in this
// sandbox's headless `flutter_tester` (the decode's completion callback
// needs a real event-loop turn that a `testWidgets` body's `FakeAsync` zone
// doesn't reliably provide, and `tester.runAsync`, the sanctioned way to get
// one, itself hung intermittently when tried here for the *full*
// `ScoreViewerScreen` (its `StreamBuilder`s, gesture detectors, and multiple
// concurrent futures around `ScorePageCanvas`). So:
//   - `duet_flow_test.dart` (headless) continues the Score Viewer portion
//     against a bare `ScoreBloc` (no `ScoreViewerScreen` widget at all) —
//     deterministic and fast, and still proves the piece the real import UI
//     produced flows correctly into annotate/record/toggle/clean-workspace/
//     reopen (each individually covered at the bloc level by
//     `score_bloc_test.dart`; this proves the continuity between them).
//   - `app_flow_test.dart` (device-only; this sandbox can't run it — no
//     device attached, matching the `flutter-e2e` skill's own note that
//     `flutter test integration_test/` needs one) mounts the real
//     `ScoreViewerScreen` and drives real drag gestures, since a real
//     device's `IntegrationTestWidgetsFlutterBinding` has no such issue.
//   - `PracticeView` — the thin, single-`FutureBuilder` wrapper around
//     `ScorePageCanvas` used for region-centering — turns out not to share
//     the full screen's flakiness: a single bounded `tester.runAsync` call
//     (with no sibling async work competing for the event loop) is enough
//     for its decode to complete reliably. See
//     `packages/features/feature_score/test/practice_view_test.dart`, which
//     covers region-centering at the widget level in isolation.
import 'dart:async';

import 'package:audio/audio.dart';
import 'package:core_utils/core_utils.dart';
import 'package:feature_library/feature_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:monetization/monetization.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

const ownerId = 'owner-e2e';

/// A tiny, deterministic [PdfRenderService]: `open` always succeeds with a
/// single page, and `renderPage` returns a fixed, fully-opaque 4x4 RGBA
/// bitmap — enough for `ScorePageCanvas` to `decodeImageFromPixels`
/// successfully without a real `pdfx` platform channel. Never touches disk.
class FakePdfRenderService implements PdfRenderService {
  static const _dimension = 4;

  @override
  Future<Result<int>> open(String path) async => const Success(1);

  @override
  Future<Result<PdfPageImage>> renderPage(
    int pageIndex, {
    double scale = 1,
  }) async => Success(
    PdfPageImage(
      pageIndex: pageIndex,
      width: _dimension,
      height: _dimension,
      bytes: List<int>.filled(_dimension * _dimension * 4, 255),
    ),
  );

  @override
  Future<Result<String>> checksum(String path) async =>
      Success('checksum-$path');
}

/// A fake [AudioRecorderService] that never touches disk: [start]/[stop]
/// just track the given output path, which the caller treats opaquely. Only
/// needed by the integration (widget-mounting) variant of this flow, which
/// mounts the real `ScoreViewerScreen`.
class FakeAudioRecorderService implements AudioRecorderService {
  late String _outputPath;

  @override
  Future<Result<void>> start(String outputPath, {int maxMillis = 60000}) {
    _outputPath = outputPath;
    return Future.value(const Success(null));
  }

  @override
  Future<Result<String>> stop() async => Success(_outputPath);

  @override
  Stream<Duration> get elapsed => const Stream<Duration>.empty();
}

/// A no-op fake [AudioPlayerService] — this flow never plays a note back.
/// Only needed by the integration (widget-mounting) variant.
class FakeAudioPlayerService implements AudioPlayerService {
  @override
  Future<Result<void>> play(String path) async => const Success(null);

  @override
  Future<Result<void>> stop() async => const Success(null);

  @override
  Stream<PlaybackProgress> get progress =>
      const Stream<PlaybackProgress>.empty();
}

/// A [MonetizationService] fixed at free-tier (`isProUser` always `false`),
/// used only by the collaborator-invite funnel test below to exercise
/// `CollaboratorLimits`' free-tier cap without depending on the real
/// `SimulatedMonetizationService`'s own async/persistence behavior. Every
/// other member is unused by that flow and throws if ever called.
class FakeMonetizationService implements MonetizationService {
  @override
  Future<bool> isProUser({String entitlementIdentifier = 'pro'}) async => false;

  @override
  Stream<bool> isProUserStream({String entitlementIdentifier = 'pro'}) =>
      Stream.value(false);

  @override
  Future<void> initialize(String apiKey, {String? appUserId}) =>
      throw UnimplementedError();

  @override
  Future<void> logIn(String appUserId) => throw UnimplementedError();

  @override
  Future<void> logOut() => throw UnimplementedError();

  @override
  Future<Offerings?> getOfferings() => throw UnimplementedError();

  @override
  Future<CustomerInfo?> purchasePackage(Package package) =>
      throw UnimplementedError();

  @override
  Future<CustomerInfo?> purchaseMonthly() => throw UnimplementedError();

  @override
  Future<CustomerInfo?> purchaseAnnual() => throw UnimplementedError();

  @override
  Future<CustomerInfo?> restorePurchases() => throw UnimplementedError();

  @override
  Stream<CustomerInfo> get customerInfoStream => throw UnimplementedError();
}

/// A minimal in-memory [PieceRepository]. Real persistence-across-restart
/// and the pairing invariants are covered by
/// `packages/core/pieces/test/local_piece_repository_test.dart`; this fake
/// only needs to support the piece this flow imports.
class FakePieceRepository implements PieceRepository {
  final _pieces = <String, Piece>{};
  final _controller = StreamController<List<Piece>>.broadcast();
  var _seq = 0;

  // Plain `StreamController` composition rather than an `async*` generator
  // — verified empirically that cancelling a subscription to a `yield*`-
  // delegating generator stream hangs `close()` in this sandbox.
  @override
  Stream<List<Piece>> watchPieces() {
    return Stream<List<Piece>>.multi((controller) {
      controller.add(_pieces.values.toList());
      final sub = _controller.stream.listen(controller.add);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<Result<Piece>> getPiece(String pieceId) async {
    final piece = _pieces[pieceId];
    if (piece == null) {
      return ResultFailure<Piece>(StateError('Unknown piece: $pieceId'));
    }
    return Success(piece);
  }

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
    String? ownerName,
  }) async {
    final now = DateTime(2024);
    final piece = Piece(
      id: 'piece_${_seq++}',
      title: title,
      basePdfChecksum: 'checksum-$sourcePath',
      basePdfPath: sourcePath,
      ownerId: ownerId,
      ownerName: ownerName,
      createdAt: now,
      updatedAt: now,
    );
    _pieces[piece.id] = piece;
    _controller.add(_pieces.values.toList());
    return Success(piece);
  }

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      throw UnimplementedError();

  @override
  Future<Result<void>> leavePiece(String pieceId) => throw UnimplementedError();

  @override
  Future<Result<void>> addCollaborator(
    String pieceId, {
    required String userId,
    String? name,
    String? email,
  }) async {
    final piece = _pieces[pieceId];
    if (piece == null) {
      return ResultFailure<void>(StateError('Unknown piece: $pieceId'));
    }
    final collaborators = [...piece.collaborators];
    final index = collaborators.indexWhere((c) => c.uid == userId);
    if (index >= 0) {
      final existing = collaborators[index];
      collaborators[index] = Collaborator(
        uid: userId,
        name: name ?? existing.name,
        email: email ?? existing.email,
      );
    } else {
      collaborators.add(Collaborator(uid: userId, name: name, email: email));
    }
    _pieces[pieceId] = piece.copyWith(collaborators: collaborators);
    _controller.add(_pieces.values.toList());
    return const Success(null);
  }

  @override
  Future<Result<void>> removeCollaborator(String pieceId, String userId) async {
    final piece = _pieces[pieceId];
    if (piece == null) {
      return ResultFailure<void>(StateError('Unknown piece: $pieceId'));
    }
    _pieces[pieceId] = piece.copyWith(
      collaborators: piece.collaborators.where((c) => c.uid != userId).toList(),
    );
    _controller.add(_pieces.values.toList());
    return const Success(null);
  }

  @override
  Future<Result<Piece>> pairCollaborator(
    String pieceId, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
    String? ownerName,
  }) => throw UnimplementedError();

  @override
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String ownerId,
    required String sourcePath,
    String? collaboratorId,
    String? ownerName,
    String? collaboratorName,
  }) => throw UnimplementedError();
}

/// A minimal in-memory [AnnotationRepository], permissive (no ownership
/// guard) — that guard is `LocalAnnotationRepository`'s job and is covered
/// airtight at the repository level in
/// `packages/core/pieces/test/local_annotation_repository_test.dart`. This
/// fake only needs to persist what `ScoreBloc` sends it and echo it back.
class FakeAnnotationRepository implements AnnotationRepository {
  final _byPiece = <String, PieceAnnotations>{};
  final _controller = StreamController<PieceAnnotations>.broadcast();

  PieceAnnotations _for(String pieceId) =>
      _byPiece[pieceId] ?? PieceAnnotations.empty(pieceId);

  void _emit(String pieceId, PieceAnnotations annotations) {
    _byPiece[pieceId] = annotations;
    _controller.add(annotations);
  }

  // Plain `StreamController` composition rather than an `async*` generator
  // — verified empirically that cancelling a subscription to a `yield*`-
  // delegating generator stream hangs `close()` in this sandbox.
  @override
  Stream<PieceAnnotations> watch(String pieceId) {
    return Stream<PieceAnnotations>.multi((controller) {
      controller.add(_for(pieceId));
      final sub = _controller.stream
          .where((a) => a.pieceId == pieceId)
          .listen(controller.add);
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Future<Result<void>> addStroke(String pieceId, InkStroke stroke) async {
    final current = _for(pieceId);
    final existing = current.layers.where((l) => l.ownerId == stroke.authorId);
    final layer = existing.isEmpty
        ? InkLayer(
            ownerId: stroke.authorId,
            role: stroke.authorId == ownerId
                ? PieceRole.owner
                : PieceRole.collaborator,
            strokes: [stroke],
          )
        : existing.first.copyWith(
            strokes: [...existing.first.strokes, stroke],
          );
    _emit(
      pieceId,
      PieceAnnotations(
        pieceId: pieceId,
        layers: [
          ...current.layers.where((l) => l.ownerId != stroke.authorId),
          layer,
        ],
        audioNotes: current.audioNotes,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> eraseStroke(String pieceId, String strokeId) async {
    final current = _for(pieceId);
    _emit(
      pieceId,
      PieceAnnotations(
        pieceId: pieceId,
        layers: [
          for (final layer in current.layers)
            layer.copyWith(
              strokes: layer.strokes.where((s) => s.id != strokeId).toList(),
            ),
        ],
        audioNotes: current.audioNotes,
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> addAudioNote(String pieceId, AudioNote note) async {
    final current = _for(pieceId);
    _emit(
      pieceId,
      PieceAnnotations(
        pieceId: pieceId,
        layers: current.layers,
        audioNotes: [...current.audioNotes, note],
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteAudioNote(String pieceId, String noteId) async {
    final current = _for(pieceId);
    _emit(
      pieceId,
      PieceAnnotations(
        pieceId: pieceId,
        layers: current.layers,
        audioNotes: current.audioNotes.where((n) => n.id != noteId).toList(),
      ),
    );
    return const Success(null);
  }

  @override
  Future<Result<void>> clearPiece(String pieceId) async {
    _emit(pieceId, PieceAnnotations.empty(pieceId));
    return const Success(null);
  }

  @override
  Future<Result<void>> replaceAuthorSlice(
    String pieceId,
    String authorId, {
    required PieceRole role,
    required List<InkStroke> strokes,
    required List<AudioNote> audioNotes,
  }) => throw UnimplementedError();

  @override
  Future<Result<void>> removeAuthorSlice(String pieceId, String authorId) =>
      throw UnimplementedError();
}

/// A minimal in-memory [AudioAssetStore] — `put`/`pathFor` never touch disk;
/// this flow never plays a note back, so `pathFor` is never actually
/// exercised.
class FakeAudioAssetStore implements AudioAssetStore {
  final _ids = <String>{};
  var _seq = 0;

  @override
  Future<Result<String>> put(String sourcePath) async {
    final id = 'asset_${_seq++}';
    _ids.add(id);
    return Success(id);
  }

  @override
  Future<Result<String>> pathFor(String assetId) async {
    if (!_ids.contains(assetId)) {
      return ResultFailure<String>(StateError('Unknown asset: $assetId'));
    }
    return Success(assetId);
  }

  @override
  Future<Result<void>> delete(String assetId) async {
    _ids.remove(assetId);
    return const Success(null);
  }
}

/// A bounded stand-in for `pumpAndSettle`: several fixed-duration pumps
/// rather than pumping until quiescence. `pumpAndSettle` hangs forever here
/// — verified empirically — because `LoadingView` (shown transiently by
/// `ImportPieceScreen`) uses an indeterminate `CircularProgressIndicator`,
/// whose repeating animation never lets the widget tree go quiet. This
/// flow's fakes resolve on the next microtask (no real delay), so a handful
/// of pumps is always enough to flush a state transition and any
/// bounded-duration route/sheet animation.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// The repositories/services a [runDuetImportFlow] call constructed, handed
/// back so the caller can continue the flow (either against a bare
/// `ScoreBloc`, headless, or the real `ScoreViewerScreen`, on-device).
class DuetImportFlowResult {
  const DuetImportFlowResult({
    required this.pieceRepository,
    required this.annotationRepository,
    required this.audioAssetStore,
    required this.renderService,
    required this.navigatorKey,
    required this.piece,
  });

  final FakePieceRepository pieceRepository;
  final FakeAnnotationRepository annotationRepository;
  final FakeAudioAssetStore audioAssetStore;
  final FakePdfRenderService renderService;
  final GlobalKey<NavigatorState> navigatorKey;
  final Piece piece;
}

/// Drives Acceptance #1 (import creates a piece) through the real
/// `feature_library` UI: pumps a `LibraryPage`, imports a PDF via the fake
/// picker/render service, and returns the resulting piece plus the shared
/// repositories, so the caller can continue into the Score Viewer.
Future<DuetImportFlowResult> runDuetImportFlow(
  WidgetTester tester, {
  Future<void> Function(String name)? shot,
}) async {
  Future<void> maybeShot(String name) async {
    if (shot != null) await shot(name);
  }

  final renderService = FakePdfRenderService();
  final pieceRepository = FakePieceRepository();
  final annotationRepository = FakeAnnotationRepository();
  final audioAssetStore = FakeAudioAssetStore();
  final navigatorKey = GlobalKey<NavigatorState>();
  Piece? importedPiece;

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      navigatorKey: navigatorKey,
      home: LibraryPage(
        pieceRepository: pieceRepository,
        renderService: renderService,
        currentUserId: ownerId,
        appName: 'Duet',
        onOpenScore: (piece) => importedPiece = piece,
        filePicker: () async => const PickedPdfFile(
          path: 'nocturne.pdf',
          suggestedTitle: 'Nocturne',
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1));

  // Library starts empty; import a sheet. The Import FAB is hidden on the
  // empty state (the redesigned gallery surfaces import via the empty-state
  // primary button instead), so drive the flow from that button.
  expect(find.text('Your library is empty'), findsOneWidget);
  await maybeShot('01_library_empty');

  await tester.tap(find.text('Import a sheet'));
  await settle(tester);
  await tester.tap(find.text('Choose PDF'));
  await settle(tester);
  expect(find.text('Nocturne'), findsOneWidget); // pre-filled title
  await maybeShot('02_import_naming');

  await tester.tap(find.text('Add sheet'));
  await settle(tester);

  final piece = importedPiece;
  if (piece == null) {
    fail('Import did not complete: onOpenScore was never called');
  }

  return DuetImportFlowResult(
    pieceRepository: pieceRepository,
    annotationRepository: annotationRepository,
    audioAssetStore: audioAssetStore,
    renderService: renderService,
    navigatorKey: navigatorKey,
    piece: piece,
  );
}
