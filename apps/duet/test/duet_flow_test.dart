// Headless mirror of the Duet core-loop flow (import -> annotate -> record
// an audio note -> toggle layers -> clean workspace -> close/reopen), so it
// runs in the standard gate without a device. See `duet_flow_harness.dart`
// for why this continues against a bare `ScoreBloc` rather than the real
// `ScoreViewerScreen` (the widget-mounting variant lives in
// `integration_test/app_flow_test.dart`, device-only).
import 'package:core_utils/core_utils.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:feature_score/feature_score.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notifications/notifications.dart';
import 'package:pieces/pieces.dart';
import 'package:user_directory/user_directory.dart';

import 'duet_flow_harness.dart';

void main() {
  testWidgets(
    'import (real UI) -> annotate -> record audio note -> toggle layers -> '
    'clean workspace -> close/reopen (bloc-level, against the piece the '
    'real import UI created)',
    (tester) async {
      final imported = await runDuetImportFlow(tester);
      final pieceRepository = imported.pieceRepository;
      final annotationRepository = imported.annotationRepository;
      final piece = imported.piece;

      ScoreBloc openScore() => ScoreBloc(
        pieceRepository: pieceRepository,
        annotationRepository: annotationRepository,
        currentUserId: teacherId,
      )..add(ScoreOpened(piece.id));

      final bloc = openScore();
      await tester.pump();
      await tester.pump();
      expect(bloc.state.status, ScoreStatus.ready);

      // 2. Teacher draws a stroke; ink lands on the teacher's own layer
      // only, never the (nonexistent, unpaired) student's.
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
      // On an unpaired piece there is exactly one participant layer — the
      // owner's — and the stroke lands on it.
      expect(bloc.state.layers, hasLength(1));
      final ownLayer = bloc.state.ownLayer!;
      expect(ownLayer.ownerId, teacherId);
      expect(ownLayer.isOwn, isTrue);
      expect(ownLayer.strokes, hasLength(1));
      expect(ownLayer.strokes.single.authorId, teacherId);

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
              authorId: teacherId,
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
      expect(recordedNote.authorId, teacherId);
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
      bloc.add(const InkLayerToggled(teacherId));
      await tester.pump();
      expect(bloc.state.ownLayer!.visible, isFalse);
      expect(bloc.state.hiddenInkOwnerIds, {teacherId});
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

      // 6. "Close and reopen the piece": a brand-new `ScoreBloc` — not the
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
    'email invite -> (foreground) inbox delivery -> accept, over the shared '
    'in-memory message gateway, records the collaborator with their email '
    '(AC-1, AC-2)',
    (tester) async {
      const studentId = 'student-e2e';
      const studentEmail = 'student@duet.dev';

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
            uid: studentId,
            email: studentEmail,
            displayName: 'Student',
          ),
        ],
      );
      final inviteService = DefaultCollaboratorInviteService(
        userDirectory: directory,
        pieceRepository: pieceRepository,
        monetizationService: FakeMonetizationService(),
        messageGateway: messaging,
      );

      // 1. Owner sends an email invite; it resolves to the seeded student
      // account and a message lands in their inbox (the foreground/
      // warm-start delivery bridge itself — surfacing that as a device
      // notification — is `injection.dart`'s app-level concern, covered at
      // the unit level by `services/notifications`' own tests).
      final sendResult = await inviteService.sendInvite(
        pieceId: piece.id,
        ownerId: teacherId,
        email: studentEmail,
        ownerName: 'Teacher',
      );
      expect(sendResult.isSuccess, isTrue);
      expect((sendResult as Success<LookupOutcome>).value, isA<Resolved>());

      final invites = await inviteService.watchInvites(studentId).first;
      expect(invites, hasLength(1));
      expect(invites.single.pieceId, piece.id);
      expect(invites.single.ownerId, teacherId);

      // 2. The invitee accepts; the piece now records them as a
      // collaborator, with their email attached (AC-2).
      final acceptResult = await inviteService.acceptInvite(
        invites.single,
        accepterId: studentId,
        accepterName: 'Student',
        accepterEmail: studentEmail,
      );
      expect(acceptResult.isSuccess, isTrue);

      final updated = (await pieceRepository.getPiece(piece.id)).orThrow();
      expect(updated.isCollaborator(studentId), isTrue);
      final collaborator = updated.collaborators.firstWhere(
        (c) => c.uid == studentId,
      );
      expect(collaborator.email, studentEmail);
      expect(collaborator.name, 'Student');
    },
  );
}
