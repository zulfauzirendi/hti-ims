import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../inventory/inventory_providers.dart';
import 'evidence_photo_lightbox.dart';
import 'logs_repository.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  bool _exporting = false;

  Future<void> _export(String type, String format) async {
    setState(() => _exporting = true);
    try {
      final filter = ref.read(logsFilterProvider);
      final savedPath = await ref.read(logsRepositoryProvider).downloadAndSaveReport(
            type: type,
            format: format,
            locationId: filter.locationId,
            dateFrom: filter.dateFrom,
            dateTo: filter.dateTo,
          );
      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HtiColors.statusGood,
            content: Text('Laporan berhasil disimpan: $savedPath'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HtiColors.statusBroken,
            content: Text('Gagal mengekspor laporan: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _pickDateRange() async {
    final current = ref.read(logsFilterProvider);
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024, 1, 1),
      lastDate: now.add(const Duration(days: 1)),
      initialDateRange: current.dateFrom != null && current.dateTo != null
          ? DateTimeRange(start: current.dateFrom!, end: current.dateTo!)
          : null,
      helpText: 'Pilih Rentang Tanggal Audit ISO 9001',
    );
    if (picked != null) {
      ref.read(logsFilterProvider.notifier).update(
            (f) => f.copyWith(
              dateFrom: () => picked.start,
              dateTo: () => picked.end,
              page: 1,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);
    final filter = ref.watch(logsFilterProvider);
    final locations = ref.watch(locationsProvider).valueOrNull ?? const <LocationRef>[];
    final shortDate = DateFormat('dd/MM/yy');

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ISO 9001 Audit Trail & Laporan Kepatuhan',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HtiColors.navyPrimary),
                        ),
                        Text(
                          'Jejak mutasi permanen (append-only) lengkap dengan diff saldo, bukti foto K3 & ekspor Excel/PDF.',
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Tombol aktif berwarna navy (memperbaiki bug visual disabled pada ElevatedButton(onPressed: null))
                  PopupMenuButton<String>(
                    enabled: !_exporting,
                    tooltip: 'Ekspor Laporan Resmi PT HTI',
                    onSelected: (choice) {
                      final parts = choice.split(':');
                      _export(parts[0], parts[1]);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'stock:xlsx',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.table_chart_outlined, color: HtiColors.statusGood),
                          title: Text('Export Stok → Excel (.xlsx)'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'stock:pdf',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.picture_as_pdf_outlined, color: HtiColors.statusBroken),
                          title: Text('Export Stok → PDF Resmi PT HTI'),
                        ),
                      ),
                      PopupMenuDivider(),
                      PopupMenuItem(
                        value: 'logs:xlsx',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.table_chart_outlined, color: HtiColors.statusGood),
                          title: Text('Export Audit Log → Excel (.xlsx)'),
                        ),
                      ),
                      PopupMenuItem(
                        value: 'logs:pdf',
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.picture_as_pdf_outlined, color: HtiColors.statusBroken),
                          title: Text('Export Audit Log → PDF ISO 9001'),
                        ),
                      ),
                    ],
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: _exporting ? Colors.blueGrey : HtiColors.navyPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_exporting)
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          else
                            const Icon(Icons.download_outlined, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            _exporting ? 'Mengekspor...' : 'Export Excel / PDF',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_drop_down, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String?>(
                    value: filter.actionType,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Semua Aksi')),
                      DropdownMenuItem(value: 'STATUS_CHANGE', child: Text('Perubahan Kondisi')),
                      DropdownMenuItem(value: 'TRANSFER_OUT', child: Text('Transfer Keluar')),
                      DropdownMenuItem(value: 'TRANSFER_IN', child: Text('Transfer Masuk')),
                      DropdownMenuItem(value: 'TRANSFER_REJECT', child: Text('Transfer Ditolak')),
                      DropdownMenuItem(value: 'TRANSFER_CANCEL', child: Text('Transfer Dibatalkan')),
                      DropdownMenuItem(value: 'STOCK_IN', child: Text('Stock In (Pengadaan)')),
                      DropdownMenuItem(value: 'DISPOSAL', child: Text('Disposal / Write-Off')),
                      DropdownMenuItem(value: 'REMARKS_UPDATE', child: Text('Update Remarks/Job')),
                      DropdownMenuItem(value: 'INITIAL_IMPORT', child: Text('Baseline Import Nov 25')),
                    ],
                    onChanged: (v) => ref.read(logsFilterProvider.notifier).update(
                          (f) => f.copyWith(actionType: () => v, page: 1),
                        ),
                  ),
                  DropdownButton<int?>(
                    value: filter.locationId,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua Lokasi')),
                      for (final l in locations) DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) => ref.read(logsFilterProvider.notifier).update(
                          (f) => f.copyWith(locationId: () => v, page: 1),
                        ),
                  ),
                  InputChip(
                    avatar: const Icon(Icons.date_range, size: 16),
                    label: Text(
                      filter.dateFrom != null && filter.dateTo != null
                          ? '${shortDate.format(filter.dateFrom!)} – ${shortDate.format(filter.dateTo!)}'
                          : 'Filter Tanggal',
                    ),
                    onPressed: _pickDateRange,
                    onDeleted: filter.dateFrom != null
                        ? () => ref.read(logsFilterProvider.notifier).update(
                              (f) => f.copyWith(dateFrom: () => null, dateTo: () => null, page: 1),
                            )
                        : null,
                  ),
                  IconButton(
                    tooltip: 'Segarkan',
                    onPressed: () => ref.invalidate(auditLogsProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: logsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(err.toString(), style: const TextStyle(color: HtiColors.statusBroken)),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(auditLogsProvider),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
            data: (paged) {
              if (paged.items.isEmpty) {
                return const Center(child: Text('Belum ada catatan audit log pada filter ini.'));
              }
              return Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => ref.refresh(auditLogsProvider.future),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: paged.items.length,
                        itemBuilder: (_, idx) => _AuditLogCard(log: paged.items[idx]),
                      ),
                    ),
                  ),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Menampilkan ${paged.items.length} dari ${paged.total} log audit',
                          style: const TextStyle(fontSize: 12.5, color: Colors.blueGrey),
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: paged.page > 1
                                  ? () => ref
                                      .read(logsFilterProvider.notifier)
                                      .update((f) => f.copyWith(page: paged.page - 1))
                                  : null,
                              icon: const Icon(Icons.chevron_left),
                            ),
                            Text('Hal ${paged.page} / ${paged.totalPages}'),
                            IconButton(
                              onPressed: paged.page < paged.totalPages
                                  ? () => ref
                                      .read(logsFilterProvider.notifier)
                                      .update((f) => f.copyWith(page: paged.page + 1))
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

class _AuditLogCard extends StatelessWidget {
  const _AuditLogCard({required this.log});

  final StockLogEntry log;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('dd MMM yyyy HH:mm').format(log.createdAt.toLocal());
    final diffText = log.snapshotDiffSummary;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                '${log.itemCode} — ${log.itemDescription}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            Text(timeStr, style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey)),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${log.actionType}${log.statusChanged != null ? ' (${log.statusChanged})' : ''} • Qty: ${log.qtyChanged} • '
                '${log.fromLocationName ?? '-'} → ${log.toLocationName ?? '-'}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
              if (diffText != null) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: HtiColors.navyPrimary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    diffText,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: HtiColors.navyPrimary,
                    ),
                  ),
                ),
              ],
              if (log.note != null && log.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(log.note!, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              ],
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Petugas: ${log.userName ?? 'SYSTEM'}',
                    style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey),
                  ),
                  if (log.jobCode != null)
                    Text(
                      '• Job: ${log.jobCode}',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                  if (log.photoUrl != null)
                    ActionChip(
                      avatar: const Icon(Icons.photo_camera_outlined, size: 15),
                      label: const Text('Lihat Foto K3'),
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => EvidencePhotoLightbox(
                          photoUrl: log.photoUrl!,
                          title: '${log.itemCode} (${log.statusChanged ?? log.actionType})',
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
