import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../auth/auth_controller.dart';
import '../dashboard/dashboard_repository.dart';
import '../inventory/inventory_providers.dart';
import 'transfers_repository.dart';

class TransfersScreen extends ConsumerWidget {
  const TransfersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    final direction = ref.watch(transferDirectionProvider);
    final statusFilter = ref.watch(transferStatusFilterProvider);
    final transfersAsync = ref.watch(transfersListProvider);

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Transfer Antar Lokasi (2 Tahap)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HtiColors.navyPrimary),
                  ),
                  IconButton.filledTonal(
                    tooltip: 'Segarkan',
                    onPressed: () => ref.invalidate(transfersListProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('Masuk (Incoming)'),
                    selected: direction == 'incoming',
                    onSelected: (_) => ref.read(transferDirectionProvider.notifier).state = 'incoming',
                  ),
                  ChoiceChip(
                    label: const Text('Keluar (Outgoing)'),
                    selected: direction == 'outgoing',
                    onSelected: (_) => ref.read(transferDirectionProvider.notifier).state = 'outgoing',
                  ),
                  ChoiceChip(
                    label: const Text('Semua'),
                    selected: direction == 'all',
                    onSelected: (_) => ref.read(transferDirectionProvider.notifier).state = 'all',
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<String?>(
                    value: statusFilter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'IN_TRANSIT', child: Text('Status: IN_TRANSIT')),
                      DropdownMenuItem(value: 'RECEIVED', child: Text('Status: RECEIVED')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('Status: REJECTED')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Status: CANCELLED')),
                      DropdownMenuItem(value: null, child: Text('Semua Status')),
                    ],
                    onChanged: (v) => ref.read(transferStatusFilterProvider.notifier).state = v,
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: transfersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(err.toString(), style: const TextStyle(color: HtiColors.statusBroken)),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(transfersListProvider),
                    child: const Text('Muat Ulang'),
                  ),
                ],
              ),
            ),
            data: (items) {
              if (items.isEmpty) {
                return const Center(
                  child: Text('Tidak ada transaksi transfer pada filter ini.'),
                );
              }
              return RefreshIndicator(
                onRefresh: () => ref.refresh(transfersListProvider.future),
                child: ListView.builder(
                  padding: const EdgeInsets.all(14),
                  itemCount: items.length,
                  itemBuilder: (_, idx) => _TransferCard(transfer: items[idx], user: user),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TransferCard extends ConsumerStatefulWidget {
  const _TransferCard({required this.transfer, required this.user});

  final StockTransferItem transfer;
  final UserProfile? user;

  @override
  ConsumerState<_TransferCard> createState() => _TransferCardState();
}

class _TransferCardState extends ConsumerState<_TransferCard> {
  bool _busy = false;

  void _refreshAll() {
    ref.invalidate(transfersListProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(inventorySearchProvider);
  }

  Future<void> _handleReceive() async {
    final transfer = widget.transfer;
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi Terima • ${transfer.transferCode}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${transfer.qty} ${transfer.itemUnit} ${transfer.itemDescription} (${transfer.conditionStatus})'),
            Text('Dari ${transfer.fromLocationName} → ${transfer.toLocationName}'),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Catatan Penerimaan (Opsional)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HtiColors.statusGood),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Konfirmasi Terima'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(transfersRepositoryProvider).receive(transfer.id, receiverNote: noteCtrl.text);
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: HtiColors.statusGood,
            content: Text('Transfer ${transfer.transferCode} berhasil diterima.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: HtiColors.statusBroken, content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleReject() async {
    final transfer = widget.transfer;
    final noteCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tolak Transfer • ${transfer.transferCode}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stok akan dikembalikan otomatis ke lokasi asal. Masukkan alasan penolakan (min. 5 karakter):'),
            const SizedBox(height: 10),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Alasan Penolakan (Wajib)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HtiColors.statusBroken),
            onPressed: () {
              if (noteCtrl.text.trim().length >= 5) Navigator.pop(ctx, true);
            },
            child: const Text('Tolak & Kembalikan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(transfersRepositoryProvider).reject(transfer.id, receiverNote: noteCtrl.text);
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Transfer ${transfer.transferCode} ditolak dan dikembalikan ke asal.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: HtiColors.statusBroken, content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleCancel() async {
    final transfer = widget.transfer;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Batalkan Pengiriman • ${transfer.transferCode}'),
        content: Text(
          'Batalkan transfer ${transfer.qty} ${transfer.itemUnit} ${transfer.itemDescription} dan kembalikan saldo ke ${transfer.fromLocationName}?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tidak')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HtiColors.statusBroken),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(transfersRepositoryProvider).cancel(transfer.id);
      _refreshAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pengiriman ${transfer.transferCode} berhasil dibatalkan.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: HtiColors.statusBroken, content: Text('Gagal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final transfer = widget.transfer;
    final user = widget.user;
    final isInTransit = transfer.status == 'IN_TRANSIT';
    final isUnsafeGear = transfer.conditionStatus == 'BROKEN' || transfer.conditionStatus == 'SERVICE';
    final canReceiveOrReject =
        isInTransit && (user?.canWriteLocation(transfer.toLocationId, allowFieldTech: true) ?? false);
    final canCancel =
        isInTransit && (user?.canWriteLocation(transfer.fromLocationId, allowFieldTech: true) ?? false);
    final timeStr = DateFormat('dd MMM yyyy HH:mm').format(transfer.sentAt.toLocal());

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  transfer.transferCode,
                  style: const TextStyle(fontWeight: FontWeight.w800, color: HtiColors.navyPrimary),
                ),
                const SizedBox(width: 8),
                ConditionStatusBadge(status: transfer.status),
                const Spacer(),
                Text(timeStr, style: const TextStyle(fontSize: 12, color: Colors.blueGrey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${transfer.itemCode} — ${transfer.itemDescription}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            if (isUnsafeGear && isInTransit) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: HtiColors.statusBroken.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 15, color: HtiColors.statusBroken),
                    SizedBox(width: 5),
                    Text(
                      'PERINGATAN K3: Alat Tidak Layak Operasi (Servis/Karantina)',
                      style: TextStyle(color: HtiColors.statusBroken, fontSize: 11.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Chip(
                  avatar: const Icon(Icons.route, size: 16),
                  label: Text('${transfer.fromLocationName} → ${transfer.toLocationName}'),
                ),
                ConditionStatusBadge(status: transfer.conditionStatus, count: transfer.qty),
                if (transfer.jobCode != null) Chip(label: Text('Job: ${transfer.jobCode}')),
              ],
            ),
            if (transfer.senderNote != null) ...[
              const SizedBox(height: 6),
              Text(
                'Pengirim (${transfer.sentByName}): ${transfer.senderNote}',
                style: const TextStyle(fontSize: 12.5, color: Colors.blueGrey),
              ),
            ],
            if (transfer.receiverNote != null) ...[
              const SizedBox(height: 4),
              Text(
                'Penerima (${transfer.receivedByName ?? '-'}): ${transfer.receiverNote}',
                style: const TextStyle(fontSize: 12.5, color: Colors.blueGrey),
              ),
            ],
            if (canReceiveOrReject || canCancel) ...[
              const SizedBox(height: 12),
              if (_busy)
                const LinearProgressIndicator()
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    if (canReceiveOrReject)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: HtiColors.statusGood),
                        onPressed: _handleReceive,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Konfirmasi Terima'),
                      ),
                    if (canReceiveOrReject)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: HtiColors.statusBroken),
                        onPressed: _handleReject,
                        icon: const Icon(Icons.cancel_outlined),
                        label: const Text('Tolak'),
                      ),
                    if (canCancel)
                      OutlinedButton.icon(
                        onPressed: _handleCancel,
                        icon: const Icon(Icons.undo),
                        label: const Text('Batalkan Pengiriman'),
                      ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
