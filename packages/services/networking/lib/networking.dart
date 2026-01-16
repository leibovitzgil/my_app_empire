library networking;

import 'package:dio/dio.dart';

/// A Dio client with global error handling.
class NetworkingClient {
  final Dio _dio;

  NetworkingClient({BaseOptions? options})
      : _dio = Dio(options ?? BaseOptions());

  Dio get dio => _dio;

  // TODO: Implement global error handling
}
