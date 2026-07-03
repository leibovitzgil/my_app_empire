# `core_ui` v1 Widget Library Plan

Expanding `packages/core/core_ui` from 9 ad-hoc widgets into a deliberate,
general-purpose widget + design-token library, so new apps and features can be
assembled from `core_ui` primitives instead of hand-rolling UI per feature.

Produced by a `product-manager` → `ux-designer` → `architect` pipeline. This
doc is the spec/brief/plan handoff for a `flutter-builder` agent to implement,
PR by PR, per the sequencing in §4.

## Current state (why this is needed)

`core_ui` today has `AppTheme` (Material 3, Google Fonts Roboto,
`ColorScheme.fromSeed(Colors.blue)`, no spacing/radius tokens) and 9 widgets:
`AppLogoMark`, `BrandLogos`, `EmptyStateView`, `ErrorRetryView`,
`InitialsAvatar`, `LabeledDivider`, `PrimaryButton`, `SignInView`,
`SocialSignInButton`. Every feature hand-rolls text fields, snackbars, confirm
dialogs, bottom sheets, cards, and list tiles — inconsistently (corner radius
8 in `PrimaryButton`, 12 in `share_sheet.dart`'s field, 4 in an item row).

## 1. Scope

### Tokens (foundation)
- `AppSpacing`: xs=4, sm=8, md=16, lg=24, xl=32.
- `AppRadii`: sm=8 (buttons/snackbar), md=12 (inputs/dialog), card=16
  (cards/bottom sheet).
- Wired into `ThemeData` sub-themes (`inputDecorationTheme`,
  filled/outlined/text button themes, `cardTheme`, `snackBarTheme`,
  `dialogTheme`, `bottomSheetTheme`) via one shared private builder so
  light/dark themes don't duplicate sub-theme code.

### v1 must-have widgets
- **Inputs:** `AppTextField`, `AppPasswordField` (obscure toggle),
  `AppSearchField` (conditional clear button).
- **Buttons:** keep `PrimaryButton`; add `SecondaryButton` (outlined),
  `AppTextButton`; add an `isDestructive` flag (color-role swap, not new
  classes) to all three.
- **Feedback:** `AppSnackbar` (success/error/info static helper, single-call,
  clears-then-shows to avoid stacking) and `confirmDialog({title, message,
  confirmLabel, isDestructive}) -> Future<bool>`.
- **State set:** `LoadingView`, `SkeletonBox`/`SkeletonList`; lightly
  token-align `EmptyStateView` + `ErrorRetryView` so all four read as one
  family (no redesign).
- **List/card:** `AppCard`, `AppListTile` / `PersonTile` (wraps
  `InitialsAvatar`).
- **Overlays:** `AppBottomSheet.show(...)` (title, drag handle, scroll +
  keyboard-inset-aware padding, real close button for a11y).

### Tier 2 — deferred
`StatusPill`, `CountBadge`, and `AppScaffold` were considered and **deferred**
for v1. Architect's audit of `feature_auth`/`feature_onboarding`/
`feature_paywall`/settings screens found only 3 screens with a trivial
one-line `AppBar(title: Text(...))` — not enough duplication to justify a
shared scaffold, and it risks becoming a leaky navigation-shell abstraction
(an explicit non-goal). No pill/badge duplication found either. Revisit
pull-driven when a real feature needs one.

### Non-goals
No animation framework (reuse existing `flutter_animate` sparingly, no new
dependency), no white-label/multi-brand theming, no navigation shell, no
data-table/calendar/charting widgets.

## 2. Design decisions

**Success color mapping** (no semantic green exists under
`ColorScheme.fromSeed(Colors.blue)`): map snackbar variants to container
roles — `error` → `errorContainer`, `success` → `tertiaryContainer`, `info` →
`secondaryContainer` — centralized in one private `_colorsFor()` function so a
future branded palette only changes one place.

**Skeleton animation**: reuse `flutter_animate` (already a dependency) for a
subtle repeating shimmer, default `shimmer: true`, but expose `shimmer: false`
for deterministic golden captures (a repeating animation never settles).

**Destructive actions**: `isDestructive` flag on buttons swaps to
`colorScheme.error` roles; convention (documented in dartdoc) is to always
pair a destructive button with `confirmDialog(isDestructive: true)`, which
focuses Cancel by default to avoid accidental confirmation.

**Accessibility baseline** (from the UX brief, applies across all widgets):
48dp minimum tap targets (enforced via theme `minimumSize`, not per-widget
padding), `Semantics` labels on icon-only actions (password toggle, search
clear, bottom-sheet close), `excludeSemantics` on decorative avatars inside
`PersonTile` to avoid double-announcement, and real focusable close controls
for overlays since drag-to-dismiss isn't screen-reader operable.

**Golden test / theme tension**: existing goldens deliberately use bare
`ThemeData(useMaterial3: true)` instead of `AppTheme` because `AppTheme` pulls
`GoogleFonts.robotoTextTheme()` (network fetch) — but the whole point of the
token system is the sub-themes living inside `AppTheme`. Resolved by adding
`AppTheme.testTheme({brightness})`, a `@visibleForTesting` seam that builds
the same sub-themes with the bundled font instead of Google Fonts. All new
goldens use `testTheme()`, not `lightTheme`/`darkTheme` directly.

## 3. API sketch (signatures only — see architect transcript for full detail)

```dart
abstract final class AppSpacing {
  static const double xs = 4, sm = 8, md = 16, lg = 24, xl = 32;
}

abstract final class AppRadii {
  static const double sm = 8, md = 12, card = 16;
}

class AppTextField extends StatelessWidget { const AppTextField({
  controller, label, hint, errorText, keyboardType, textInputAction,
  onChanged, onSubmitted, enabled, readOnly, prefixIcon, suffixIcon,
  obscureText, ... }); }

class AppPasswordField extends StatefulWidget { const AppPasswordField({
  controller, label, onChanged, onSubmitted, ... }); }

class AppSearchField extends StatelessWidget { const AppSearchField({
  required controller, hint, onChanged, onClear, isLoading, ... }); }

class SecondaryButton extends StatelessWidget { const SecondaryButton({
  required onPressed, required label, isLoading, isDestructive }); }
class AppTextButton extends StatelessWidget { const AppTextButton({
  required onPressed, required label, isLoading, isDestructive }); }

enum AppSnackbarVariant { success, error, info }
abstract final class AppSnackbar {
  static void show(BuildContext context, {required message, variant,
    actionLabel, onAction, duration});
  static void success(...); static void error(...); static void info(...);
}

Future<bool> confirmDialog(BuildContext context, {required title,
  required message, confirmLabel, cancelLabel, isDestructive});

class LoadingView extends StatelessWidget { const LoadingView({label}); }
class SkeletonBox extends StatelessWidget { const SkeletonBox({width,
  height, borderRadius, shimmer}); }
class SkeletonList extends StatelessWidget { const SkeletonList({itemCount,
  itemHeight, spacing, shimmer}); }

class AppCard extends StatelessWidget { const AppCard({required child,
  onTap, selected, enabled, padding}); }
class AppListTile extends StatelessWidget { const AppListTile({leading,
  title, subtitle, trailing, onTap, enabled}); }
class PersonTile extends StatelessWidget { const PersonTile({
  required initials, required color, required name, subtitle, trailing,
  onTap}); }

abstract final class AppBottomSheet {
  static Future<T?> show<T>(BuildContext context, {required builder,
    title, isScrollControlled, isDismissible});
}
```

## 4. Sequencing — independently-mergeable PRs

Each PR leaves `melos run lint && melos run test && melos run golden` green.

1. **Tokens + theme.** `AppSpacing`, `AppRadii`, rewrite `app_theme.dart`
   around a shared `_build()` with all sub-themes + `testTheme()` seam.
   Migrate existing goldens (`primary_button`, `brand_logos`) to
   `testTheme()`, rebaseline once.
2. **Buttons.** `SecondaryButton`, `AppTextButton`, `isDestructive` on all
   three; drop hardcoded height/radius from `PrimaryButton` /
   `SocialSignInButton` (theme supplies them, no visual change).
3. **Inputs.** `AppTextField`, `AppPasswordField`, `AppSearchField`.
4. **Feedback.** `AppSnackbar`, `confirmDialog`.
5. **State set.** `LoadingView`, `SkeletonBox`/`SkeletonList`; token-align
   `EmptyStateView` + `ErrorRetryView`.
6. **List/card.** `AppCard`, `AppListTile`, `PersonTile`.
7. **Overlay.** `AppBottomSheet`.
8. **Migrations (proof).** `SignInView` → `AppTextField`/`AppPasswordField`;
   `feature_grocery_list/share_sheet.dart`'s confirm dialog (lines ~212–234)
   and copy-link snackbar (lines ~66–74) → `confirmDialog`/`AppSnackbar`;
   optionally `feature_settings/settings_screen.dart` snackbars.
9. **Deferred backlog note.** `StatusPill`/`CountBadge`/`AppScaffold` — not
   built now (see §1 Tier 2); left here so it isn't silently forgotten.

Every PR from step 2 onward: add a `@Preview` per new widget (key states
only, no dark-mode duplication needed) and a golden per visually-distinct
state × {light, dark}, using `AppTheme.testTheme()`.

## 5. Acceptance criteria

- Tokens exported from `core_ui.dart`; no magic radius/spacing numbers in any
  widget `build()` method.
- Every v1 widget exported from the barrel, bloc-agnostic (no `flutter_bloc`
  or service-package imports) — confirmed zero DI/get_it impact.
- Every widget has a `@Preview` and a golden test (network-free via
  `testTheme()`, tagged `golden`).
- `AppSnackbar`/`confirmDialog` are single-call and independently testable.
- Full backward compatibility: all existing features/apps compile unchanged,
  `melos run test` stays green throughout.
- At least one real migration lands (step 8) proving primitives replace, not
  just supplement, hand-rolled code.
- `melos run lint` / `format-check` clean under `very_good_analysis`.
- Every widget verified in both `AppTheme.lightTheme` and `darkTheme` via
  golden coverage.

No new dependencies required — `flutter_animate`, `google_fonts`, and
`flutter_svg` already cover everything above.
