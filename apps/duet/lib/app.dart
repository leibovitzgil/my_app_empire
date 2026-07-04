import 'dart:async';

import 'package:core_ui/core_ui.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/data/current_user.dart';
import 'package:duet/data/current_user_name.dart';
import 'package:duet/injection.dart';
import 'package:duet/ui/role_selection/role_selection_cubit.dart';
import 'package:duet/ui/role_selection_screen.dart';
import 'package:duet/ui/score_page.dart';
import 'package:duet/ui/settings_page.dart';
import 'package:feature_auth/feature_auth.dart';
import 'package:feature_library/feature_library.dart';
import 'package:feature_pairing/feature_pairing.dart' hide DuetPermissions;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:monetization/monetization.dart';
import 'package:pdf_rendering/pdf_rendering.dart';
import 'package:pieces/pieces.dart';
import 'package:user_roles/user_roles.dart';

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
  late final StreamSubscription<AppRole> _roleSubscription;
  late final GoRouter _router;
  DeepLinkIntent? _pendingIntent;
  AppRole _currentRole = AppRole.guest;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      redirect: _redirect,
      routes: [
        GoRoute(path: '/', builder: (context, state) => const _RootScreen()),
        GoRoute(
          path: '/role-selection',
          builder: (context, state) => BlocProvider<RoleSelectionCubit>(
            create: (_) => RoleSelectionCubit(
              userRoleRepository: getIt<UserRoleRepository>(),
              currentUserId: getIt<CurrentUser>().call,
            ),
            child: RoleSelectionScreen(
              onConfirmed: () => context.go('/home'),
            ),
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
          path: '/invite/accept/:token',
          builder: (context, state) => AcceptInvitePage(
            inviteService: getIt<InviteService>(),
            token: state.pathParameters['token']!,
            studentId: getIt<CurrentUser>().call(),
            studentName: getIt<CurrentUserName>().call(),
            // Kept deliberately simple: land back on the (now-updated)
            // library rather than deep-navigating into the freshly-paired
            // piece, so a failed/edge-case navigation here can never strand
            // the student outside the app.
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
    // Auth and role changes don't otherwise tell go_router to re-evaluate
    // `_redirect` (nothing navigates on their own), so each gets its own
    // refresh-triggering subscription, mirroring the deep-link one above.
    _authSubscription = context.read<AuthBloc>().stream.listen(
      (_) => _router.refresh(),
    );
    _roleSubscription = getIt<UserRoleRepository>().currentRole.listen((
      role,
    ) {
      setState(() => _currentRole = role);
      _router.refresh();
    });
    unawaited(_seedInitialIntent());
  }

  Future<void> _seedInitialIntent() async {
    final result = await _deepLinks.getInitialIntent();
    if (result case Success<DeepLinkIntent>(:final value)) {
      setState(() => _pendingIntent = value);
      _router.refresh();
    }
  }

  // The factory's reference redirect-wiring pattern for deep links, extended
  // with Duet's post-signup role-selection gate: an authenticated user with
  // no role yet is always sent to `/role-selection` (except a pending deep
  // link, which always wins — e.g. an invite link arriving mid-session
  // shouldn't be swallowed by the role gate), and a role-selected user never
  // lingers on `/role-selection` or the bare `/` root.
  String? _redirect(BuildContext context, GoRouterState state) {
    final pending = _pendingIntent;
    if (pending != null && pending.location != state.matchedLocation) {
      _pendingIntent = null;
      return pending.location;
    }
    final authStatus = context.read<AuthBloc>().state.status;
    if (authStatus != AuthStatus.authenticated) return null;
    final onRoleSelection = state.matchedLocation == '/role-selection';
    if (_currentRole == AppRole.guest) {
      return onRoleSelection ? null : '/role-selection';
    }
    if (onRoleSelection || state.matchedLocation == '/') {
      return '/home';
    }
    return null;
  }

  @override
  void dispose() {
    unawaited(_intentSubscription.cancel());
    unawaited(_authSubscription.cancel());
    unawaited(_roleSubscription.cancel());
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
      // `/` (to role-selection or home) before this would otherwise render;
      // this is just a safe placeholder for the brief frame in between the
      // auth state changing and the next redirect evaluation.
      return const LoadingView();
    }
    return const LoginScreen(
      title: 'Duet',
      logo: AppLogoMark(icon: Icons.music_note),
    );
  }
}

/// The signed-in, role-selected Home screen: `feature_library`'s Home /
/// Piece List, wired with the cross-feature navigation callbacks it can't
/// own directly.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUserId = getIt<CurrentUser>().call();
    final isTeacher = getIt<UserRoleRepository>().hasPermission(
      DuetPermissions.importPiece,
    );
    return LibraryPage(
      pieceRepository: getIt<PieceRepository>(),
      renderService: getIt<PdfRenderService>(),
      userRoleRepository: getIt<UserRoleRepository>(),
      currentUserId: currentUserId,
      currentRole: isTeacher ? PieceRole.teacher : PieceRole.student,
      onOpenScore: (piece) => _openScore(context, piece),
      onInvitePiece: (piece) => _openInvite(context, piece, currentUserId),
      onOpenSettings: () => context.push('/settings'),
      currentUserName: getIt<CurrentUserName>().call(),
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

  void _openInvite(BuildContext context, Piece piece, String teacherId) {
    unawaited(
      showInviteSheet(
        context,
        inviteService: getIt<InviteService>(),
        monetizationService: getIt<MonetizationService>(),
        pieceRepository: getIt<PieceRepository>(),
        teacherId: teacherId,
        pieceId: piece.id,
        teacherName: getIt<CurrentUserName>().call(),
      ),
    );
  }
}
