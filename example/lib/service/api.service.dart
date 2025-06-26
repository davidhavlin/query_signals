import 'package:dio/dio.dart';
import 'package:example/config/app.config.dart';

typedef Params = Map<String, dynamic>;

class ApiException extends DioException implements Exception {
  @override
  final String message;
  final List<dynamic>? errors;
  final String? code;

  ApiException({
    required super.requestOptions,
    required this.message,
    required super.stackTrace,
    super.response,
    super.type = DioExceptionType.unknown,
    this.errors,
    this.code,
    super.error,
  }) : super(message: message);
}

class ApiService {
  final version = 'v1';
  final client = Dio();

  ApiService() {
    client.options.baseUrl = '${AppConfig.baseUrl}/';
    client.options.connectTimeout = const Duration(seconds: 5);
    client.options.receiveTimeout = const Duration(seconds: 10);

    client.interceptors.addAll([
      InterceptorsWrapper(
        onRequest: (options, handler) {
          print(
            '${options.method} request: ${options.uri.path}${options.uri.query.isNotEmpty ? ' q: ${options.uri.query}' : ''}',
          );

          return handler.next(options);
        },
        onError: (error, handler) {
          print(
            '${error.requestOptions.method} request failed: ${error.requestOptions.uri}, ${error.response?.statusCode}',
          );

          final data = error.response?.data?['error'] as Map<String, dynamic>?;
          final validation = error.response?.data?['errors'];

          String message = 'An error occurred';
          String? code;

          if (data != null) {
            message = data['message'] ?? message;
            code = data['code'];
          }

          if (validation != null && validation is List) {
            message = validation.map((e) => e['message']).join('\n');
          }

          return handler.next(
            ApiException(
              requestOptions: error.requestOptions,
              message: message,
              stackTrace: error.stackTrace,
              response: error.response,
              type: error.type,
              error: error.error,
              code: code,
              errors: validation,
            ),
          );
        },
      ),
    ]);
  }

  Future<Response<T>> get<T>(
    String path, {
    Params? params,
    Options? options,
  }) async {
    return await client.get<T>(path, queryParameters: params, options: options);
  }

  Future<T> $get<T>(String path, {Params? params, Options? options}) async {
    final response = await get<T>(path, params: params, options: options);
    return response.data!;
  }

  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Params? params,
    Options? options,
  }) async {
    return await client.post<T>(
      path,
      queryParameters: params,
      data: data,
      options: options,
    );
  }

  Future<T> $post<T>(
    String path, {
    Object? data,
    Params? params,
    Options? options,
  }) async {
    final response = await post<T>(
      path,
      params: params,
      data: data,
      options: options,
    );

    return response.data!;
  }

  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Params? params,
    Options? options,
  }) async {
    return await client.patch<T>(
      path,
      queryParameters: params,
      data: data,
      options: options,
    );
  }

  Future<T> $patch<T>(
    String path, {
    Object? data,
    Params? params,
    Options? options,
  }) async {
    final response = await patch<T>(
      path,
      params: params,
      data: data,
      options: options,
    );

    return response.data!;
  }

  Future<Response<T>> delete<T>(
    String path, {
    Params? params,
    Options? options,
  }) async {
    return await client.delete<T>(
      path,
      queryParameters: params,
      options: options,
    );
  }

  Future<T> $delete<T>(String path, {Params? params, Options? options}) async {
    final response = await delete<T>(path, params: params, options: options);

    return response.data!;
  }
}

final api = ApiService();
