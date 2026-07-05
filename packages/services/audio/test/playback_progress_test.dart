import 'package:audio/audio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlaybackProgress supports value equality', () {
    const progress = PlaybackProgress(
      position: Duration(seconds: 1),
      duration: Duration(seconds: 10),
    );

    expect(
      progress,
      const PlaybackProgress(
        position: Duration(seconds: 1),
        duration: Duration(seconds: 10),
      ),
    );
  });
}
