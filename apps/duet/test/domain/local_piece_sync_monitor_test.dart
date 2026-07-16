import 'package:duet/domain/domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LocalPieceSyncMonitor always reports a piece as synced', () async {
    const monitor = LocalPieceSyncMonitor();

    expect(await monitor.watch('any-piece').first, PieceSyncState.synced);
  });
}
