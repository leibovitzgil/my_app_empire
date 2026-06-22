# Known Issues

The workspace bootstraps, lints, formats, and tests cleanly
(`melos run lint && melos run test && melos run format-check`). The items below
are resolved; remaining notes are optional structural cleanups with no
functional impact.

## Resolved

- **Workspace could not bootstrap.** Two packages were named `notifications`
  (`core/` + `services/`) and two `remote_config`, which Melos rejects. The
  "restructure packages" commit moved both to `services/` but left the `core/`
  copies behind. The orphaned `core/notifications` and `core/remote_config`
  duplicates were removed; nothing depended on them.
- **`monetization` + `feature_paywall`** — `revenue_cat_service.dart` returned a
  `PurchaseResult` where `Future<CustomerInfo?>` was declared, and used the
  deprecated `Purchases.purchasePackage`. Migrated to
  `Purchases.purchase(PurchaseParams.package(...))` and return
  `result.customerInfo`.
- **`services/notifications`** — the mockito mocks
  (`notifications_manager_test.mocks.dart`) were never generated. Generated and
  committed them (CI does not run `build_runner`).
- **`analytics` + `analytics_logger`** — `inference_failure_on_function_invocation`
  on `mocktail`'s `any()`; added explicit type arguments.
- **`review_prompter`** — `invalid_assignment` of `dynamic` to `int`/`bool` in
  tests; added explicit casts.
- **`template_app`** — removed an unused import, sorted `pubspec` dependencies,
  disabled `public_member_api_docs` (apps don't expose a public API), and made
  the widget test settle its animation/timer so it no longer fails on
  `!timersPending`.
- **`core_ui`** — removed an unnecessary `library` directive and sorted
  dependencies.
- **`include_file_not_found`** — `notifications` and `review_prompter` had a
  redundant local `analysis_options.yaml` that re-`include`d the root (which
  references `package:very_good_analysis`) but didn't depend on it. Removed the
  redundant files so they inherit the root options directly.
- **Workspace formatting** — `dart format` had never been run across the
  packages; formatted the whole workspace and added a `format-check` CI gate.

## Optional structural cleanups (no functional impact)

- **Two template apps.** `app_template` is the composed reference
  (auth + DI + routing) and is what `tool/create_app.dart` clones; `template_app`
  is a near-empty counter stub. Consider consolidating to one canonical template.
- **Conceptual duplication.** `core/analytics_logger` vs `services/analytics`
  (and the identical `revenue_cat_service.dart` in `monetization` vs
  `feature_paywall`) cover the same ground; consider a single home for each.
- **Mixed lint baselines.** `app_template` still declares `flutter_lints` in its
  dev-dependencies though the workspace standard is `very_good_analysis`.
