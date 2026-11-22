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
      final locId = ref.read(logLocationFilterProvider);
      final savedPath = await ref
          .read(logsRepositoryProvider)
          .downloadAndSaveReport(type: type, format: format, locationId: locId);
      if (mounted && savedPath != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Laporan berhasil disimpan: $savedPath')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor laporan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(auditLogsProvider);
    final actionFilter = ref.watch(logActionFilterProvider);
    final locFilter = ref.watch(logLocationFilterProvider);
    final locations = ref.watch(locationsProvider).valueOrNull ?? const <LocationRef>[];

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
                          'Jejak mutasi permanen (append-only) lengkap dengan bukti foto K3 & ekspor Excel/PDF.',
                          style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    enabled: !_exporting,
                    onSelected: (choice) {
                      final parts = choice.split(':');
                      _export(parts[0], parts[1]);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'stock:xlsx', child: Text('Export Stok → Excel (.xlsx)')),
                      PopupMenuItem(value: 'stock:pdf', child: Text('Export Stok → PDF Resmi PT HTI')),
                      PopupMenuDivider(),
                      PopupMenuItem(value: 'logs:xlsx', child: Text('Export Audit Log → Excel (.xlsx)')),
                      PopupMenuItem(value: 'logs:pdf', child: Text('Export Audit Log → PDF ISO 9001')),
                    ],
                    child: ElevatedButton.icon(
                      onPressed: null,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.download_outlined),
                      label: Text(_exporting ? 'Mengekspor...' : 'Export Excel / PDF'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  DropdownButton<String?>(
                    value: actionFilter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('Semua Aksi')),
                      DropdownMenuItem(value: 'STATUS_CHANGE', child: Text('Perubahan Kondisi')),
                      DropdownMenuItem(value: 'TRANSFER_OUT', child: Text('Transfer Keluar')),
                      DropdownMenuItem(value: 'TRANSFER_IN', child: Text('Transfer Masuk')),
                      DropdownMenuItem(value: 'TRANSFER_REJECT', child: Text('Transfer Ditolak')),
                      DropdownMenuItem(value: 'STOCK_IN', child: Text('Stock In (Pengadaan)')),
                      DropdownMenuItem(value: 'DISPOSAL', child: Text('Disposal / Write-Off')),
                      DropdownMenuItem(value: 'REMARKS_UPDATE', child: Text('Update Remarks/Job')),
                      DropdownMenuItem(value: 'INITIAL_IMPORT', child: Text('Baseline Import Nov 25')),
                    ],
                    onChanged: (v) => ref.read(logActionFilterProvider.notifier).state = v,
                  ),
                  DropdownButton<int?>(
                    value: locFilter,
                    underline: const SizedBox.shrink(),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Semua Lokasi')),
                      for (final l in locations) DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) => ref.read(logLocationFilterProvider.notifier).state = v,
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
              child: Text(err.toString(), style: const TextStyle(color: HtiColors.statusBroken)),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return const Center(child: Text('Belum ada catatan audit log pada filter ini.'));
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(auditLogsProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: logs.length,
                  itemBuilder: (_, idx) {
                    final log = logs[idx];
                    final timeStr = DateFormat('dd MMM yyyy HH:mm').format(log.createdAt.toLocal());
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
                              if (log.note != null && log.note!.isNotEmpty)
                                Text(log.note!, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
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
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
