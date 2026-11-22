import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/inventory_models.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';
import 'inventory_providers.dart';
import 'stock_action_modals.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchCtrl.text = ref.read(inventoryFilterProvider).query;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    // Debounce 300ms sesuai SRS-CAP-007
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref.read(inventoryFilterProvider.notifier).update(
            (f) => f.copyWith(query: value, page: 1),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final filter = ref.watch(inventoryFilterProvider);
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const <CategoryRef>[];
    final locations = ref.watch(locationsProvider).valueOrNull ?? const <LocationRef>[];
    final searchAsync = ref.watch(inventorySearchProvider);

    return Column(
      children: [
        // Top Search & Filter Bar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Cari nama alat, spesifikasi, atau SKU (mis. Crane, Grinding, HTI-EQP)...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _onSearchChanged('');
                                },
                                icon: const Icon(Icons.clear),
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (user?.isSuperAdmin ?? false) ...[
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => showCreateItemModal(context, ref, categories),
                      icon: const Icon(Icons.add),
                      label: const Text('Item Baru'),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Quick filter "Lokasi Saya" untuk Admin Gudang & Petugas Lapangan
                    if (user?.assignedLocation != null) ...[
                      FilterChip(
                        selected: filter.locationId == user!.assignedLocation!.id,
                        label: Text('Lokasi Saya (${user.assignedLocation!.code})'),
                        onSelected: (selected) {
                          ref.read(inventoryFilterProvider.notifier).update(
                                (f) => f.copyWith(
                                  locationId: () => selected ? user.assignedLocation!.id : null,
                                  page: 1,
                                ),
                              );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    _DropdownChip<int?>(
                      label: 'Kategori',
                      value: filter.categoryId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Semua Kategori')),
                        for (final c in categories)
                          DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                      ],
                      onChanged: (v) => ref.read(inventoryFilterProvider.notifier).update(
                            (f) => f.copyWith(categoryId: () => v, page: 1),
                          ),
                    ),
                    const SizedBox(width: 8),
                    _DropdownChip<int?>(
                      label: 'Lokasi',
                      value: filter.locationId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('Semua 4 Lokasi')),
                        for (final l in locations)
                          DropdownMenuItem<int?>(value: l.id, child: Text(l.name)),
                      ],
                      onChanged: (v) => ref.read(inventoryFilterProvider.notifier).update(
                            (f) => f.copyWith(locationId: () => v, page: 1),
                          ),
                    ),
                    const SizedBox(width: 8),
                    _DropdownChip<String?>(
                      label: 'Kondisi',
                      value: filter.condition,
                      items: const [
                        DropdownMenuItem<String?>(value: null, child: Text('Semua Kondisi')),
                        DropdownMenuItem<String?>(value: 'GOOD', child: Text('GOOD')),
                        DropdownMenuItem<String?>(value: 'SERVICE', child: Text('SERVICE')),
                        DropdownMenuItem<String?>(value: 'BROKEN', child: Text('BROKEN')),
                        DropdownMenuItem<String?>(value: 'IN_TRANSIT', child: Text('IN_TRANSIT')),
                      ],
                      onChanged: (v) => ref.read(inventoryFilterProvider.notifier).update(
                            (f) => f.copyWith(condition: () => v, page: 1),
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Search Results List & 4-Location Matrix
        Expanded(
          child: searchAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(err.toString(), style: const TextStyle(color: HtiColors.statusBroken)),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => ref.invalidate(inventorySearchProvider),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
            data: (result) {
              if (result.items.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off, size: 48, color: Colors.blueGrey),
                      SizedBox(height: 8),
                      Text('Tidak ada item yang sesuai dengan pencarian/filter.'),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref.refresh(inventorySearchProvider.future),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: result.items.length,
                        itemBuilder: (_, idx) => _InventoryItemCard(
                          item: result.items[idx],
                          user: user,
                          allLocations: locations,
                        ),
                      ),
                    ),
                  ),
                  // Pagination footer
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Menampilkan ${result.items.length} dari ${result.total} item',
                          style: const TextStyle(fontSize: 12.5, color: Colors.blueGrey),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: result.page > 1
                                  ? () => ref
                                      .read(inventoryFilterProvider.notifier)
                                      .update((f) => f.copyWith(page: result.page - 1))
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('Hal ${result.page} / ${result.totalPages}'),
                            IconButton(
                              onPressed: result.page < result.totalPages
                                  ? () => ref
                                      .read(inventoryFilterProvider.notifier)
                                      .update((f) => f.copyWith(page: result.page + 1))
                                  : null,
                              icon: const Icon(Icons.chevron_right),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InventoryItemCard extends ConsumerWidget {
  const _InventoryItemCard({
    required this.item,
    required this.user,
    required this.allLocations,
  });

  final InventoryItem item;
  final UserProfile? user;
  final List<LocationRef> allLocations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: HtiColors.navyPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                item.itemCode,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: HtiColors.navyPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.description,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            Text(
              '${item.totalVolume} ${item.unit}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: HtiColors.navyPrimary),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.category.name}${item.specification != null ? ' • ${item.specification}' : ''}',
                style: const TextStyle(fontSize: 12.5, color: Colors.blueGrey),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ConditionStatusBadge(status: 'GOOD', count: item.totalGood),
                  if (item.totalService > 0)
                    ConditionStatusBadge(status: 'SERVICE', count: item.totalService),
                  if (item.totalBroken > 0)
                    ConditionStatusBadge(status: 'BROKEN', count: item.totalBroken),
                  if (item.totalInTransit > 0)
                    ConditionStatusBadge(status: 'IN_TRANSIT', count: item.totalInTransit),
                ],
              ),
            ],
          ),
        ),
        children: [
          const Divider(),
          // Breakdown 4 Lokasi Operasional
          for (final st in item.stocks)
            _LocationStockRow(
              item: item,
              stock: st,
              user: user,
              allLocations: allLocations,
            ),
        ],
      ),
    );
  }
}

