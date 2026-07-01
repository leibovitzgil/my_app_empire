import 'package:app_template/data/fake_deep_link_service.dart';
import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FakeDeepLinkService service;

  setUp(() => service = FakeDeepLinkService());

  tearDown(() => service.dispose());

  group('getInitialLink', () {
    test('returns the seeded link once, then null', () async {
      service.initialLink = Uri.parse('https://example.com/home');

      final first = await service.getInitialLink();
      final second = await service.getInitialLink();

      expect(first, Uri.parse('https://example.com/home'));
      expect(second, isNull);
    });
  });

  group('ingest / onIntent', () {
    test('emits a matching intent for a recognized URI', () async {
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

  group('parse', () {
    test('returns UnrecognizedLinkException for an unmatched URI', () {
      final result = service.parse(Uri.parse('https://example.com/unknown'));

      expect(result, isA<ResultFailure<DeepLinkIntent>>());
      expect(
        (result as ResultFailure<DeepLinkIntent>).error,
        isA<UnrecognizedLinkException>(),
      );
    });
  });
}
