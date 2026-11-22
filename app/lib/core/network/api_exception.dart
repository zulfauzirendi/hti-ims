import 'package:dio/dio.dart';

class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.isNetworkError = false,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final bool isNetworkError;

  factory ApiException.fromDio(DioException err) {
    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      return const ApiException(
        code: 'NETWORK_UNAVAILABLE',
        message: 'Koneksi ke server terputus atau lambat. Data formulir Anda tetap aman — silakan coba lagi.',
        isNetworkError: true,
      );
    }

    final statusCode = err.response?.statusCode;
    final data = err.response?.data;
    if (data is Map<String, dynamic>) {
      final errorObj = data['error'] as Map<String, dynamic>?;
      final metaObj = data['meta'] as Map<String, dynamic>?;
      if (errorObj != null) {
        return ApiException(
          code: (errorObj['code'] as String?) ?? 'UNKNOWN_ERROR',
          message: (errorObj['message'] as String?) ?? 'Terjadi kesalahan pada server.',
          statusCode: statusCode,
          requestId: metaObj?['requestId'] as String?,
        );
      }
    }

    return ApiException(
      code: 'HTTP_${statusCode ?? 0}',
      message: 'Permintaan gagal diproses (HTTP ${statusCode ?? '-'}). Silakan coba lagi.',
      statusCode: statusCode,
    );
  }

  @override
  String toString() => requestId != null ? '$message (Ref: $requestId)' : message;
}
