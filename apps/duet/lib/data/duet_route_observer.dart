import 'dart:async';

import 'package:duet/data/duet_analytics.dart';
import 'package:flutter/widgets.dart';

/// The router-side half of M7.2's instrumentation (see [DuetAnalytics] for
/// the full seam map): a [NavigatorObserver] on the app's `GoRouter` that
/// logs a screen view per shown route.
///
/// go_router names its pages `state.name ?? state.path` — the route
/// *template* (`/score/:pieceId`), never the concrete location — so screen
/// names stay id-free (and PII-free). Routes without a name (transient
/// `MaterialPageRoute`s, sheets, dialogs) are skipped: transient UI is not
/// a destination.
///
/// The dedicated `/paywall` route also fires [DuetAnalytics.paywallShown],
/// completing the trio of paywall surfaces (the invite sheet's and inbox
/// banner's gates are bloc transitions, observed by
/// `DuetAnalyticsObserver`).
class DuetRouteObserver extends NavigatorObserver {
  /// Creates the observer over [analytics].
  DuetRouteObserver({required DuetAnalytics analytics})
    : _analytics = analytics;

  final DuetAnalytics _analytics;

  void _log(Route<dynamic>? route) {
    final name = route?.settings.name;
    if (name == null || name.isEmpty) return;
    unawaited(_analytics.screenViewed(screenName: name));
    if (name == '/paywall') unawaited(_analytics.paywallShown());
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _log(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _log(newRoute);
  }
}
