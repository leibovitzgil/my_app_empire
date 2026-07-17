import 'dart:async';

import 'package:duet/data/duet_analytics.dart';
import 'package:duet/features/library/library.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/features/score/score.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// The single bloc-side funnel-instrumentation seam (M7.2): one app-level
/// [BlocObserver] that translates feature bloc/cubit transitions into
/// [DuetAnalytics] catalogue calls, so feature code never carries an
/// analytics dependency (G3). The full seam map lives on [DuetAnalytics].
///
/// Dispatch is keyed on state/event *types*, not bloc types, so it works
/// wherever a bloc is constructed (route builder, sheet, banner). Blocs are
/// handled in [onTransition] (which carries the triggering event — needed to
/// tell a purchase from a restore, or a note save from a remote-sync note);
/// cubits, which have no events, in [onChange]. [onChange] skips [Bloc]s so
/// nothing is counted twice.
class DuetAnalyticsObserver extends BlocObserver {
  /// Creates the observer over [analytics].
  DuetAnalyticsObserver({required DuetAnalytics analytics})
    : _analytics = analytics;

  final DuetAnalytics _analytics;

  /// Auth blocs with a sign-up in flight. Sign-up success only surfaces as a
  /// later authenticated transition (the repository's user stream flips it),
  /// so the intent is remembered from the event until that transition — or
  /// dropped on failure, so a later plain login is never counted as a
  /// sign-up. An [Expando] so closed blocs don't leak.
  final Expando<bool> _signUpInFlight = Expando<bool>();

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    super.onEvent(bloc, event);
    if (event is AuthSignUpRequested) _signUpInFlight[bloc] = true;
    // The reader's `_saveAudioNote` success path dispatches exactly one
    // `AudioNoteSaved` per saved recording. It rides `onEvent` (not
    // `onTransition`) because the handler emits nothing on success — the
    // notes list refreshes via the annotations stream instead.
    if (event is AudioNoteSaved) {
      unawaited(_analytics.noteRecorded(durationMs: event.note.durationMs));
    }
  }

  @override
  void onTransition(
    Bloc<dynamic, dynamic> bloc,
    Transition<dynamic, dynamic> transition,
  ) {
    super.onTransition(bloc, transition);
    final event = transition.event;
    final current = transition.currentState;
    final next = transition.nextState;

    if (current is ImportPieceState && next is ImportPieceState) {
      final piece = next.piece;
      if (current.status != ImportStatus.success &&
          next.status == ImportStatus.success &&
          piece != null) {
        unawaited(_analytics.sheetImported(pieceId: piece.id));
      }
      return;
    }

    if (current is InviteState && next is InviteState) {
      if (current.status != InviteStatus.sent &&
          next.status == InviteStatus.sent) {
        unawaited(
          _analytics.inviteSent(
            method: next.link != null
                ? DuetInviteMethod.link
                : DuetInviteMethod.email,
          ),
        );
      }
      if (current.status != InviteStatus.paywallRequired &&
          next.status == InviteStatus.paywallRequired) {
        unawaited(_analytics.paywallShown());
      }
      return;
    }

    if (next is ScoreState) {
      if (event is RegionSelectCompleted &&
          next.regionIntent == RegionIntent.practice &&
          next.activeRegion != null) {
        unawaited(_analytics.practiceOpened());
      }
      return;
    }

    if (next is PaywallState) {
      if (event is PaywallPackagePurchased &&
          next.status == PaywallStatus.purchased) {
        unawaited(_analytics.purchaseCompleted());
      }
      return;
    }

    if (current is AuthState && next is AuthState) {
      if (next.status == AuthStatus.authenticated &&
          current.status != AuthStatus.authenticated) {
        if (_signUpInFlight[bloc] ?? false) {
          _signUpInFlight[bloc] = false;
          unawaited(_analytics.signUp());
        }
      } else if (next.status == AuthStatus.failure) {
        _signUpInFlight[bloc] = false;
      }
    }
  }

  @override
  void onChange(BlocBase<dynamic> bloc, Change<dynamic> change) {
    super.onChange(bloc, change);
    // Blocs are fully handled in onTransition; only cubits land here.
    if (bloc is Bloc) return;
    final current = change.currentState;
    final next = change.nextState;

    if (current is InviteInboxState && next is InviteInboxState) {
      if (current.status != InviteInboxStatus.accepted &&
          next.status == InviteInboxStatus.accepted) {
        unawaited(
          _analytics.inviteAccepted(method: DuetInviteMethod.email),
        );
      }
      if (current.status != InviteInboxStatus.atCap &&
          next.status == InviteInboxStatus.atCap) {
        unawaited(_analytics.paywallShown());
      }
      return;
    }

    if (current is AcceptInviteState && next is AcceptInviteState) {
      if (current.status != AcceptInviteStatus.accepted &&
          next.status == AcceptInviteStatus.accepted) {
        unawaited(
          _analytics.inviteAccepted(method: DuetInviteMethod.link),
        );
      }
    }
  }
}
