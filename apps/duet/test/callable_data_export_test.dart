// Unit-covers `CallableDataExport`'s error mapping — the boundary that folds
// `FirebaseFunctionsException` codes onto the `DataExportFailure` taxonomy so
// the Settings "Download my data" flow can pattern-match them (mirrors
// `callable_account_purge_test.dart`). The seam-called sequence itself is
// covered against a fake in `duet_settings_page_test.dart`; this pins the
// code translation.
import 'package:cloud_functions/cloud_functions.dart' hide Result;
import 'package:duet/data/callable_data_export.dart';
import 'package:duet/data/data_export.dart';
import 'package:flutter_test/flutter_test.dart';

FirebaseFunctionsException _exception(String code) =>
    FirebaseFunctionsException(message: code, code: code);

void main() {
  group('mapExportError', () {
    const cases = <(String, DataExportFailureKind)>[
      ('resource-exhausted', DataExportFailureKind.rateLimited),
      ('unavailable', DataExportFailureKind.network),
      ('deadline-exceeded', DataExportFailureKind.network),
      ('unauthenticated', DataExportFailureKind.unknown),
      ('internal', DataExportFailureKind.unknown),
      ('not-found', DataExportFailureKind.unknown),
    ];

    for (final (code, expected) in cases) {
      test('$code -> ${expected.name}', () {
        final failure = mapExportError(_exception(code));
        expect(failure.kind, expected);
      });
    }

    test('a non-Functions error maps to unknown, keeping the raw error', () {
      final raw = StateError('boom');
      final failure = mapExportError(raw);
      expect(failure.kind, DataExportFailureKind.unknown);
      expect(failure.cause, same(raw));
    });
  });
}
