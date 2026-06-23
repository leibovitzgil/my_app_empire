import 'dart:typed_data';

import 'package:core_utils/core_utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:networking/networking.dart';

/// A Dio adapter that returns a canned status code without hitting the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.statusCode);

  final int statusCode;

  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      '{}',
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }
}

NetworkingClient _client(int statusCode) {
  return NetworkingClient(
    options: BaseOptions(baseUrl: 'https://example.com'),
  )..dio.httpClientAdapter = _FakeAdapter(statusCode);
}

void main() {
  group('NetworkingClient', () {
    test('returns Success on a 2xx response', () async {
      final result = await _client(200).get<dynamic>('/ok');
      expect(result, isA<Success<Response<dynamic>>>());
    });

    test('maps a 500 response to a NetworkException failure', () async {
      final result = await _client(500).get<dynamic>('/boom');
      switch (result) {
        case ResultFailure(:final error):
          expect(error, isA<NetworkException>());
          expect((error as NetworkException).statusCode, 500);
        case Success():
          fail('expected a failure');
      }
    });

    test('injects a bearer token when a provider is given', () async {
      final client = NetworkingClient(
        options: BaseOptions(baseUrl: 'https://example.com'),
        tokenProvider: () => 'abc123',
      )..dio.httpClientAdapter = _FakeAdapter(200);

      String? sentAuth;
      client.dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            sentAuth = options.headers['Authorization'] as String?;
            handler.next(options);
          },
        ),
      );

      await client.get<dynamic>('/ok');
      expect(sentAuth, 'Bearer abc123');
    });
  });
}
