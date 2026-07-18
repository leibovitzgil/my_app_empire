// Headless mirror of the Duet core-loop flow (import -> annotate -> record
// an audio note -> toggle layers -> clean workspace -> close/reopen), so it
// runs in the standard gate without a device. See `duet_flow_harness.dart`
// for why this continues against a bare `ScoreBloc` rather than the real
// `ScoreViewerScreen` (the widget-mounting variant lives in
// `integration_test/app_flow_test.dart`, device-only).
import 'package:core_utils/core_utils.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/library/library.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/features/score/score.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:user_directory/user_directory.dart';

import 'duet_flow_harness.dart';

/// The invitee's view over the shared [FakePieceRepository]: only pieces
/// where [collaboratorId] is actually a collaborator. The fake itself has no
/// per-viewer scoping (the real backends scope `watchPieces` to the caller),
/// so without this the invited sheet would sit in the collaborator's gallery
/// *before* they accept — hiding exactly the live-update this flow proves.
class _CollaboratorLibraryView implements PieceRepository {
  const _CollaboratorLibraryView({
    required this.inner,
    required this.collaboratorId,
  });

  final FakePieceRepository inner;
  final String collaboratorId;

  @override
  Stream<List<Piece>> watchPieces() => inner.watchPieces().map(
    (pieces) => pieces.where((p) => p.isCollaborator(collaboratorId)).toList(),
  );

  @override
  Stream<Map<String, DateTime>> watchReads() => inner.watchReads();

  @override
  Future<Result<void>> markOpened(String pieceId) => inner.markOpened(pieceId);

  @override
  Future<Result<Piece>> getPiece(String pieceId) => inner.getPiece(pieceId);

  @override
  Future<Result<Piece>> importPiece({
    required String title,
    required String sourcePath,
    String? ownerName,
  }) => inner.importPiece(
    title: title,
    sourcePath: sourcePath,
    ownerName: ownerName,
  );

  @override
  Future<Result<void>> renamePiece(String pieceId, String title) =>
      inner.renamePiece(pieceId, title);

  @override
  Future<Result<void>> deletePiece(String pieceId) =>
      inner.deletePiece(pieceId);

  @override
  Future<Result<void>> leavePiece(String pieceId) => inner.leavePiece(pieceId);

  @override
  Future<Result<void>> addCollaborator(
    String pieceId, {
    required String userId,
    String? name,
    String? email,
  }) => inner.addCollaborator(
    pieceId,
    userId: userId,
    name: name,
    email: email,
  );

  @override
  Future<Result<void>> removeCollaborator(String pieceId, String userId) =>
      inner.removeCollaborator(pieceId, userId);

  @override
  Future<Result<Piece>> pairCollaborator(
    String pieceId, {
    required String collaboratorId,
    String? collaboratorName,
    String? collaboratorEmail,
    String? ownerName,
  }) => inner.pairCollaborator(
    pieceId,
    collaboratorId: collaboratorId,
    collaboratorName: collaboratorName,
    collaboratorEmail: collaboratorEmail,
    ownerName: ownerName,
  );

  @override
  Future<Result<Piece>> registerImportedPiece({
    required String pieceId,
    required String title,
    required String ownerId,
    required String sourcePath,
    String? collaboratorId,
    String? ownerName,
    String? collaboratorName,
  }) => inner.registerImportedPiece(
    pieceId: pieceId,
    title: title,
    ownerId: ownerId,
    sourcePath: sourcePath,
    collaboratorId: collaboratorId,
    ownerName: ownerName,
    collaboratorName: collaboratorName,
  );
}