class _LocationStockRow extends ConsumerWidget {
  const _LocationStockRow({
    required this.item,
    required this.stock,
    required this.user,
    required this.allLocations,
  });

  final InventoryItem item;
  final ItemStockEntry stock;
  final UserProfile? user;
  final List<LocationRef> allLocations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canWrite = user?.canWriteLocation(stock.locationId, allowFieldTech: true) ?? false;
    final canStockIn = user?.canWriteLocation(stock.locationId, allowFieldTech: false) ?? false;
    final canDispose = (user?.isSuperAdmin ?? false) && stock.qtyBroken > 0;
    final hasStock = stock.qtyGood + stock.qtyService + stock.qtyBroken > 0;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: canWrite ? HtiColors.slateBg : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: canWrite ? HtiColors.navyPrimary.withValues(alpha: 0.3) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${stock.locationName} (${stock.locationCode})',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
              ),
              Text(
                'Total: ${stock.total} ${item.unit}',
                style: const TextStyle(fontWeight: FontWeight.w700, color: HtiColors.navyPrimary),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ConditionStatusBadge(status: 'GOOD', count: stock.qtyGood),
              ConditionStatusBadge(status: 'SERVICE', count: stock.qtyService),
              ConditionStatusBadge(status: 'BROKEN', count: stock.qtyBroken),
              if (stock.qtyInTransit > 0)
                ConditionStatusBadge(status: 'IN_TRANSIT', count: stock.qtyInTransit),
            ],
          ),
          if (stock.jobCode != null || stock.remarks != null) ...[
            const SizedBox(height: 6),
            Text(
              '${stock.jobCode != null ? 'Job: ${stock.jobCode}  ' : ''}${stock.remarks ?? ''}',
              style: const TextStyle(fontSize: 12, color: Colors.blueGrey),
            ),
          ],
          if (canWrite || canStockIn || canDispose) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canWrite && hasStock)
                  OutlinedButton.icon(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => ConditionUpdateDialog(item: item, stock: stock),
                    ),
                    icon: const Icon(Icons.build_outlined, size: 16),
                    label: const Text('Ubah Kondisi'),
                  ),
                if (canWrite && hasStock && allLocations.length > 1)
                  OutlinedButton.icon(
                    onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => CreateTransferDialog(
                        item: item,
                        sourceStock: stock,
                        allLocations: allLocations,
                      ),
                    ),
                    icon: const Icon(Icons.send_outlined, size: 16),
                    label: const Text('Transfer'),
                  ),
                if (canWrite && stock.stockId != null)
                  OutlinedButton.icon(
                    onPressed: () => showRemarksModal(context, ref, item, stock),
                    icon: const Icon(Icons.edit_note, size: 16),
                    label: const Text('Job / Remarks'),
                  ),
                if (canStockIn)
                  OutlinedButton.icon(
                    onPressed: () => showStockInModal(context, ref, item, stock),
                    icon: const Icon(Icons.add_box_outlined, size: 16),
                    label: const Text('Stock In'),
                  ),
                if (canDispose)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(foregroundColor: HtiColors.statusBroken),
                    onPressed: () => showDisposalModal(context, ref, item, stock),
                    icon: const Icon(Icons.delete_forever_outlined, size: 16),
                    label: const Text('Disposal'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DropdownChip<T> extends StatelessWidget {
  const _DropdownChip({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: HtiColors.slateBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          hint: Text(label),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
