import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_email.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/injection.dart';
import 'package:duet/ui/score_page.dart';
import 'package:duet/ui/settings_page.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_library/feature_library.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:monetization/monetization.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';

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
        GoRoute(path: '/', builder: (context, state) => const _RootScreen()),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const DuetSettingsPage(),
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
    // A single subscription drives both updating `_pendingIntent` and
    // triggering go_router to re-run `_redirect`, in that order. Splitting
    // this into two independent subscriptions (e.g. a `GoRouterRefreshStream`
    // wired as `refreshListenable` alongside this listener) is racy: for a
    // broadcast stream, listeners fire in subscription order, so the
    // refresh-triggered redirect check could run before `_pendingIntent` is
    // actually set, silently dropping the very first navigation.
    _intentSubscription = _deepLinks.onIntent.listen((result) {
      if (result case Success<DeepLinkIntent>(:final value)) {
        setState(() => _pendingIntent = value);
        _router.refresh();
      }
    });
    // Auth changes don't otherwise tell go_router to re-evaluate `_redirect`
    // (nothing navigates on their own), so this refresh-triggering
    // subscription mirrors the deep-link one above.
    _authSubscription = context.read<AuthBloc>().stream.listen(
      (_) => _router.refresh(),
    );
    unawaited(_seedInitialIntent());
  }

  Future<void> _seedInitialIntent() async {
    final result = await _deepLinks.getInitialIntent();
    if (result case Success<DeepLinkIntent>(:final value)) {
      setState(() => _pendingIntent = value);
      _router.refresh();
    }
  }

  // The factory's reference redirect-wiring pattern for deep links: a pending
  // deep link always wins (e.g. an invite link arriving mid-session), and an
  // authenticated user never lingers on the bare `/` root — they land on the
  // library. No role gate anymore: sign-in leads straight to the library.
  String? _redirect(BuildContext context, GoRouterState state) {
    final pending = _pendingIntent;
    if (pending != null && pending.location != state.matchedLocation) {
      _pendingIntent = null;
      return pending.location;
    }
    final authStatus = context.read<AuthBloc>().state.status;
    if (authStatus != AuthStatus.authenticated) return null;
    if (state.matchedLocation == '/') return '/home';
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

class _RootScreen extends StatelessWidget {
  const _RootScreen();

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    if (authState.status == AuthStatus.authenticated) {
      // `AppView`'s redirect always diverts an authenticated user away from
      // `/` (to home) before this would otherwise render; this is just a safe
      // placeholder for the brief frame in between the auth state changing and
      // the next redirect evaluation.
      return const LoadingView();
    }
    return const LoginScreen(
      title: 'Duet',
      logo: AppLogoMark(icon: Icons.music_note),
    );
  }
}

/// The signed-in Home screen: `feature_library`'s unified Sheet Library,
/// wired with the cross-feature navigation callbacks it can't own directly.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = getIt<CurrentUser>().call();
    return LibraryPage(
      pieceRepository: getIt<PieceRepository>(),
      renderService: getIt<PdfRenderService>(),
      currentUserId: currentUserId,
      onOpenScore: (piece) => _openScore(context, piece),
      onInvitePiece: (piece) => _openInvite(context, piece, currentUserId),
      onOpenCollaborators: (piece) =>
          _openCollaborators(context, piece, currentUserId),
      onOpenSettings: () => context.push('/settings'),
      currentUserName: getIt<CurrentUserName>().call(),
      appName: 'Duet',
    );
  }

  void _openScore(BuildContext context, Piece piece) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => DuetScorePage(pieceId: piece.id),
        ),
      ),
    );
  }

  void _openInvite(BuildContext context, Piece piece, String ownerId) {
    unawaited(
      showInviteSheet(
        context,
        collaboratorInviteService: getIt<CollaboratorInviteService>(),
        inviteService: getIt<InviteService>(),
        monetizationService: getIt<MonetizationService>(),
        pieceRepository: getIt<PieceRepository>(),
        ownerId: ownerId,
        pieceId: piece.id,
        ownerName: getIt<CurrentUserName>().call(),
      ),
    );
  }

  void _openCollaborators(
    BuildContext context,
    Piece piece,
    String currentUserId,
  ) {
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => CollaboratorsPage(
            pieceRepository: getIt<PieceRepository>(),
            pieceId: piece.id,
            currentUserId: currentUserId,
            onInvite: () => _openInvite(context, piece, currentUserId),
          ),
        ),
      ),
    );
  }
}