void main() {
  testWidgets(
    'import (real UI) -> annotate -> record audio note -> toggle layers -> '
    'clean workspace -> close/reopen (bloc-level, against the sheet the '
    'real import UI created)',
    (tester) async {
      final imported = await runDuetImportFlow(tester);
      final pieceRepository = imported.pieceRepository;
      final annotationRepository = imported.annotationRepository;
      final piece = imported.piece;

      ScoreBloc openScore() => ScoreBloc(
        pieceRepository: pieceRepository,
        annotationRepository: annotationRepository,
        currentUserId: ownerId,
      )..add(ScoreOpened(piece.id));

      final bloc = openScore();
      await tester.pump();
      await tester.pump();
      expect(bloc.state.status, ScoreStatus.ready);

      // 2. Owner draws a stroke; ink lands on the owner's own layer only,
      // never a (nonexistent, uninvited) collaborator's.
      bloc
        ..add(const ModeChanged(ScoreMode.draw))
        ..add(
          const StrokeCompleted([
            InkPoint(x: 0.2, y: 0.2),
            InkPoint(x: 0.6, y: 0.5),
          ]),
        );
      await tester.pump();
      await tester.pump();
      // On a sheet with no collaborators there is exactly one participant
      // layer — the owner's — and the stroke lands on it.
      expect(bloc.state.layers, hasLength(1));
      final ownLayer = bloc.state.ownLayer!;
      expect(ownLayer.ownerId, ownerId);
      expect(ownLayer.isOwn, isTrue);
      expect(ownLayer.strokes, hasLength(1));
      expect(ownLayer.strokes.single.authorId, ownerId);

      // 3. Region-select a passage and record an audio note on it.
      bloc
        ..add(const ModeChanged(ScoreMode.view))
        ..add(const RegionSelectStarted(RegionIntent.recordAudio))
        ..add(
          const RegionSelectCompleted(
            Region(pageIndex: 0, left: 0.3, top: 0.4, width: 0.2, height: 0.15),
          ),
        )
        ..add(
          AudioNoteSaved(
            AudioNote(
              id: 'note-1',
              authorId: ownerId,
              audioAssetId: 'asset-1',
              pageIndex: 0,
              durationMs: 4000,
              region: const Region(
                pageIndex: 0,
                left: 0.3,
                top: 0.4,
                width: 0.2,
                height: 0.15,
              ),
              createdAt: DateTime(2024),
            ),
            'rec_0.m4a',
          ),
        );
      await tester.pump();
      await tester.pump();

      expect(bloc.state.notes, hasLength(1));
      final recordedNote = bloc.state.notes.single;
      expect(recordedNote.authorId, ownerId);
      expect(
        recordedNote.region,
        const Region(
          pageIndex: 0,
          left: 0.3,
          top: 0.4,
          width: 0.2,
          height: 0.15,
        ),
      );

      // 4. Layer toggles are independent and immediate: toggling the owner's
      // ink layer off leaves audio pins untouched.
      bloc.add(const InkLayerToggled(ownerId));
      await tester.pump();
      expect(bloc.state.ownLayer!.visible, isFalse);
      expect(bloc.state.hiddenInkOwnerIds, {ownerId});
      expect(bloc.state.audioPinsVisible, isTrue);

      // 5. Clean workspace hides every layer regardless of its own flag...
      bloc.add(const CleanWorkspaceToggled());
      await tester.pump();
      expect(bloc.state.cleanWorkspace, isTrue);
      for (final layer in bloc.state.layers) {
        expect(bloc.state.effectiveInkVisible(layer), isFalse);
      }
      expect(bloc.state.effectiveAudioPinsVisible, isFalse);

      // ...a layer toggled *while* masked still updates its underlying
      // flag...
      bloc.add(const AudioPinsToggled());
      await tester.pump();
      expect(bloc.state.audioPinsVisible, isFalse);
      expect(bloc.state.effectiveAudioPinsVisible, isFalse); // still masked

      // ...and turning clean workspace off restores the *exact* prior
      // per-layer state — the owner's ink still off, audio pins now off (the
      // change made while masked) — never a reset to some default.
      bloc.add(const CleanWorkspaceToggled());
      await tester.pump();
      expect(bloc.state.cleanWorkspace, isFalse);
      expect(bloc.state.ownLayer!.visible, isFalse);
      expect(bloc.state.audioPinsVisible, isFalse);

      // 6. "Close and reopen the sheet": a brand-new `ScoreBloc` — not the
      // one already in memory — reads the *same* (repository-backed)
      // annotation repository and sees the same stroke and audio note (at
      // the same fractional position). The original bloc is deliberately
      // left open rather than `close()`d first (awaiting `close()` here hit
      // this sandbox's same real-event-loop-turn limitation noted in
      // `duet_flow_harness.dart` — verified empirically); both are closed at
      // teardown instead.
      addTearDown(bloc.close);
      final reopened = openScore();
      addTearDown(reopened.close);
      await tester.pump();
      await tester.pump();

      expect(reopened.state.ownLayer!.strokes, hasLength(1));
      expect(reopened.state.notes, hasLength(1));
      expect(reopened.state.notes.single.region, recordedNote.region);
    },
  );

  testWidgets(
    'email invite -> pending-invite banner over the invitee library -> '
    'accept via the banner UI (M5.6): the sheet joins the gallery live and '
    'records the collaborator with their email (AC-1, AC-2)',
    (tester) async {
      const collaboratorId = 'collaborator-e2e';
      const collaboratorEmail = 'friend@duet.dev';

      final imported = await runDuetImportFlow(tester);
      final pieceRepository = imported.pieceRepository;
      final piece = imported.piece;

      // One shared `InMemoryUserMessaging` instance backs both contracts —
      // mirroring `injection.dart`'s default-gate binding — so the owner's
      // `sendInvite` is immediately visible on the invitee's `watchInvites`
      // stream within this process.
      final messaging = InMemoryUserMessaging();
      final directory = InMemoryUserDirectory(
        seed: const [
          DirectoryUser(
            uid: collaboratorId,
            email: collaboratorEmail,
            displayName: 'Friend',
          ),
        ],
      );
      final inviteService = DefaultCollaboratorInviteService(
        userDirectory: directory,
        pieceRepository: pieceRepository,
        monetizationService: FakeMonetizationService(),
        messageGateway: messaging,
      );

      // 1. Owner sends an email invite; it resolves to the seeded friend
      // account and a message lands in their inbox (the foreground/
      // warm-start delivery bridge itself — surfacing that as a device
      // notification — is `injection.dart`'s app-level concern, covered at
      // the unit level by `services/notifications`' own tests).
      final sendResult = await inviteService.sendInvite(
        pieceId: piece.id,
        ownerId: ownerId,
        email: collaboratorEmail,
        ownerName: 'Owner',
      );
      expect(sendResult.isSuccess, isTrue);
      expect((sendResult as Success<LookupOutcome>).value, isA<Resolved>());

      // 2. The invitee's Home surface: the pending-invite banner (M5.6)
      // over their — initially empty — library, exactly as `app.dart`'s
      // `HomeScreen` composes them.
      String? acceptedPieceId;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: Scaffold(
            body: Column(
              children: [
                InviteInboxBanner(
                  collaboratorInviteService: inviteService,
                  messageGateway: messaging,
                  monetizationService: FakeMonetizationService(),
                  currentUserId: collaboratorId,
                  currentUserName: 'Friend',
                  currentUserEmail: collaboratorEmail,
                  onAccepted: (pieceId) => acceptedPieceId = pieceId,
                ),
                Expanded(
                  child: LibraryPage(
                    pieceRepository: _CollaboratorLibraryView(
                      inner: pieceRepository,
                      collaboratorId: collaboratorId,
                    ),
                    renderService: imported.renderService,
                    binaryStore: const NoopPieceBinaryStore(),
                    currentUserId: collaboratorId,
                    appName: 'Duet',
                    onOpenScore: (_) {},
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await settle(tester);

      // The banner surfaces the invite; the gallery has nothing yet — the
      // invitee is not a collaborator until they accept.
      expect(
        find.text('Owner invited you to collaborate on a sheet.'),
        findsOneWidget,
      );
      expect(find.text('Your library is empty'), findsOneWidget);

      // 3. Accept from the banner: the accept path consumes the invite (the
      // banner clears), fires the navigation callback with the piece id, and
      // the gallery below live-updates via `watchPieces`.
      await tester.tap(find.text('Accept'));
      await settle(tester);

      expect(acceptedPieceId, piece.id);
      expect(find.text('Accept'), findsNothing);
      expect(find.text('Nocturne'), findsWidgets);

      // The sheet now records the invitee as a collaborator, with their
      // email attached (AC-2).
      final updated = (await pieceRepository.getPiece(piece.id)).orThrow();
      expect(updated.isCollaborator(collaboratorId), isTrue);
      final collaborator = updated.collaborators.firstWhere(
        (c) => c.uid == collaboratorId,
      );
      expect(collaborator.email, collaboratorEmail);
      expect(collaborator.name, 'Friend');
    },
  );
}
