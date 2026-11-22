import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/models/user_model.dart';
import '../core/network/dio_client.dart';
import '../core/theme/app_theme.dart';
import '../features/auth/auth_controller.dart';

/// Provider angka badge transfer masuk IN_TRANSIT (akan dihubungkan ke Dashboard/Transfers di Fase 4)
final pendingIncomingTransfersCountProvider = StateProvider<int>((ref) => 0);

/// Breakpoint adaptif resmi sesuai HLD/LLD: >= 900dp DesktopShell, < 900dp MobileShell
const double kDesktopBreakpoint = 900.0;

class _NavItem {
  const _NavItem({
    required this.route,
    required this.label,
    required this.icon,
    this.superAdminOnly = false,
    this.showTransferBadge = false,
  });

  final String route;
  final String label;
  final IconData icon;
  final bool superAdminOnly;
  final bool showTransferBadge;
}

const _allDesktopNav = [
  _NavItem(route: '/dashboard', label: 'Dashboard', icon: Icons.dashboard_outlined),
  _NavItem(route: '/inventory', label: 'Inventaris', icon: Icons.inventory_2_outlined),
  _NavItem(
    route: '/transfers',
    label: 'Transfer',
    icon: Icons.swap_horiz_rounded,
    showTransferBadge: true,
  ),
  _NavItem(route: '/logs', label: 'Audit & Laporan', icon: Icons.fact_check_outlined),
  _NavItem(route: '/users', label: 'Pengguna', icon: Icons.manage_accounts_outlined, superAdminOnly: true),
];

const _mobileNav = [
  _NavItem(route: '/inventory', label: 'Inventaris', icon: Icons.inventory_2_outlined),
  _NavItem(
    route: '/transfers',
    label: 'Transfer',
    icon: Icons.swap_horiz_rounded,
    showTransferBadge: true,
  ),
  _NavItem(route: '/dashboard', label: 'Ringkasan', icon: Icons.dashboard_outlined),
  _NavItem(route: '/logs', label: 'Audit', icon: Icons.fact_check_outlined),
];

class AdaptiveShell extends ConsumerWidget {
  const AdaptiveShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  final String currentPath;
  final Widget child;

  Widget _badgeIcon(IconData icon, int count, bool enabled) {
    if (!enabled || count <= 0) return Icon(icon);
    return Badge(
      label: Text(count > 99 ? '99+' : '$count'),
      backgroundColor: HtiColors.statusBroken,
      child: Icon(icon),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final degraded = ref.watch(connectivityDegradedProvider);
    final pendingTransfers = ref.watch(pendingIncomingTransfersCountProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= kDesktopBreakpoint;

        final contentWithBanner = Column(
          children: [
            if (degraded)
              MaterialBanner(
                backgroundColor: HtiColors.statusService.withValues(alpha: 0.15),
                leading: const Icon(Icons.wifi_off, color: HtiColors.statusService),
                content: const Text(
                  'Koneksi jaringan terganggu — data isian Anda tetap aman. Periksa koneksi lalu coba lagi.',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                actions: [
                  TextButton(
                    onPressed: () => ref.read(connectivityDegradedProvider.notifier).state = false,
                    child: const Text('Tutup'),
                  ),
                ],
              ),
            Expanded(child: child),
          ],
        );

        if (isDesktop) {
          return _DesktopShell(
            currentPath: currentPath,
            user: user,
            pendingTransfers: pendingTransfers,
            badgeIconBuilder: _badgeIcon,
            onLogout: () => ref.read(authControllerProvider.notifier).logout(),
            child: contentWithBanner,
          );
        }

        return _MobileShell(
          currentPath: currentPath,
          user: user,
          pendingTransfers: pendingTransfers,
          badgeIconBuilder: _badgeIcon,
          onLogout: () => ref.read(authControllerProvider.notifier).logout(),
          child: contentWithBanner,
        );
      },
    );
  }
}

class _DesktopShell extends StatelessWidget {
  const _DesktopShell({
    required this.currentPath,
    required this.user,
    required this.pendingTransfers,
    required this.badgeIconBuilder,
    required this.onLogout,
    required this.child,
  });

  final String currentPath;
  final UserProfile? user;
  final int pendingTransfers;
  final Widget Function(IconData, int, bool) badgeIconBuilder;
  final VoidCallback onLogout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final visibleItems = _allDesktopNav
        .where((item) => !item.superAdminOnly || (user?.isSuperAdmin ?? false))
        .toList();
    var selectedIdx = visibleItems.indexWhere((i) => currentPath.startsWith(i.route));
    if (selectedIdx < 0) selectedIdx = 0;

    return CallbackShortcuts(
      bindings: {
        // Pintasan keyboard Desktop Ctrl+K -> langsung buka pencarian inventaris (SRS-QAL-014)
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => context.go('/inventory'),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('PT HTI Tool & Equipment Inventory System'),
            actions: [
              if (user != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Center(
                    child: Chip(
                      backgroundColor: HtiColors.navySurface,
                      side: BorderSide.none,
                      label: Text(
                        '${user!.fullName} • ${user!.role.displayLabel}'
                        '${user!.assignedLocation != null ? ' (${user!.assignedLocation!.code})' : ''}',
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              IconButton(
                tooltip: 'Keluar',
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Row(
            children: [
              NavigationRail(
                extended: true,
                minExtendedWidth: 210,
                backgroundColor: Colors.white,
                selectedIndex: selectedIdx,
                onDestinationSelected: (idx) => context.go(visibleItems[idx].route),
                destinations: [
                  for (final item in visibleItems)
                    NavigationRailDestination(
                      icon: badgeIconBuilder(item.icon, pendingTransfers, item.showTransferBadge),
                      label: Text(item.label),
                    ),
                ],
              ),
              const VerticalDivider(width: 1),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell({
    required this.currentPath,
    required this.user,
    required this.pendingTransfers,
    required this.badgeIconBuilder,
    required this.onLogout,
    required this.child,
  });

  final String currentPath;
  final UserProfile? user;
  final int pendingTransfers;
  final Widget Function(IconData, int, bool) badgeIconBuilder;
  final VoidCallback onLogout;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    var selectedIdx = _mobileNav.indexWhere((i) => currentPath.startsWith(i.route));
    if (selectedIdx < 0) selectedIdx = 0;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PT HTI Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            if (user != null)
              Text(
                '${user!.fullName}${user!.assignedLocation != null ? ' • ${user!.assignedLocation!.name}' : ''}',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIdx,
        onDestinationSelected: (idx) => context.go(_mobileNav[idx].route),
        destinations: [
          for (final item in _mobileNav)
            NavigationDestination(
              icon: badgeIconBuilder(item.icon, pendingTransfers, item.showTransferBadge),
              label: item.label,
            ),
        ],
      ),
    );
  }
}
