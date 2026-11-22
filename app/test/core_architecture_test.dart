import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hti_inventory_app/core/models/user_model.dart';
import 'package:hti_inventory_app/core/network/auth_interceptor.dart';
import 'package:hti_inventory_app/core/security/secure_token_storage.dart';
import 'package:hti_inventory_app/core/theme/app_theme.dart';
import 'package:hti_inventory_app/features/auth/login_screen.dart';
import 'package:hti_inventory_app/layouts/adaptive_shell.dart';

class _InMemoryTokenStore implements TokenStore {
  String? access;
  String? refresh;

  @override
  Future<void> clearTokens() async {
    access = null;
    refresh = null;
  }

  @override
  Future<String?> readAccessToken() async => access;

  @override
  Future<String?> readRefreshToken() async => refresh;

  @override
  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    access = accessToken;
    refresh = refreshToken;
  }
}

class _FakeAdapter implements HttpClientAdapter {
  @override
  void close({bool force = false}) {}

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final auth = options.headers['Authorization'] as String?;
    if (auth == 'Bearer fresh_token') {
      return ResponseBody.fromString('{"success":true,"data":"ok"}', 200);
    }
    return ResponseBody.fromString(
      '{"success":false,"error":{"code":"AUTH_TOKEN_EXPIRED","message":"expired"}}',
      401,
    );
  }
}

void main() {
  group('RBAC UI Helper (Read Global, Write Local)', () {
    test('enforces role and location rules accurately', () {
      const wh1 = LocationRef(id: 1, code: 'WH-1', name: 'Warehouse 1', locationType: 'WAREHOUSE');
      const sitePts = LocationRef(id: 3, code: 'SITE-PTS', name: 'Site PTS', locationType: 'SITE');

      const superAdmin = UserProfile(
        id: 1,
        username: 'sa',
        fullName: 'Super Admin',
        role: UserRole.superAdmin,
        mustChangePassword: false,
      );
      const adminWh1 = UserProfile(
        id: 2,
        username: 'wh1',
        fullName: 'Admin WH1',
        role: UserRole.adminGudang,
        mustChangePassword: false,
        assignedLocation: wh1,
      );
      const techPts = UserProfile(
        id: 3,
        username: 'pts',
        fullName: 'Tech PTS',
        role: UserRole.petugasLapangan,
        mustChangePassword: false,
        assignedLocation: sitePts,
      );
      const viewer = UserProfile(
        id: 4,
        username: 'hanif',
        fullName: 'Pak Hanif',
        role: UserRole.viewer,
        mustChangePassword: false,
      );

      expect(superAdmin.canWriteLocation(99), isTrue);
      expect(viewer.canWriteLocation(1), isFalse);
      expect(adminWh1.canWriteLocation(1, allowFieldTech: false), isTrue);
      expect(adminWh1.canWriteLocation(3, allowFieldTech: false), isFalse);
      expect(techPts.canWriteLocation(3, allowFieldTech: true), isTrue);
      expect(techPts.canWriteLocation(3, allowFieldTech: false), isFalse);
      expect(techPts.canWriteLocation(1, allowFieldTech: true), isFalse);
    });
  });

  group('Single-Flight Auth Refresh Interceptor (LLD 5.2)', () {
    test('executes refresh only ONCE when 3 parallel requests fail with 401', () async {
      final tokenStore = _InMemoryTokenStore()
        ..access = 'expired_token'
        ..refresh = 'valid_refresh_1';

      var refreshCalls = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://inv.hti.co.id'));
      dio.httpClientAdapter = _FakeAdapter();

      dio.interceptors.add(
        SingleFlightAuthInterceptor(
          tokenStore: tokenStore,
          retryDio: dio,
          onRefreshToken: (rt) async {
            refreshCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 30));
            return (accessToken: 'fresh_token', refreshToken: 'valid_refresh_2');
          },
          onSessionExpired: () async {},
        ),
      );

      final results = await Future.wait([
        dio.get<dynamic>('/api/v1/dashboard/summary'),
        dio.get<dynamic>('/api/v1/items/search'),
        dio.get<dynamic>('/api/v1/transfers'),
      ]);

      expect(refreshCalls, 1);
      for (final res in results) {
        expect(res.statusCode, 200);
      }
      expect(tokenStore.access, 'fresh_token');
      expect(tokenStore.refresh, 'valid_refresh_2');
    });
  });

  group('AdaptiveShell & LoginScreen Widget Tests', () {
    testWidgets('renders NavigationRail on Desktop (>= 900dp) and NavigationBar on Mobile (< 900dp)',
        (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [tokenStoreProvider.overrideWithValue(_InMemoryTokenStore())],
          child: MaterialApp(
            theme: HtiTheme.light(),
            home: const AdaptiveShell(
              currentPath: '/dashboard',
              child: Text('Desktop Content'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.byType(NavigationRail), findsNothing);
    });

    testWidgets('LoginScreen validates empty credentials in Bahasa Indonesia', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [tokenStoreProvider.overrideWithValue(_InMemoryTokenStore())],
          child: MaterialApp(
            theme: HtiTheme.light(),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Masuk ke Sistem'));
      await tester.pump();

      expect(find.text('Username minimal 3 karakter.'), findsOneWidget);
      expect(find.text('Kata sandi wajib diisi.'), findsOneWidget);
    });
  });
}
