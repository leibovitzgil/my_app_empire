import 'package:core_utils/core_utils.dart';
import 'package:deep_linking/deep_linking.dart';
import 'package:duet/features/pairing/pairing.dart';
import 'package:duet/routing/app_deep_link_parser.dart';
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

    // M5.5: the piece links carried by push notifications
    // (`https://duet.app/piece/<id>`, the shape `onInboxMessageCreated`
    // emits as `data.deepLink`) route onto the existing `/score/:pieceId`
    // destination.
    group('piece links', () {
      test('maps /piece/<id> onto the /score/:pieceId route', () {
        final result = duetDeepLinkParser(
          Uri.parse('https://duet.app/piece/some-piece-id'),
        );

        expect(
          result,
          isA<Success<DeepLinkIntent>>().having(
            (s) => s.value,
            'value',
            const DeepLinkIntent(location: '/score/some-piece-id'),
          ),
        );
      });

      test('re-encodes an id that needs escaping in the location', () {
        final result = duetDeepLinkParser(
          Uri.parse('https://duet.app/piece/a%2Fb'),
        );

        expect(
          result,
          isA<Success<DeepLinkIntent>>().having(
            (s) => s.value,
            'value',
            const DeepLinkIntent(location: '/score/a%2Fb'),
          ),
        );
      });

      test('rejects /piece/ with no id', () {
        final result = duetDeepLinkParser(
          Uri.parse('https://duet.app/piece/'),
        );

        expect(result, isA<ResultFailure<DeepLinkIntent>>());
        expect(
          (result as ResultFailure<DeepLinkIntent>).error,
          isA<UnrecognizedLinkException>(),
        );
      });

      test('rejects a piece link with trailing garbage segments', () {
        final result = duetDeepLinkParser(
          Uri.parse('https://duet.app/piece/p1/extra'),
        );

        expect(result, isA<ResultFailure<DeepLinkIntent>>());
        expect(
          (result as ResultFailure<DeepLinkIntent>).error,
          isA<UnrecognizedLinkException>(),
        );
      });
    });

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
