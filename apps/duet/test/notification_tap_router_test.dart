// Unit cover for the tap → deep-link glue (M5.5): a local-notification tap
// payload is ingested into `DeepLinkService`, whose parser turns a piece
// link into a `/score/<id>` intent — the same `onIntent` machinery
// `AppView` subscribes to (covered end-to-end in
// `app_deep_link_redirect_test.dart`).
import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/data/fake_deep_link_service.dart';
import 'package:duet/injection.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<String> taps;
  late FakeDeepLinkService deepLinks;
  late NotificationTapRouter router;
  late List<Result<DeepLinkIntent>> intents;
  late StreamSubscription<Result<DeepLinkIntent>> subscription;

  setUp(() {
    taps = StreamController<String>();
    deepLinks = FakeDeepLinkService();
    router = NotificationTapRouter(taps: taps.stream, deepLinks: deepLinks);
    intents = <Result<DeepLinkIntent>>[];
    subscription = deepLinks.onIntent.listen(intents.add);
  });

  tearDown(() async {
    await subscription.cancel();
    await router.dispose();
    await taps.close();
    await deepLinks.dispose();
  });

  test('a piece-link payload is ingested and parses to its score', () async {
    taps.add('https://duet.app/piece/some-piece-id');
    await pumpEventQueue();

    expect(
      intents.single,
      isA<Success<DeepLinkIntent>>().having(
        (s) => s.value,
        'value',
        const DeepLinkIntent(location: '/score/some-piece-id'),
      ),
    );
  });

  test('an unparseable payload is dropped, not ingested', () async {
    // `Uri.tryParse` returns null for an unterminated IPv6 host.
    taps.add('http://[');
    await pumpEventQueue();

    expect(intents, isEmpty);
  });

  test('an unrecognized-but-valid URI still rides the intent stream '
      'as a failure (the parser decides, not the router)', () async {
    taps.add('https://example.com/unknown');
    await pumpEventQueue();

    expect(intents.single, isA<ResultFailure<DeepLinkIntent>>());
  });
}
