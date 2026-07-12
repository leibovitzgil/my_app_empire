import 'package:core_utils/core_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';

void main() {
  group('UploadProgress', () {
    test('fraction is bytes/total, clamped to 0..1', () {
      expect(
        const UploadProgress(bytesTransferred: 25, totalBytes: 100).fraction,
        0.25,
      );
      expect(
        const UploadProgress(bytesTransferred: 200, totalBytes: 100).fraction,
        1,
      );
    });

    test('fraction is 0 while the total is unknown', () {
      expect(
        const UploadProgress(bytesTransferred: 0, totalBytes: 0).fraction,
        0,
      );
    });

    test('a skipped upload reads as complete', () {
      const skipped = UploadProgress.skipped();
      expect(skipped.skipped, isTrue);
      expect(skipped.fraction, 1);
    });
  });

  group('NoopPieceBinaryStore', () {
    test('emits a single skipped upload event and completes', () async {
      const store = NoopPieceBinaryStore();
      final events = await store
          .uploadBasePdf(pieceId: 'p1', localPath: '/tmp/p1.pdf', checksum: 'c')
          .toList();

      expect(events, const [UploadProgress.skipped()]);
    });

    test('download fails — the local composition never downloads', () async {
      const store = NoopPieceBinaryStore();
      final result = await store.downloadBasePdf(
        pieceId: 'p1',
        destPath: '/tmp/p1.pdf',
      );
      expect(result, isA<ResultFailure<void>>());
    });
  });
}
