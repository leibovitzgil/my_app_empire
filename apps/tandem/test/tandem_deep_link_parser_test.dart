import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tandem/data/tandem_deep_link_parser.dart';

void main() {
  group('tandemDeepLinkParser', () {
    test('bare "/" resolves to /list with no parameters', () {
      final result = tandemDeepLinkParser(Uri.parse('https://tandem.app/'));

      expect(
        result,
        isA<Success<DeepLinkIntent>>().having(
          (s) => s.value,
          'value',
          const DeepLinkIntent(location: '/list'),
        ),
      );
    });

    test('"/list" resolves to /list with no parameters', () {
      final result = tandemDeepLinkParser(
        Uri.parse('https://tandem.app/list'),
      );

      expect(
        result,
        isA<Success<DeepLinkIntent>>().having(
          (s) => s.value,
          'value',
          const DeepLinkIntent(location: '/list'),
        ),
      );
    });

    test('"/join/<id>" resolves to /list with listId parameter', () {
      final result = tandemDeepLinkParser(
        Uri.parse('https://tandem.app/join/household'),
      );

      expect(
        result,
        isA<Success<DeepLinkIntent>>().having(
          (s) => s.value,
          'value',
          const DeepLinkIntent(
            location: '/list',
            parameters: {'listId': 'household'},
          ),
        ),
      );
    });

    test('an unrecognized path returns UnrecognizedLinkException', () {
      final uri = Uri.parse('https://tandem.app/unknown');

      final result = tandemDeepLinkParser(uri);

      expect(result, isA<ResultFailure<DeepLinkIntent>>());
      expect(
        (result as ResultFailure<DeepLinkIntent>).error,
        isA<UnrecognizedLinkException>(),
      );
    });
  });
}
