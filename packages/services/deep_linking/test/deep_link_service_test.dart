import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:flutter_test/flutter_test.dart';

Result<DeepLinkIntent> _stubParser(Uri uri) {
  if (uri.path == '/home') {
    return const Success(DeepLinkIntent(location: '/home'));
  }
  return ResultFailure<DeepLinkIntent>(UnrecognizedLinkException(uri));
}

void main() {
  // Listening to `onLink`/`onIntent` lazily subscribes to
  // `AppLinks().uriLinkStream`, which resolves the platform binary
  // messenger. A plain `test()` has no binding by default; initialize one
  // so that subscription (exercised by the `ingest`/`onIntent` group below)
  // doesn't throw, without needing a real platform channel or a fake
  // `AppLinks`.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppLinksDeepLinkService service;

  setUp(() {
    service = AppLinksDeepLinkService(parser: _stubParser);
  });

  tearDown(() => service.dispose());

  group('parse', () {
    test('returns Success for a URI the parser accepts', () {
      final result = service.parse(Uri.parse('https://example.com/home'));

      expect(result, isA<Success<DeepLinkIntent>>());
      expect(
        (result as Success<DeepLinkIntent>).value,
        const DeepLinkIntent(location: '/home'),
      );
    });

    test('returns ResultFailure<UnrecognizedLinkException> for a URI the '
        'parser rejects', () {
      final uri = Uri.parse('https://example.com/unknown');
      final result = service.parse(uri);

      expect(result, isA<ResultFailure<DeepLinkIntent>>());
      expect(
        (result as ResultFailure<DeepLinkIntent>).error,
        isA<UnrecognizedLinkException>(),
      );
    });
  });

  group('parseRaw', () {
    test('returns ResultFailure<InvalidLinkException> for an unparseable '
        'string', () {
      const raw = 'http://[invalid';
      expect(Uri.tryParse(raw), isNull);

      final result = service.parseRaw(raw);

      expect(result, isA<ResultFailure<DeepLinkIntent>>());
      expect(
        (result as ResultFailure<DeepLinkIntent>).error,
        isA<InvalidLinkException>(),
      );
    });

    test('delegates to parse for a parseable string', () {
      final result = service.parseRaw('https://example.com/home');

      expect(result, isA<Success<DeepLinkIntent>>());
    });
  });

  group('ingest / onIntent', () {
    test('emits a matching Result on onIntent', () async {
      final expectation = expectLater(
        service.onIntent,
        emits(
          isA<Success<DeepLinkIntent>>().having(
            (s) => s.value,
            'value',
            const DeepLinkIntent(location: '/home'),
          ),
        ),
      );

      service.ingest(Uri.parse('https://example.com/home'));

      await expectation;
    });
  });

  group('DeepLinkIntent equality', () {
    test('equal location and parameters are ==', () {
      const a = DeepLinkIntent(
        location: '/home',
        parameters: {'id': '1'},
      );
      const b = DeepLinkIntent(
        location: '/home',
        parameters: {'id': '1'},
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different location or parameters are not ==', () {
      const a = DeepLinkIntent(location: '/home');
      const b = DeepLinkIntent(location: '/paywall');
      const c = DeepLinkIntent(
        location: '/home',
        parameters: {'id': '1'},
      );

      expect(a == b, isFalse);
      expect(a == c, isFalse);
    });
  });
}
