import 'package:core_utils/core_utils.dart';

/// Why a data export could not be produced — carried in a `ResultFailure` so
/// the Settings flow can render a specific message (the `AuthFailure` pattern,
/// applied to export).
enum DataExportFailureKind {
  /// The daily export budget (once per day per account) is already spent.
  rateLimited,

  /// A connectivity problem reaching the export backend.
  network,

  /// Anything else (an unexpected callable error, or no link produced).
  unknown,
}

/// A typed export failure with a user-facing [message].
class DataExportFailure {
  /// Creates a [DataExportFailure] of [kind], optionally wrapping [cause].
  const DataExportFailure(this.kind, [this.cause]);

  /// The category of failure.
  final DataExportFailureKind kind;

  /// The underlying error, when there is one.
  final Object? cause;

  /// The message shown to the user for this failure.
  String get message => switch (kind) {
    DataExportFailureKind.rateLimited =>
      'You can export your data once a day. Please try again tomorrow.',
    DataExportFailureKind.network =>
      'No connection. Check your network and try again.',
    DataExportFailureKind.unknown =>
      'Could not export your data. Please try again.',
  };
}

/// The self-service GDPR data-export seam (task M7.5).
///
/// Asks the backend to gather everything Duet holds about the caller into a
/// JSON bundle and delivers the resulting download link to the user (the
/// share-sheet). Server-authoritative — the rules scope a client to its own
/// docs one at a time, so a complete cross-collection export is a Cloud
/// Function (`functions/src/exportMyData.ts`), the same posture as
/// `AccountPurge` (M1.8/M1.9). The app picks the implementation at the DI
/// layer (`CallableDataExport` under `useFirebase: true`, [MockDataExport]
/// otherwise), which lets the headless Settings flow test drive the full UI
/// sequence without Cloud Functions (G2).
// ignore: one_member_abstracts
abstract class DataExport {
  /// Requests an export of the signed-in account's data and hands the
  /// resulting download link to the user.
  ///
  /// On `Success` the export was produced and delivered. Failures carry a
  /// [DataExportFailure] in the `ResultFailure`: `rateLimited` when the daily
  /// budget is spent, `network` for connectivity, `unknown` otherwise.
  Future<Result<void>> exportMyData();
}

/// The default (no-Firebase) [DataExport]: simulates success after a delay.
///
/// The mock identity's data lives only in the in-memory stores, which die
/// with the process — there is no persisted bundle to produce, so simulated
/// success is the honest behavior (mirrors `MockAccountPurge`).
class MockDataExport implements DataExport {
  @override
  Future<Result<void>> exportMyData() async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return const Success(null);
  }
}
