import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/dio_client.dart';

class ManagedUserRecord {
  const ManagedUserRecord({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.mustChangePassword,
    required this.isActive,
    this.assignedLocation,
  });

  final int id;
  final String username;
  final String fullName;
  final UserRole role;
  final bool mustChangePassword;
  final bool isActive;
  final LocationRef? assignedLocation;

  factory ManagedUserRecord.fromJson(Map<String, dynamic> json) => ManagedUserRecord(
        id: (json['id'] as num).toInt(),
        username: json['username'] as String,
        fullName: json['fullName'] as String,
        role: UserRole.fromApi(json['role'] as String),
        mustChangePassword: (json['mustChangePassword'] as bool?) ?? false,
        isActive: (json['isActive'] as bool?) ?? true,
        assignedLocation: json['assignedLocation'] != null
            ? LocationRef.fromJson(json['assignedLocation'] as Map<String, dynamic>)
            : null,
      );
}

class UsersRepository {
  const UsersRepository(this._dio);

  final Dio _dio;

  Future<List<ManagedUserRecord>> listUsers() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/v1/users');
      final list = res.data!['data'] as List<dynamic>;
      return list.map((e) => ManagedUserRecord.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> createUser({
    required String username,
    required String fullName,
    required String password,
    required UserRole role,
    int? assignedLocationId,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/v1/users',
        data: {
          'username': username.trim(),
          'fullName': fullName.trim(),
          'password': password,
          'role': role.apiValue,
          'assignedLocationId': assignedLocationId,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> updateUser(
    int userId, {
    bool? isActive,
    String? resetPassword,
  }) async {
    try {
      await _dio.patch<Map<String, dynamic>>(
        '/api/v1/users/$userId',
        data: {
          'isActive': ?isActive,
          if (resetPassword != null && resetPassword.isNotEmpty) 'resetPassword': resetPassword,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<int> revokeAllSessions(int userId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>('/api/v1/users/$userId/revoke-sessions');
      final data = res.data!['data'] as Map<String, dynamic>;
      return (data['revokedSessions'] as num?)?.toInt() ?? 0;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(dioProvider));
});

final managedUsersProvider = FutureProvider<List<ManagedUserRecord>>((ref) {
  return ref.watch(usersRepositoryProvider).listUsers();
});
