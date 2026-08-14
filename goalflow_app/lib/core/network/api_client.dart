import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../storage/token_storage.dart';
import 'api_exception.dart';

/// Single place that knows how to talk to the backend.
/// Repositories call [get]/[post]/... and receive the unwrapped `data` payload --
/// no screen ever sees the response envelope, a status code, or a Dio type.
class ApiClient {
  ApiClient({required TokenStorage storage, String? baseUrl})
      : _storage = storage,
        _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? defaultBaseUrl,
            connectTimeout: const Duration(seconds: 15),
            receiveTimeout: const Duration(seconds: 20),
            contentType: 'application/json',
            validateStatus: (s) => s != null && s < 500,
          ),
        ) {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.accessToken;
          if (token != null) options.headers['Authorization'] = 'Bearer $token';
          handler.next(options);
        },
        onError: (e, handler) => handler.next(e),
      ),
    );

    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: false));
    }
  }

  final Dio _dio;
  final TokenStorage _storage;

  /// Called when refreshing fails, so the app can drop to the login screen.
  VoidCallback? onSessionExpired;

  /// Android emulators reach the host machine on 10.0.2.2, iOS simulators and
  /// the web build on localhost. Override with --dart-define=API_BASE_URL=...
  /// for a real device or a deployed backend.
  ///
  /// Uses `defaultTargetPlatform` rather than `dart:io`'s `Platform`, because
  /// importing dart:io at all breaks the web build.
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/api/v1';
    }
    return 'http://localhost:4000/api/v1';
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _send(() => _dio.post(path, data: body));

  Future<dynamic> patch(String path, {Object? body}) =>
      _send(() => _dio.patch(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _send(() => _dio.delete(path, data: body));

  /// Takes bytes rather than a file path so the same code works on mobile and
  /// on web, where `dart:io` files do not exist.
  Future<dynamic> upload(
    String path,
    String field,
    Uint8List bytes,
    String filename,
  ) =>
      _send(
        () => _dio.post(
          path,
          data: FormData.fromMap({
            field: MultipartFile.fromBytes(bytes, filename: filename),
          }),
        ),
      );

  Future<dynamic> _send(Future<Response> Function() request, {bool retrying = false}) async {
    try {
      final res = await request();
      final body = res.data;

      if (res.statusCode == 401 && !retrying) {
        // One transparent refresh attempt, then give up and sign out.
        if (await _refreshSession()) return _send(request, retrying: true);
        onSessionExpired?.call();
        throw ApiException('Your session expired. Please sign in again.',
            statusCode: 401);
      }

      if (body is Map && body['success'] == true) return body['data'];

      throw _fromEnvelope(body, res.statusCode);
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw ApiException(
          'Cannot reach the server. Check your connection and try again.',
        );
      }
      throw _fromEnvelope(e.response?.data, e.response?.statusCode);
    }
  }

  ApiException _fromEnvelope(dynamic body, int? status) {
    if (body is Map && body['error'] is Map) {
      final error = body['error'] as Map;
      Map<String, String>? fields;
      if (error['details'] is List) {
        fields = {
          for (final d in error['details'] as List)
            if (d is Map && d['field'] != null)
              d['field'].toString(): d['message'].toString(),
        };
      }
      return ApiException(
        error['message']?.toString() ?? 'Something went wrong',
        code: error['code']?.toString(),
        statusCode: status,
        fieldErrors: fields,
      );
    }
    return ApiException('Something went wrong. Please try again.', statusCode: status);
  }

  Future<bool> _refreshSession() async {
    final refresh = await _storage.refreshToken;
    if (refresh == null) return false;
    try {
      final res = await Dio(BaseOptions(baseUrl: _dio.options.baseUrl))
          .post('/auth/refresh', data: {'refreshToken': refresh});
      final data = res.data['data'];
      await _storage.save(
        access: data['accessToken'] as String,
        refresh: data['refreshToken'] as String,
      );
      return true;
    } catch (_) {
      await _storage.clear();
      return false;
    }
  }
}
