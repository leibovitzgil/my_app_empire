import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_email.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/domain/domain.dart';
import 'package:duet/features/library/library.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/injection.dart';
import 'package:duet/ui/migration_prompt.dart';
import 'package:duet/ui/score_page.dart';
import 'package:duet/ui/settings_page.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_paywall/feature_paywall.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:monetization/monetization.dart';
import 'package:pdf_rendering/pdf_rendering.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthBloc(authRepository: getIt<AuthRepository>()),
      child: const AppView(),
    );
  }
}

class AppView extends StatefulWidget {
  const AppView({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  final DeepLinkService _deepLinks = getIt<DeepLinkService>();
  late final StreamSubscription<Result<DeepLinkIntent>> _intentSubscription;
  late final StreamSubscription<AuthState> _authSubscription;
  late final GoRouter _router;
  DeepLinkIntent? _pendingIntent;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      redirect: _redirect,
      routes: [
        // `_redirect` immediately resolves `/` to `/login` or `/home`; this
        // builder only covers the transient frame between an auth change and
        // the next redirect evaluation.
        GoRoute(
          path: '/',
          builder: (context, state) => const LoadingView(),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(
            title: 'Duet',
            logo: AppLogoMark(icon: Icons.music_note),
          ),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const DuetSettingsPage(),
        ),
        GoRoute(
          path: '/paywall',
          builder: (context, state) => BlocProvider<PaywallBloc>(
            create: (_) =>
                PaywallBloc(monetizationService: getIt<MonetizationService>())
                  ..add(const PaywallStarted()),
            child: const PaywallScreen(),
          ),
        ),
        GoRoute(
          path: '/score/:pieceId',
          builder: (context, state) =>
              DuetScorePage(pieceId: state.pathParameters['pieceId']!),
        ),
        GoRoute(
          path: '/collaborators/:pieceId',
          builder: (context, state) {
            final pieceId = state.pathParameters['pieceId']!;
            final currentUserId = getIt<CurrentUser>().call();
            return CollaboratorsPage(
              pieceRepository: getIt<PieceRepository>(),
              pieceId: pieceId,
              currentUserId: currentUserId,
              onInvite: () => showInviteSheetFor(
                context,
                pieceId: pieceId,
                ownerId: currentUserId,
              ),
            );
          },
        ),
        GoRoute(
          path: '/invite/accept/:token',
          builder: (context, state) => AcceptInvitePage(
            inviteService: getIt<InviteService>(),
            pieceRepository: getIt<PieceRepository>(),
            monetizationService: getIt<MonetizationService>(),
            token: state.pathParameters['token']!,
            collaboratorId: getIt<CurrentUser>().call(),
            collaboratorName: getIt<CurrentUserName>().call(),
            collaboratorEmail: getIt<CurrentUserEmail>().call(),
            // Kept deliberately simple: land back on the (now-updated)
            // library rather than deep-navigating into the freshly-joined
            // sheet, so a failed/edge-case navigation here can never strand
            // the user outside the app.
            onAccepted: (_) => context.go('/home'),
          ),
        ),
      ],
    );
    _intentSubscription = _deepLinks.onIntent.listen((result) {
      if (result case Success<DeepLinkIntent>(:final value)) {
        _dispatchIntent(value);
      }
    });
    // Auth changes don't otherwise tell go_router to re-evaluate `_redirect`
    // (nothing navigates on their own), so this refresh-triggering
    // subscription drives both the signed-out → `/login` bounce and the
    // post-login consumption of a held intent.
    _authSubscription = context.read<AuthBloc>().stream.listen(
      (_) => _router.refresh(),
    );
    unawaited(_seedInitialIntent());
  }

  Future<void> _seedInitialIntent() async {
    final result = await _deepLinks.getInitialIntent();
    if (result case Success<DeepLinkIntent>(:final value)) {
      _dispatchIntent(value);
    }
  }

  /// Routes a deep-link intent. Signed in, it navigates immediately with
  /// `go` — which also collapses any pushed stack, so the destination is
  /// actually visible (a `refresh`-driven redirect can't do that: over a
  /// pushed stack go_router reports the base location, and an intent for
  /// that same base would be swallowed). Signed out, the intent is held for
  /// `_redirect` to consume right after login.
  void _dispatchIntent(DeepLinkIntent intent) {
    final authenticated =
        context.read<AuthBloc>().state.status == AuthStatus.authenticated;
    if (authenticated) {
      _router.go(intent.location);
      return;
    }
    _pendingIntent = intent;
    _router.refresh();
  }

  // The redirect owns ALL screen selection at the full-screen level: every
  // destination in this app is a go_router route, and auth decides which are
  // reachable. Signed out, everything funnels to `/login`; a deep link that
  // arrived while signed out is *held* (see `_dispatchIntent`) and consumed
  // here on the first post-login pass, winning over the default `/home`
  // landing — so a link opened while signed out survives the login
  // round-trip instead of dropping the user on a screen that needs an
  // identity.
  String? _redirect(BuildContext context, GoRouterState state) {
    final authStatus = context.read<AuthBloc>().state.status;
    final loggedIn = authStatus == AuthStatus.authenticated;
    final atLogin = state.matchedLocation == '/login';

    if (!loggedIn) return atLogin ? null : '/login';

    final pending = _pendingIntent;
    if (pending != null) {
      _pendingIntent = null;
      if (pending.location != state.matchedLocation) return pending.location;
    }
    if (atLogin || state.matchedLocation == '/') return '/home';
    return null;
  }

