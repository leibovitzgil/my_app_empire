import 'package:analytics/analytics.dart';

/// How an invite travelled: the primary email path or the tokenized
/// deep-link fallback.
enum DuetInviteMethod {
  /// The primary email-invite path (`CollaboratorInviteService`).
  email,

  /// The tokenized deep-link fallback path (`InviteService`).
  link,
}

/// Duet's typed analytics catalogue (M7.2): every funnel event the app emits,
/// as a named method over the factory's free-form [AppLogger] — the generic
/// package stays generic; the catalogue (and its event names) is app glue.
///
/// ## Instrumentation seam — decided once, here
///
/// Feature code stays 100% analytics-free (G3). All funnel instrumentation
/// lives in exactly two app-glue observers, chosen over per-callsite
/// callbacks so no feature bloc, screen, or service ever grows an analytics
/// dependency or callback parameter:
///
/// - `DuetAnalyticsObserver` (`Bloc.observer`, set in `injection.dart`)
///   translates bloc/cubit state transitions into catalogue calls:
///   - [sheetImported] — `ImportPieceBloc` reaching `ImportStatus.success`;
///   - [inviteSent] — `InviteBloc` reaching `InviteStatus.sent` (method from
///     whether a link was created or an email invite resolved);
///   - [inviteAccepted] — BOTH accept paths: `InviteInboxCubit` reaching
///     `accepted` (email, M5.6 in-app inbox) and `AcceptInviteCubit`
///     reaching `accepted` (link, M5.2 token accept);
///   - [noteRecorded] — `ScoreBloc` processing `AudioNoteSaved` (the
///     `_saveAudioNote` success path dispatches it, carrying `durationMs`);
///   - [practiceOpened] — `ScoreBloc` processing `RegionSelectCompleted`
///     with the practice intent (the exact transition that opens
///     `PracticeView`);
///   - [paywallShown] — `InviteBloc` reaching `paywallRequired` and
///     `InviteInboxCubit` reaching `atCap`, the two transitions that swap
///     `PaywallScreen` in. (`PaywallBloc` creation is deliberately NOT the
///     signal: the invite sheet constructs one eagerly even when unshown.)
///   - [purchaseCompleted] — `PaywallBloc` completing a
///     `PaywallPackagePurchased` event (restores excluded on purpose);
///   - [signUp] — `AuthBloc` flipping to authenticated after an
///     `AuthSignUpRequested` (a plain login never fires it).
/// - `DuetRouteObserver` (on the `GoRouter` in `app.dart`) logs
///   [screenViewed] per pushed route — go_router names pages with the route
///   *template* (`/score/:pieceId`), so no ids leak — and [paywallShown]
///   for the dedicated `/paywall` route.
///
/// ## No PII
///
/// Params carry opaque ids and enums only — NEVER an email address, display
/// name, or free-typed text.
class DuetAnalytics {
  /// Creates the catalogue over the given [AppLogger].
  DuetAnalytics(this._logger);

  final AppLogger _logger;

  /// A sheet PDF finished importing (create + base-PDF upload).
  Future<void> sheetImported({required String pieceId}) =>
      _logger.logEvent('sheet_imported', {'piece_id': pieceId});

  /// A collaborator invite was sent ([DuetInviteMethod.email]) or an invite
  /// link created ([DuetInviteMethod.link]).
  Future<void> inviteSent({required DuetInviteMethod method}) =>
      _logger.logEvent('invite_sent', {'method': method.name});

  /// An invite was accepted, via the in-app inbox
  /// ([DuetInviteMethod.email]) or a resolved token
  /// ([DuetInviteMethod.link]).
  Future<void> inviteAccepted({required DuetInviteMethod method}) =>
      _logger.logEvent('invite_accepted', {'method': method.name});

  /// An audio note was recorded and saved onto a passage.
  Future<void> noteRecorded({required int durationMs}) =>
      _logger.logEvent('note_recorded', {'duration_ms': durationMs});

  /// The practice view was opened for a passage or page.
  Future<void> practiceOpened() => _logger.logEvent('practice_opened');

  /// The paywall became visible (route, invite-sheet gate, or inbox
  /// at-cap gate).
  Future<void> paywallShown() => _logger.logEvent('paywall_shown');

  /// A purchase completed successfully (restores are not counted).
  Future<void> purchaseCompleted() => _logger.logEvent('purchase_completed');

  /// A new account was created (never fired for a plain login).
  Future<void> signUp() => _logger.logEvent('sign_up');

  /// A full-screen route was shown. [screenName] is the route template
  /// (e.g. `/score/:pieceId`), never a concrete location with ids.
  Future<void> screenViewed({required String screenName}) =>
      _logger.logEvent('screen_view', {'screen_name': screenName});
}
