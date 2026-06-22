# Known Issues

Tracked technical debt in the workspace. The CI workflow runs `melos run lint`
and `melos run test`, so it will report these until they're resolved. Each is
independent and safe to tackle in its own PR.

## Fixed

- **Workspace could not bootstrap.** Two packages were named `notifications`
  (`core/` + `services/`) and two named `remote_config`, which Melos rejects.
  The "restructure packages" commit moved both to `services/` but left the
  `core/` copies behind. The orphaned `core/notifications` and
  `core/remote_config` duplicates were removed; nothing depended on them.

## Outstanding — packages failing `melos run lint`

### Source (compile) errors

- **`monetization` + `feature_paywall`** — `lib/src/revenue_cat_service.dart`
  (identical, duplicated file) declares `Future<CustomerInfo?> purchasePackage`
  but `Purchases.purchasePackage` returns `PurchaseResult` in the resolved
  `purchases_flutter` version. Either pin an older API or return
  `result.customerInfo`. The duplication across two packages should also be
  resolved (pick one home for the RevenueCat service).

### Missing generated code

- **`services/notifications`** — `test/notifications_manager_test.dart` imports
  `notifications_manager_test.mocks.dart` and references `Mock*` classes that
  were never generated. Run `dart run build_runner build` in that package (it
  depends on `mockito`/`build_runner`).

### Mechanical test/lint fixes

- **`analytics`, `analytics_logger`** — `inference_failure_on_function_invocation`
  on `mocktail`'s `any()`. Add type args, e.g. `any<SomeType>()`.
- **`review_prompter`** — `invalid_assignment`: `dynamic` assigned to
  `int`/`bool` in tests. Add casts or type the mocked returns.
- **`template_app`** — unused `package:flutter/material.dart` import in
  `test/widget_test.dart`, plus related issues.
- **`core_ui`** — 2 analyzer issues.

## Structural debt (no functional impact yet)

- **Two template apps.** `app_template` is the composed reference
  (auth + DI + routing) and is what `tool/create_app.dart` clones; `template_app`
  is a near-empty stub on `very_good_analysis`. Consolidate to one canonical
  template.
- **Conceptual duplication.** `core/analytics_logger` vs `services/analytics`
  cover similar ground; decide on one.
- **Mixed lint baselines.** `app_template` still uses `flutter_lints`; the rest
  of the workspace uses `very_good_analysis`.
