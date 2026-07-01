// Exercises `AppLinksDeepLinkService` against a *fake app_links platform*
// (rather than only the hand-written `FakeDeepLinkService` in app_template),
// so the cold-start latch, lazy subscription, and warm-start/`ingest`
// pipeline-sharing behavior are proven against the real production class,
// not just re-implemented fake logic.
//
// This file is deliberately kept separate from `deep_link_service_test.dart`.
// `package:app_links`'s `AppLinks` is a process-wide singleton (private
// constructor, `factory AppLinks() => _instance`) that memoizes its own
// `uriLinkStream` controller the first time anything listens — and never
// resets that memoization on its own. Any earlier test in the *same process*
// that listens to an `AppLinksDeepLinkService`'s `onLink`/`onIntent` (even
// indirectly, e.g. via `ingest`'s `expectLater(service.onIntent, ...)`)
// permanently latches `AppLinks` onto whatever `AppLinksPlatform.instance`
// was active at that moment, and this file's `AppLinksPlatform.instance`
// swap would then have no effect. `flutter test` runs each test file in its
// own process, so isolating these tests in their own file avoids that
// cross-test/cross-group pollution without relying on execution order.
import 'dart:async';

import 'package:app_links_platform_interface/app_links_platform_interface.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:flutter_test/flutter_test.dart';

Result<DeepLinkIntent> _stubParser(Uri uri) {
  if (uri.path == '/home') {
    return const Success(DeepLinkIntent(location: '/home'));
  }
  return ResultFailure<DeepLinkIntent>(UnrecognizedLinkException(uri));
}

/// A test double for the plugin's platform interface, so `AppLinks` can be
/// driven without a real platform channel. `AppLinksPlatform.instance` is a
/// public seam the plugin itself exposes for platform implementations (and,
/// incidentally, for tests) to register against.
class _FakeAppLinksPlatform extends AppLinksPlatform {
  Uri? initialLink;
  int uriLinkStreamAccessCount = 0;
  final _uriController = StreamController<Uri>.broadcast();

  @override
  Future<Uri?> getInitialLink() async => initialLink;

  @override
  Stream<Uri> get uriLinkStream {
    uriLinkStreamAccessCount++;
    return _uriController.stream;
  }

  void emit(Uri uri) => _uriController.add(uri);

  Future<void> close() => _uriController.close();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A single fake platform for the whole file (installed once, before any
  // test runs) so `AppLinks`'s internal memoization only ever latches onto
  // this fake — see the file-level doc comment above.
  late _FakeAppLinksPlatform fakePlatform;

  setUpAll(() {
    fakePlatform = _FakeAppLinksPlatform();
    AppLinksPlatform.instance = fakePlatform;
  });

  tearDownAll(() => fakePlatform.close());

  test(
    'constructing the service does not touch the platform uriLinkStream',
    () {
      expect(fakePlatform.uriLinkStreamAccessCount, 0);

      final realService = AppLinksDeepLinkService(parser: _stubParser);
      addTearDown(realService.dispose);

      expect(fakePlatform.uriLinkStreamAccessCount, 0);
    },
  );

  test(
    'first listen on onLink/onIntent subscribes to the platform stream '
    'exactly once',
    () async {
      final realService = AppLinksDeepLinkService(parser: _stubParser);
      addTearDown(realService.dispose);

      final countBefore = fakePlatform.uriLinkStreamAccessCount;
      final sub1 = realService.onLink.listen((_) {});
      final sub2 = realService.onIntent.listen((_) {});

      // Both onLink and onIntent are views over the same broadcast
      // controller, so listening to both must still touch the platform
      // stream only once.
      expect(fakePlatform.uriLinkStreamAccessCount, countBefore + 1);

      await sub1.cancel();
      await sub2.cancel();
    },
  );

  test('getInitialLink returns the seeded link once, then null on every '
      'subsequent call', () async {
    fakePlatform.initialLink = Uri.parse('https://example.com/home');
    final realService = AppLinksDeepLinkService(parser: _stubParser);
    addTearDown(realService.dispose);

    final first = await realService.getInitialLink();
    final second = await realService.getInitialLink();
    final third = await realService.getInitialLink();

    expect(first, Uri.parse('https://example.com/home'));
    expect(second, isNull);
    expect(third, isNull);
  });

  test(
    'getInitialIntent parses the seeded link once, then returns null',
    () async {
      fakePlatform.initialLink = Uri.parse('https://example.com/home');
      final realService = AppLinksDeepLinkService(parser: _stubParser);
      addTearDown(realService.dispose);

      final first = await realService.getInitialIntent();
      final second = await realService.getInitialIntent();

      expect(first, isA<Success<DeepLinkIntent>>());
      expect(
        (first! as Success<DeepLinkIntent>).value,
        const DeepLinkIntent(location: '/home'),
      );
      expect(second, isNull);
    },
  );

  test(
    'getInitialIntent returns null when there was no initial link',
    () async {
      fakePlatform.initialLink = null;
      final realService = AppLinksDeepLinkService(parser: _stubParser);
      addTearDown(realService.dispose);

      expect(await realService.getInitialIntent(), isNull);
    },
  );

  test('warm-start: a link delivered on the platform stream while '
      'listening reaches onIntent', () async {
    final realService = AppLinksDeepLinkService(parser: _stubParser);
    addTearDown(realService.dispose);

    final expectation = expectLater(
      realService.onIntent,
      emits(
        isA<Success<DeepLinkIntent>>().having(
          (s) => s.value,
          'value',
          const DeepLinkIntent(location: '/home'),
        ),
      ),
    );

    fakePlatform.emit(Uri.parse('https://example.com/home'));

    await expectation;
  });

  test('push-notification-sourced ingest() and platform-sourced links '
      'interleave on the same onIntent pipeline', () async {
    final realService = AppLinksDeepLinkService(parser: _stubParser);
    addTearDown(realService.dispose);

    final received = <String>[];
    final subscription = realService.onIntent.listen((result) {
      if (result case Success<DeepLinkIntent>(:final value)) {
        received.add(value.location);
      }
    });

    // Simulates a push-notification payload feeding the same pipeline as a
    // native app_links URI.
    realService.ingest(Uri.parse('https://example.com/home'));
    await pumpEventQueue();
    fakePlatform.emit(Uri.parse('https://example.com/home'));
    await pumpEventQueue();

    expect(received, ['/home', '/home']);
    await subscription.cancel();
  });
}
