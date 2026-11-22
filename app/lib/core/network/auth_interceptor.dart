import 'dart:async';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';
import '../security/secure_token_storage.dart';

typedef TokenRefresher = Future<({String accessToken, String refreshToken})> Function(
  String refreshToken,
);

/// QueuedInterceptor dengan Single-Flight Refresh Lock (LLD Bagian 5.2).
/// Jika beberapa request paralel menerima HTTP 401 bersamaan, hanya 1 kali
/// /api/v1/auth/refresh dieksekusi agar tidak memicu false-positive AUTH_TOKEN_REUSE_DETECTED.
class SingleFlightAuthInterceptor extends QueuedInterceptor {
  SingleFlightAuthInterceptor({
    required this.tokenStore,
    required this.retryDio,
    required this.onRefreshToken,
    required this.onSessionExpired,
    this.onConnectivityChanged,
  });

  final TokenStore tokenStore;
  final Dio retryDio;
  final TokenRefresher onRefreshToken;
  final Future<void> Function() onSessionExpired;
  final void Function(bool isDegraded)? onConnectivityChanged;

  static const _uuid = Uuid();
  Completer<String?>? _refreshCompleter;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    options.headers.putIfAbsent('X-Request-Id', () => _uuid.v4());
    final isPublic =
        options.path.endsWith('/auth/login') ||
        options.path.endsWith('/auth/refresh') ||
        options.path.endsWith('/health');

    if (!isPublic && !options.headers.containsKey('Authorization')) {
      final token = await tokenStore.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    onConnectivityChanged?.call(false);
    handler.next(response);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.type == DioExceptionType.connectionError ||
        err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout) {
      onConnectivityChanged?.call(true);
    }

    final req = err.requestOptions;
    final statusCode = err.response?.statusCode;
    final alreadyRetried = req.extra['_hti_retried'] == true;
    final isAuthEndpoint =
        req.path.endsWith('/auth/login') ||
        req.path.endsWith('/auth/refresh') ||
        req.path.endsWith('/auth/logout');

    if (statusCode != 401 || alreadyRetried || isAuthEndpoint) {
      handler.next(err);
      return;
    }

    // Jika token saat ini sudah lebih baru dibanding yang gagal pada request lama, langsung retry
    final currentAccess = await tokenStore.readAccessToken();
    final sentAuth = req.headers['Authorization'] as String?;
    if (currentAccess != null && sentAuth != 'Bearer $currentAccess') {
      return _retryRequest(req, currentAccess, handler, err);
    }

    // Single-flight refresh lock
    final newAccessToken = await _performSingleFlightRefresh();
    if (newAccessToken == null) {
      await tokenStore.clearTokens();
      await onSessionExpired();
      handler.next(err);
      return;
    }

    return _retryRequest(req, newAccessToken, handler, err);
  }

  Future<String?> _performSingleFlightRefresh() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    final completer = Completer<String?>();
    _refreshCompleter = completer;

    try {
      final refreshToken = await tokenStore.readRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) {
        completer.complete(null);
        return null;
      }

      final rotated = await onRefreshToken(refreshToken);
      await tokenStore.saveTokens(
        accessToken: rotated.accessToken,
        refreshToken: rotated.refreshToken,
      );
      completer.complete(rotated.accessToken);
      return rotated.accessToken;
    } catch (_) {
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<void> _retryRequest(
    RequestOptions req,
    String accessToken,
    ErrorInterceptorHandler handler,
    DioException originalErr,
  ) async {
    try {
      final cloned = req.copyWith(
        headers: {
          ...req.headers,
          'Authorization': 'Bearer $accessToken',
        },
        extra: {
          ...req.extra,
          '_hti_retried': true,
        },
      );
      final response = await retryDio.fetch<dynamic>(cloned);
      handler.resolve(response);
    } on DioException catch (retryErr) {
      handler.next(retryErr);
    } catch (_) {
      handler.next(originalErr);
    }
  }
}
