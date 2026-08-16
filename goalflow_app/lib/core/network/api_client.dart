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
            // Generous on purpose. A free-tier host (Render, Fly, Railway) spins
            // its container down when idle, and the first request afterwards
            // waits for a cold start -- measured at 17s and documented up to 60s.
            // Shorter timeouts here surface as "cannot reach the server" on the
            // very first launch of the day, which reads as a broken app.
            connectTimeout: const Duration(seconds: 75),
            receiveTimeout: const Duration(seconds: 75),
            sendTimeout: const Duration(seconds: 75),
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

  /// The deployed backend. Defaulting to production rather than localhost means
  /// a plain `flutter run`, and an APK handed to someone else, both just work --
  /// forgetting the --dart-define used to surface as "cannot reach the server".
  static const productionBaseUrl = 'https://fitness-lgaw.onrender.com/api/v1';

  /// Resolution order:
  ///   1. --dart-define=API_BASE_URL=...   (explicit, always wins)
  ///   2. --dart-define=USE_LOCAL_API=true (localhost, or 10.0.2.2 on an
  ///      Android emulator, which is how the emulator reaches the host machine)
  ///   3. the deployed backend
  ///
  /// Uses `defaultTargetPlatform` rather than `dart:io`'s `Platform`, because
  /// importing dart:io at all breaks the web build.
  static String get defaultBaseUrl {
    const fromEnv = String.fromEnvironment('API_BASE_URL');
    if (fromEnv.isNotEmpty) return fromEnv;

    const useLocal = bool.fromEnvironment('USE_LOCAL_API');
    if (useLocal) {
      final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? '10.0.2.2'
          : 'localhost';
      return 'http://$host:4000/api/v1';
    }

    return productionBaseUrl;
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
      // A timeout and a refused connection mean different things to the user:
      // one is "wait a moment", the other is "check your wifi".
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        throw ApiException(
          'The server is taking longer than usual to respond. '
          'It may be waking up - try again in a moment.',
        );
      }
      if (e.type == DioExceptionType.connectionError) {
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
