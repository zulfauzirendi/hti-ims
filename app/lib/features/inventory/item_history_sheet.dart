import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/inventory_models.dart';
import '../../core/theme/app_theme.dart';
import '../logs/evidence_photo_lightbox.dart';
import 'inventory_repository.dart';

/// Dialog Detail & 10 Riwayat Audit Terakhir per Item (GET /api/v1/items/:id)
class ItemHistoryDialog extends ConsumerWidget {
  const ItemHistoryDialog({super.key, required this.item});

  final InventoryItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 600),
        child: Column(
          children: [
            Container(
              color: HtiColors.navyPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.history_rounded, color: HtiColors.amberAccent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.itemCode} — ${item.description}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        Text(
                          '10 Riwayat Mutasi & Kondisi Terakhir (ISO 9001 / ISO 45001)',
                          style: const TextStyle(color: Colors.white70, fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<ItemDetailResult>(
                future: ref.read(inventoryRepositoryProvider).fetchItemDetail(item.id),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Gagal memuat riwayat item: ${snap.error}',
                          style: const TextStyle(color: HtiColors.statusBroken),
                        ),
                      ),
                    );
                  }
                  final logs = snap.data?.recentLogs ?? const [];
                  if (logs.isEmpty) {
                    return const Center(child: Text('Belum ada riwayat transaksi untuk item ini.'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(14),
                    itemCount: logs.length,
                    separatorBuilder: (_, _) => const Divider(height: 12),
                    itemBuilder: (_, idx) {
                      final log = logs[idx];
                      final timeStr = DateFormat('dd MMM yyyy HH:mm').format(log.createdAt.toLocal());
                      final diff = log.snapshotDiffSummary;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${log.actionType}${log.statusChanged != null ? ' (${log.statusChanged})' : ''}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: HtiColors.navyPrimary,
                                ),
                              ),
                              const Spacer(),
                              Text(timeStr, style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Qty: ${log.qtyChanged} • ${log.fromLocationName ?? '-'} → ${log.toLocationName ?? '-'} • Petugas: ${log.userName ?? 'SYSTEM'}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          if (diff != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              diff,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: HtiColors.navySurface,
                              ),
                            ),
                          ],
                          if (log.note != null && log.note!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(log.note!, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
                          ],
                          if (log.photoUrl != null) ...[
                            const SizedBox(height: 6),
                            ActionChip(
                              avatar: const Icon(Icons.photo_camera_outlined, size: 15),
                              label: const Text('Lihat Foto Bukti K3'),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => EvidencePhotoLightbox(
                                  photoUrl: log.photoUrl!,
                                  title: '${item.itemCode} ($timeStr)',
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