  @override
  void dispose() {
    unawaited(_intentSubscription.cancel());
    unawaited(_authSubscription.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      routerConfig: _router,
    );
  }
}

/// Opens the collaborator invite sheet for [pieceId] — shared by the
/// library's invite affordance and the collaborators route.
void showInviteSheetFor(
  BuildContext context, {
  required String pieceId,
  required String ownerId,
}) {
  unawaited(
    showInviteSheet(
      context,
      collaboratorInviteService: getIt<CollaboratorInviteService>(),
      inviteService: getIt<InviteService>(),
      monetizationService: getIt<MonetizationService>(),
      pieceRepository: getIt<PieceRepository>(),
      ownerId: ownerId,
      pieceId: pieceId,
      ownerName: getIt<CurrentUserName>().call(),
    ),
  );
}

/// The signed-in Home screen: `feature_library`'s unified Sheet Library,
/// wired with the cross-feature navigation callbacks it can't own directly.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = getIt<CurrentUser>().call();
    return Column(
      children: [
        // Nudges signed-in-but-unverified accounts (fresh sign-ups, M1.3);
        // renders nothing once verified or dismissed. Nothing gates on it.
        EmailVerificationBanner(
          accounts: getIt<AuthAccountProvider>().account,
          onResend: () => getIt<AuthRepository>().sendEmailVerification(),
          onRefresh: () => getIt<AuthAccountProvider>().refreshAccount(),
        ),
        // Offers a one-time upload of this device's local sheets to the
        // signed-in account on first cloud sign-in (M3.6); renders nothing and
        // is a no-op unless the Firebase composition registered a migrator.
        const MigrationPrompt(),
        Expanded(
          child: LibraryPage(
            pieceRepository: getIt<PieceRepository>(),
            renderService: getIt<PdfRenderService>(),
            binaryStore: getIt<PieceBinaryStore>(),
            currentUserId: currentUserId,
            // Full-screen destinations go through the router (score,
            // collaborators); transient UI (the invite sheet) stays an
            // overlay.
            onOpenScore: (piece) => context.push(
              '/score/${Uri.encodeComponent(piece.id)}',
            ),
            onInvitePiece: (piece) => showInviteSheetFor(
              context,
              pieceId: piece.id,
              ownerId: currentUserId,
            ),
            onOpenCollaborators: (piece) => context.push(
              '/collaborators/${Uri.encodeComponent(piece.id)}',
            ),
            // Offline sharing (M4.2): the `.duet` bundle escape hatch, moved
            // off the reader and onto Piece Detail. Live sync is the default
            // path now; these stay for airplane mode.
            onExportBundle: (piece) =>
                unawaited(_exportReviewBundle(context, piece)),
            onImportBundle: () => unawaited(_importReviewBundle(context)),
            onOpenSettings: () => context.push('/settings'),
            currentUserName: getIt<CurrentUserName>().call(),
            appName: 'Duet',
          ),
        ),
      ],
    );
  }
}

/// Exports [piece]'s annotations as a `.duet` review bundle and hands it to
/// the OS share sheet — the offline escape hatch surfaced from Piece Detail
/// (M4.2). Snackbars surface on the app-level messenger.
Future<void> _exportReviewBundle(BuildContext context, Piece piece) async {
  final exportResult = await getIt<ReviewSyncService>().exportBundle(piece.id);
  if (!context.mounted) return;
  switch (exportResult) {
    case Success<ExportedBundle>(:final value):
      final shareResult = await getIt<ReviewSyncService>().share(value);
      if (!context.mounted) return;
      if (shareResult case ResultFailure<void>(:final error)) {
        AppSnackbar.error(context, "Couldn't share: $error");
      }
    case ResultFailure<ExportedBundle>(:final error):
      AppSnackbar.error(context, "Couldn't export: $error");
  }
}

/// Picks a `.duet` review bundle and merges it via `ReviewSyncService` (M4.2).
Future<void> _importReviewBundle(BuildContext context) async {
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['duet'],
  );
  if (picked == null || picked.files.isEmpty) return;
  final path = picked.files.single.path;
  if (path == null || !context.mounted) return;
  final result = await getIt<ReviewSyncService>().importBundle(path);
  if (!context.mounted) return;
  switch (result) {
    case Success<ReviewBundleSummary>(:final value):
      AppSnackbar.success(
        context,
        'Imported ${value.strokeCount} strokes, '
        '${value.audioNoteCount} notes',
      );
    case ResultFailure<ReviewBundleSummary>(:final error):
      AppSnackbar.error(context, "Couldn't import: $error");
  }
}
