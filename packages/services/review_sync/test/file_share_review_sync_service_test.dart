import 'package:flutter_test/flutter_test.dart';
import 'package:pieces/pieces.dart';
import 'package:review_sync/review_sync.dart';

void main() {
  test('FileShareReviewSyncService implements ReviewSyncService', () {
    expect(FileShareReviewSyncService(), isA<ReviewSyncService>());
  });
}
