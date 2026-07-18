/// App-wide legal constants: the hosted document URLs surfaced in Settings and
/// at sign-up, the consent document version stamped onto each acceptance
/// record, and the displayed app version.
///
/// The URLs are placeholders until the real policy/ToS are authored and hosted
/// (M7.4 ▸B / Track B, `hosting/` from M0.4). Nothing depends on them
/// resolving on the headless gate — `PrivacyPolicyButton`/`TermsOfServiceButton`
/// only launch them on a real tap.
library;

// TODO(track-b): replace with the real hosted privacy-policy URL once the
// document is authored and hosted (M7.4 ▸B [HUMAN]).
const String kPrivacyPolicyUrl = 'https://duet.app/legal/privacy';

// TODO(track-b): replace with the real hosted terms-of-service URL once the
// document is authored and hosted (M7.4 ▸B [HUMAN]).
const String kTermsOfServiceUrl = 'https://duet.app/legal/terms';

/// The version of the legal documents a user accepts at sign-up. Bump this
/// whenever the policy/ToS change materially, so stale consent can be detected
/// and re-prompted. Stored on each `ConsentRecord`.
const String kLegalDocumentVersion = '2026-07-17';

// TODO(track-b): source this from `package_info_plus` (not yet a dependency)
// once release builds set a real version; kept in sync with `pubspec.yaml`'s
// `version:` for now.
/// The app version shown in Settings ▸ About.
const String kAppVersion = '1.0.0';
