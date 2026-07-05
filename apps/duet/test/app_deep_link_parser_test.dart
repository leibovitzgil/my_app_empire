import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/routing/app_deep_link_parser.dart';
import 'package:feature_pairing/feature_pairing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('duetDeepLinkParser', () {
    test('matches the root path', () {
      final result = duetDeepLinkParser(Uri.parse('https://example.com/'));

      expect(
        result,
        isA<Success<DeepLinkIntent>>().having(
          (s) => s.value,
          'value',
          const DeepLinkIntent(location: '/'),
        ),
      );
    });

    test('matches /home', () {
      final result = duetDeepLinkParser(Uri.parse('https://example.com/home'));

      expect(
        result,
        isA<Success<DeepLinkIntent>>().having(
          (s) => s.value,
          'value',
          const DeepLinkIntent(location: '/home'),
        ),
      );
    });

    test(
      'recognizes an invite link and routes to the Accept-Invite screen '
      'with the token embedded in the location',
      () {
        final uri = InviteDeepLinks.buildUri('abc123');

        final result = duetDeepLinkParser(uri);

        expect(
          result,
          isA<Success<DeepLinkIntent>>().having(
            (s) => s.value,
            'value',
            const DeepLinkIntent(location: '/invite/accept/abc123'),
          ),
        );
      },
    );

    test('fails for an unrecognized link', () {
      final result = duetDeepLinkParser(Uri.parse('https://example.com/nope'));

      expect(result, isA<ResultFailure<DeepLinkIntent>>());
      expect(
        (result as ResultFailure<DeepLinkIntent>).error,
        isA<UnrecognizedLinkException>(),
      );
    });
  });
}
