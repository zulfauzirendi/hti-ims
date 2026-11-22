import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class TokenStore {
  Future<String?> readAccessToken();
  Future<String?> readRefreshToken();
  Future<void> saveTokens({required String accessToken, required String refreshToken});
  Future<void> clearTokens();
}

/// Penyimpanan token aman memanfaatkan OS Keystore / DPAPI / libsecret (SRS-SEC-003).
class SecureTokenStorage implements TokenStore {
  SecureTokenStorage()
      : _storage = const FlutterSecureStorage(
          aOptions: AndroidOptions(encryptedSharedPreferences: true),
        );

  static const String _kAccessKey = 'hti_access_token';
  static const String _kRefreshKey = 'hti_refresh_token';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readAccessToken() => _storage.read(key: _kAccessKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _kRefreshKey);

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await Future.wait([
      _storage.write(key: _kAccessKey, value: accessToken),
      _storage.write(key: _kRefreshKey, value: refreshToken),
    ]);
  }

  @override
  Future<void> clearTokens() async {
    await Future.wait([
      _storage.delete(key: _kAccessKey),
      _storage.delete(key: _kRefreshKey),
    ]);
  }
}

final tokenStoreProvider = Provider<TokenStore>((ref) => SecureTokenStorage());
