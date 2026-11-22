import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/change_password_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/inventory/inventory_screen.dart';
import '../../features/logs/audit_logs_screen.dart';
import '../../features/master/users_management_screen.dart';
import '../../features/transfers/transfers_screen.dart';
import '../../layouts/adaptive_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    redirect: (context, state) {
      final path = state.matchedLocation;

      if (authState.status == AuthStatus.loading) {
        return null;
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return path == '/login' ? null : '/login';
      }

      // Wajib ganti password sebelum mengakses fitur operasional (SRS-SEC-012)
      if (authState.status == AuthStatus.mustChangePassword) {
        return path == '/change-password' ? null : '/change-password';
      }

      if (path == '/login' || path == '/change-password') {
        return '/dashboard';
      }

      if (path.startsWith('/users') && !(authState.user?.isSuperAdmin ?? false)) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AdaptiveShell(
          currentPath: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/inventory',
            builder: (context, state) => const InventoryScreen(),
          ),
          GoRoute(
            path: '/transfers',
            builder: (context, state) => const TransfersScreen(),
          ),
          GoRoute(
            path: '/logs',
            builder: (context, state) => const AuditLogsScreen(),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => const UsersManagementScreen(),
          ),
        ],
      ),
    ],
  );
});
