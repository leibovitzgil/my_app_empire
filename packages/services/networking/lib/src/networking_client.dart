import 'dart:async';

import 'package:core_utils/core_utils.dart';
import 'package:dio/dio.dart';
import 'package:networking/src/network_exception.dart';

/// Supplies the current auth token (if any) for outgoing requests.
typedef TokenProvider = FutureOr<String?> Function();

/// A thin [Dio] wrapper that injects an auth token, and returns typed
/// [Result]s with errors mapped to [NetworkException] instead of throwing.
class NetworkingClient {
  NetworkingClient({BaseOptions? options, TokenProvider? tokenProvider})
      : _dio = Dio(options ?? BaseOptions()) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenProvider?.call();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  final Dio _dio;

  /// The underlying Dio instance, for advanced configuration.
  Dio get dio => _dio;

  /// Performs a GET request.
  Future<Result<Response<T>>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) =>
      _send(() => _dio.get<T>(path, queryParameters: queryParameters));

  /// Performs a POST request.
  Future<Result<Response<T>>> post<T>(String path, {Object? data}) =>
      _send(() => _dio.post<T>(path, data: data));

  Future<Result<Response<T>>> _send<T>(
    Future<Response<T>> Function() request,
  ) async {
    try {
      return Success(await request());
    } on DioException catch (error, stackTrace) {
      return ResultFailure(NetworkException.fromDio(error), stackTrace);
    } on Object catch (error, stackTrace) {
      return ResultFailure(error, stackTrace);
    }
  }
}
