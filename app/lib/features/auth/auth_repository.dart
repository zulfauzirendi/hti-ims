import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final UserProfile user;
}

class AuthRepository {
  const AuthRepository(this._dio);

  final Dio _dio;

  String _detectDeviceInfo() {
    if (kIsWeb) return 'Web Client';
    return '${Platform.operatingSystem} (${Platform.operatingSystemVersion})'.substring(
      0,
      '${Platform.operatingSystem} (${Platform.operatingSystemVersion})'.length.clamp(0, 140),
    );
  }

  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/login',
        data: {
          'username': username.trim(),
          'password': password,
          'deviceInfo': _detectDeviceInfo(),
        },
      );
      final data = res.data!['data'] as Map<String, dynamic>;
      return LoginResponse(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
        user: UserProfile.fromJson(data['user'] as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<UserProfile> fetchMe() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/auth/me');
      final data = res.data!['data'] as Map<String, dynamic>;
      return UserProfile.fromJson(data);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/change-password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> logout(String refreshToken) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/auth/logout',
        data: {'refreshToken': refreshToken},
      );
    } catch (_) {
      // Tetap lanjutkan pembersihan token lokal meski jaringan terputus
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(dioProvider));
});
