import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../inventory/inventory_providers.dart';
import 'dashboard_repository.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _drillDownLocation(BuildContext context, WidgetRef ref, int locationId) {
    ref.read(inventoryFilterProvider.notifier).state = InventoryFilter(locationId: locationId);
    context.go('/inventory');
  }

  void _drillDownCategory(BuildContext context, WidgetRef ref, int categoryId) {
    ref.read(inventoryFilterProvider.notifier).state = InventoryFilter(categoryId: categoryId);
    context.go('/inventory');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final fmt = NumberFormat('#,###', 'id_ID');

    return RefreshIndicator(
      onRefresh: () => ref.refresh(dashboardSummaryProvider.future),
      child: summaryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 48, color: HtiColors.statusBroken),
                const SizedBox(height: 12),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: HtiColors.statusBroken),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(dashboardSummaryProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Muat Ulang'),
                ),
              ],
            ),
          ),
        ),
        data: (summary) {
          final goodPct = summary.totalVolume > 0
              ? (summary.good * 100 / summary.totalVolume).toStringAsFixed(1)
              : '0.0';

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ringkasan Inventaris PT HTI',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: HtiColors.navyPrimary,
                          ),
                        ),
                        Text(
                          'Ketuk kartu lokasi atau kategori untuk langsung membuka daftar stok terfilter.',
                          style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Segarkan Data',
                    onPressed: () => ref.invalidate(dashboardSummaryProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (summary.pendingIncomingTransfers > 0) ...[
                Card(
                  color: HtiColors.statusInTransit.withValues(alpha: 0.08),
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_shipping_outlined,
                      color: HtiColors.statusInTransit,
                      size: 30,
                    ),
                    title: Text(
                      '${summary.pendingIncomingTransfers} Transfer Masuk Menunggu Konfirmasi',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: HtiColors.navyPrimary),
                    ),
                    subtitle: const Text('Segera periksa fisik barang dan konfirmasi Terima/Tolak.'),
                    trailing: ElevatedButton(
                      onPressed: () => context.go('/transfers'),
                      child: const Text('Buka Transfer'),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Grand Total Hero Card
              Card(
                color: HtiColors.navyPrimary,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    spacing: 28,
                    runSpacing: 16,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      _HeroMetric(
                        label: 'Total Volume Unit',
                        value: fmt.format(summary.totalVolume),
                        sub: '${fmt.format(summary.itemsCount)} jenis item aktif',
                        highlight: Colors.amber,
                      ),
                      _HeroMetric(
                        label: 'Kondisi Good',
                        value: fmt.format(summary.good),
                        sub: '$goodPct% layak operasi',
                        highlight: const Color(0xFF86EFAC),
                      ),
                      _HeroMetric(
                        label: 'Dalam Service',
                        value: fmt.format(summary.service),
                        sub: 'Perlu perbaikan',
                        highlight: const Color(0xFFFDBA74),
                      ),
                      _HeroMetric(
                        label: 'Kondisi Broken',
                        value: fmt.format(summary.broken),
                        sub: 'Tidak layak operasi (K3)',
                        highlight: const Color(0xFFFCA5A5),
                      ),
                      _HeroMetric(
                        label: 'In-Transit',
                        value: fmt.format(summary.inTransit),
                        sub: 'Dalam pengiriman',
                        highlight: const Color(0xFF93C5FD),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              const Text(
                'Distribusi 4 Lokasi Operasional',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: HtiColors.navyPrimary),
              ),
              const SizedBox(height: 10),

              LayoutBuilder(
                builder: (context, constraints) {
                  final crossCount = constraints.maxWidth >= 960
                      ? 4
                      : constraints.maxWidth >= 600
                          ? 2
                          : 1;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: summary.byLocation.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 232,
                    ),
                    itemBuilder: (_, idx) {
                      final loc = summary.byLocation[idx];
                      return _LocationKpiCard(
                        loc: loc,
                        fmt: fmt,
                        onTap: () => _drillDownLocation(context, ref, loc.locationId),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),

              const Text(
                'Ringkasan 9 Kategori Utama',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: HtiColors.navyPrimary),
              ),
              const SizedBox(height: 10),
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < summary.byCategory.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        onTap: () => _drillDownCategory(context, ref, summary.byCategory[i].categoryId),
                        leading: CircleAvatar(
                          backgroundColor: HtiColors.navyPrimary.withValues(alpha: 0.1),
                          child: Text(
                            summary.byCategory[i].code,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: HtiColors.navyPrimary,
                            ),
                          ),
                        ),
                        title: Text(
                          summary.byCategory[i].name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        subtitle: Text('${fmt.format(summary.byCategory[i].totalItems)} jenis item'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${fmt.format(summary.byCategory[i].totalUnits)} unit',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: HtiColors.navyPrimary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.chevron_right, size: 18, color: Colors.blueGrey),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
    required this.sub,
    required this.highlight,
  });

  final String label;
  final String value;
  final String sub;
  final Color highlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: highlight, fontSize: 24, fontWeight: FontWeight.w900)),
        Text(sub, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

class _LocationKpiCard extends StatelessWidget {
  const _LocationKpiCard({
    required this.loc,
    required this.fmt,
    required this.onTap,
  });

  final LocationSummary loc;
  final NumberFormat fmt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSite = loc.locationType == 'SITE';
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isSite ? Icons.engineering_outlined : Icons.warehouse_outlined,
                    color: HtiColors.navyPrimary,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      loc.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                  Text(
                    loc.code,
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    '${fmt.format(loc.total)} unit',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: HtiColors.navyPrimary,
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.open_in_new, size: 15, color: Colors.blueGrey),
                ],
              ),
              const SizedBox(height: 8),
              // Stacked 3+1 Color K3 Health Bar
              _StackedHealthBar(
                good: loc.good,
                service: loc.service,
                broken: loc.broken,
                inTransit: loc.inTransit,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ConditionStatusBadge(status: 'GOOD', count: loc.good),
                  ConditionStatusBadge(status: 'SERVICE', count: loc.service),
                  ConditionStatusBadge(status: 'BROKEN', count: loc.broken),
                  if (loc.inTransit > 0) ConditionStatusBadge(status: 'IN_TRANSIT', count: loc.inTransit),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StackedHealthBar extends StatelessWidget {
  const _StackedHealthBar({
    required this.good,
    required this.service,
    required this.broken,
    required this.inTransit,
  });

  final int good;
  final int service;
  final int broken;
  final int inTransit;

  @override
  Widget build(BuildContext context) {
    final total = good + service + broken + inTransit;
    if (total <= 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (good > 0) Expanded(flex: good, child: Container(color: HtiColors.statusGood)),
            if (service > 0) Expanded(flex: service, child: Container(color: HtiColors.statusService)),
            if (broken > 0) Expanded(flex: broken, child: Container(color: HtiColors.statusBroken)),
            if (inTransit > 0) Expanded(flex: inTransit, child: Container(color: HtiColors.statusInTransit)),
          ],
        ),
      ),
    );
  }
}
