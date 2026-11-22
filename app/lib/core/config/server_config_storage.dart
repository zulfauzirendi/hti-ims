import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/inventory_models.dart';

const String _kServerBaseUrlKey = 'hti_server_base_url';

/// Default endpoint: localhost saat debug, domain produksi PT HTI saat release.
/// Pengguna dapat mengubahnya kapan saja (On-Premise LAN <-> Cloud VPS) tanpa rebuild (SRS-ADP-001).
String get defaultServerBaseUrl =>
    kDebugMode ? 'http://127.0.0.1:3000' : 'https://inv.hti.co.id';

String normalizeServerUrl(String raw) {
  var cleaned = raw.trim();
  while (cleaned.endsWith('/')) {
    cleaned = cleaned.substring(0, cleaned.length - 1);
  }
  return cleaned;
}

class ServerConfigNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kServerBaseUrlKey);
    if (saved != null && saved.trim().isNotEmpty) {
      return normalizeServerUrl(saved);
    }
    return defaultServerBaseUrl;
  }

  Future<void> setServerUrl(String newUrl) async {
    final normalized = normalizeServerUrl(newUrl);
    final uri = Uri.tryParse(normalized);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      throw const FormatException('URL server tidak valid. Gunakan format https://... atau http://...');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerBaseUrlKey, normalized);
    state = AsyncData(normalized);
  }

  /// Uji koneksi server melalui GET /api/v1/health dalam batas 5 detik (SRS-EIF-007)
  Future<HealthCheckResult> testConnection(String candidateUrl) async {
    final normalized = normalizeServerUrl(candidateUrl);
    final dio = Dio(
      BaseOptions(
        baseUrl: normalized,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ),
    );
    final sw = Stopwatch()..start();
    try {
      final res = await dio.get<Map<String, dynamic>>('/api/v1/health');
      sw.stop();
      final data = res.data?['data'] as Map<String, dynamic>?;
      final ok = res.statusCode == 200 && data?['status'] == 'ok';
      return HealthCheckResult(
        ok: ok,
        latencyMs: sw.elapsedMilliseconds,
        message: ok
            ? 'Terhubung ke server PT HTI (${sw.elapsedMilliseconds} ms)'
            : 'Server merespons status terdegradasi (${res.statusCode}).',
        latestClientVersion: data?['latestClientVersion'] as String?,
      );
    } on DioException catch (e) {
      sw.stop();
      return HealthCheckResult(
        ok: false,
        latencyMs: sw.elapsedMilliseconds,
        message: 'Gagal terhubung ke $normalized (${e.type.name}). Periksa jaringan atau URL server.',
      );
    }
  }
}

final serverConfigProvider = AsyncNotifierProvider<ServerConfigNotifier, String>(
  ServerConfigNotifier.new,
);
