import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/server_config_storage.dart';
import '../security/secure_token_storage.dart';
import 'auth_interceptor.dart';

/// Indikator mode DEGRADED_CONNECTIVITY (SRS-MOD-002) agar banner tampil tanpa menghapus form
final connectivityDegradedProvider = StateProvider<bool>((ref) => false);

/// Callback event paksa logout ketika refresh token kedaluwarsa / reuse terdeteksi
final sessionExpiredCounterProvider = StateProvider<int>((ref) => 0);

final dioProvider = Provider<Dio>((ref) {
  final baseUrl = ref.watch(serverConfigProvider).valueOrNull ?? defaultServerBaseUrl;
  final tokenStore = ref.watch(tokenStoreProvider);

  final baseOptions = BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
    sendTimeout: const Duration(seconds: 45), // Mendukung upload multipart foto di 3G/4G (SRS-RES-009)
    headers: const {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    },
  );

  final dio = Dio(baseOptions);
  final refreshDio = Dio(baseOptions);

  dio.interceptors.add(
    SingleFlightAuthInterceptor(
      tokenStore: tokenStore,
      retryDio: dio,
      onConnectivityChanged: (degraded) {
        final current = ref.read(connectivityDegradedProvider);
        if (current != degraded) {
          ref.read(connectivityDegradedProvider.notifier).state = degraded;
        }
      },
      onRefreshToken: (refreshToken) async {
        final res = await refreshDio.post<Map<String, dynamic>>(
          '/api/v1/auth/refresh',
          data: {'refreshToken': refreshToken},
        );
        final data = res.data?['data'] as Map<String, dynamic>;
        return (
          accessToken: data['accessToken'] as String,
          refreshToken: data['refreshToken'] as String,
        );
      },
      onSessionExpired: () async {
        ref.read(sessionExpiredCounterProvider.notifier).state++;
      },
    ),
  );

  return dio;
});
