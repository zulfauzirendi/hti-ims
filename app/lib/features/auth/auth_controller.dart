import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/network/dio_client.dart';
import '../../core/security/secure_token_storage.dart';
import 'auth_repository.dart';

enum AuthStatus {
  loading,
  unauthenticated,
  mustChangePassword,
  authenticated,
}

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  final AuthStatus status;
  final UserProfile? user;
  final String? errorMessage;

  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.unauthenticated([String? message])
      : this(status: AuthStatus.unauthenticated, errorMessage: message);
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    ref.listen<int>(sessionExpiredCounterProvider, (prev, next) {
      if (prev != null && next > prev) {
        state = const AuthState.unauthenticated(
          'Sesi Anda telah berakhir atau dicabut. Silakan login kembali.',
        );
      }
    });

    Future.microtask(restoreSession);
    return const AuthState.loading();
  }

  Future<void> restoreSession() async {
    final tokenStore = ref.read(tokenStoreProvider);
    final access = await tokenStore.readAccessToken();
    final refresh = await tokenStore.readRefreshToken();
    if ((access == null || access.isEmpty) && (refresh == null || refresh.isEmpty)) {
      state = const AuthState.unauthenticated();
      return;
    }

    try {
      final user = await ref.read(authRepositoryProvider).fetchMe();
      state = AuthState(
        status: user.mustChangePassword
            ? AuthStatus.mustChangePassword
            : AuthStatus.authenticated,
        user: user,
      );
    } catch (_) {
      await tokenStore.clearTokens();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login({required String username, required String password}) async {
    final repo = ref.read(authRepositoryProvider);
    final tokenStore = ref.read(tokenStoreProvider);

    final res = await repo.login(username: username, password: password);
    await tokenStore.saveTokens(
      accessToken: res.accessToken,
      refreshToken: res.refreshToken,
    );

    state = AuthState(
      status: res.user.mustChangePassword
          ? AuthStatus.mustChangePassword
          : AuthStatus.authenticated,
      user: res.user,
    );
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
    // Setelah ganti password, backend mencabut sesi lama -> arahkan login ulang dengan sandi baru
    await ref.read(tokenStoreProvider).clearTokens();
    state = const AuthState.unauthenticated(
      'Kata sandi berhasil diperbarui. Silakan login menggunakan kata sandi baru Anda.',
    );
  }

  Future<void> logout() async {
    final tokenStore = ref.read(tokenStoreProvider);
    final refreshToken = await tokenStore.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await ref.read(authRepositoryProvider).logout(refreshToken);
    }
    await tokenStore.clearTokens();
    state = const AuthState.unauthenticated();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
