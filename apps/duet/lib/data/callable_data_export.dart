// cloud_functions exports its own (unrelated) `Result`; ours is core_utils'.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:core_utils/core_utils.dart';
import 'package:duet/data/data_export.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// A [DataExport] backed by the `exportMyData` callable (task M7.5).
///
/// Calls the region-pinned callable, then hands the returned 24 h signed URL
/// to the platform share-sheet so the user can open, copy, or send their
/// export bundle. `share_plus` lives here — behind the seam — so the headless
/// Settings flow test drives the UI through `MockDataExport`/a fake without
/// ever touching a platform channel (G2); the injected `shareInvoker` seam
/// (defaulting to `SharePlus.instance.share`, the `review_sync` precedent)
/// keeps even this class unit-testable.
class CallableDataExport implements DataExport {
  /// Creates a [CallableDataExport] over [functions] — pass the region-pinned
  /// instance (`FirebaseFunctions.instanceFor(region: duetFunctionsRegion)`).
  CallableDataExport({
    required FirebaseFunctions functions,
    Future<ShareResult> Function(ShareParams params)? shareInvoker,
  }) : _functions = functions,
       _shareInvoker = shareInvoker ?? SharePlus.instance.share;

  final FirebaseFunctions _functions;
  final Future<ShareResult> Function(ShareParams params) _shareInvoker;

  @override
  Future<Result<void>> exportMyData() async {
    try {
      final response = await _functions
          .httpsCallable('exportMyData')
          .call<Object?>();
      final data = response.data;
      final url = (data is Map && data['downloadUrl'] is String)
          ? data['downloadUrl'] as String
          : null;
      if (url == null) {
        // The export ran but produced no link — Storage isn't wired for the
        // project yet (the ▸B staging tail). Surface it as a plain failure
        // rather than pretending to share nothing.
        return const ResultFailure<void>(
          DataExportFailure(DataExportFailureKind.unknown),
        );
      }
      await _shareInvoker(
        ShareParams(uri: Uri.parse(url), subject: 'Your Duet data export'),
      );
      return const Success(null);
    } on Exception catch (e) {
      return ResultFailure<void>(mapExportError(e));
    }
  }
}

/// Maps an `exportMyData` callable [error] onto the [DataExportFailure]
/// taxonomy. `resource-exhausted` is the once-a-day limiter tripping;
/// `unavailable`/`deadline-exceeded` are transient connectivity.
@visibleForTesting
DataExportFailure mapExportError(Object error) {
  if (error is! FirebaseFunctionsException) {
    return DataExportFailure(DataExportFailureKind.unknown, error);
  }
  return switch (error.code) {
    'resource-exhausted' => const DataExportFailure(
      DataExportFailureKind.rateLimited,
    ),
    'unavailable' || 'deadline-exceeded' => const DataExportFailure(
      DataExportFailureKind.network,
    ),
    _ => DataExportFailure(DataExportFailureKind.unknown, error),
  };
}
