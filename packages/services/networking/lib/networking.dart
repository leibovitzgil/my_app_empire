import 'package:dio/dio.dart';

/// A Dio client with global error handling.
class NetworkingClient {
  NetworkingClient({BaseOptions? options})
      : _dio = Dio(options ?? BaseOptions());
  final Dio _dio;

  Dio get dio => _dio;

  // TODO(team): add a global error-handling interceptor.
}
