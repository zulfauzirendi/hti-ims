import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/media/evidence_image_helper.dart';
import '../../core/models/inventory_models.dart';
import '../../core/models/user_model.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_repository.dart';
import 'inventory_providers.dart';
import 'inventory_repository.dart';

const _uuid = Uuid();
const _allowedUnits = ['UNIT', 'PCS', 'SET', 'ROLL', 'EA', 'PAIR', 'BOX', 'BTL'];

/// Modal Ubah Kondisi Alat + Wajib Foto Bukti K3 ISO 45001 (SRS-CAP-010, SRS-CAP-011)
class ConditionUpdateDialog extends ConsumerStatefulWidget {
  const ConditionUpdateDialog({
    super.key,
    required this.item,
    required this.stock,
  });

  final InventoryItem item;
  final ItemStockEntry stock;

  @override
  ConsumerState<ConditionUpdateDialog> createState() => _ConditionUpdateDialogState();
}

class _ConditionUpdateDialogState extends ConsumerState<ConditionUpdateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();
  late final TextEditingController _jobCodeCtrl;

  late String _fromStatus;
  late String _toStatus;
  PreparedEvidencePhoto? _selectedPhoto;
  String? _uploadedPhotoUrl;
  late final String _idempotencyKey;
  bool _submitting = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = _uuid.v4();
    _jobCodeCtrl = TextEditingController(text: widget.stock.jobCode ?? '');
    if (widget.stock.qtyGood > 0) {
      _fromStatus = 'GOOD';
      _toStatus = 'SERVICE';
    } else if (widget.stock.qtyService > 0) {
      _fromStatus = 'SERVICE';
      _toStatus = 'GOOD';
    } else {
      _fromStatus = 'BROKEN';
      _toStatus = 'GOOD';
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _noteCtrl.dispose();
    _jobCodeCtrl.dispose();
    super.dispose();
  }

  int get _availableForFrom => switch (_fromStatus) {
        'GOOD' => widget.stock.qtyGood,
        'SERVICE' => widget.stock.qtyService,
        'BROKEN' => widget.stock.qtyBroken,
        _ => 0,
      };

  bool get _photoRequired => _toStatus == 'SERVICE' || _toStatus == 'BROKEN';

  Future<void> _pickPhoto({required bool fromCamera}) async {
    setState(() => _errorText = null);
    try {
      final photo = await EvidenceImageHelper.pickEvidencePhoto(fromCamera: fromCamera);
      if (photo != null && mounted) {
        setState(() {
          _selectedPhoto = photo;
          _uploadedPhotoUrl = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorText = e.toString());
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromStatus == _toStatus) {
      setState(() => _errorText = 'Status asal dan tujuan harus berbeda.');
      return;
    }
    if (_photoRequired && _selectedPhoto == null && _uploadedPhotoUrl == null) {
      setState(
        () => _errorText =
            'Wajib melampirkan bukti foto fisik (ISO 45001) untuk mengubah status ke $_toStatus.',
      );
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final repo = ref.read(inventoryRepositoryProvider);
      var photoUrl = _uploadedPhotoUrl;
      if (_selectedPhoto != null && photoUrl == null) {
        photoUrl = await repo.uploadEvidencePhoto(
          bytes: _selectedPhoto!.bytes,
          filename: _selectedPhoto!.filename,
        );
        _uploadedPhotoUrl = photoUrl;
      }

      await repo.updateCondition(
        itemId: widget.item.id,
        locationId: widget.stock.locationId,
        fromStatus: _fromStatus,
        toStatus: _toStatus,
        qty: int.parse(_qtyCtrl.text.trim()),
        note: _noteCtrl.text,
        expectedVersion: widget.stock.version,
        photoUrl: photoUrl,
        jobCode: _jobCodeCtrl.text,
        idempotencyKey: _idempotencyKey,
      );

      ref.invalidate(inventorySearchProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorText = e.message);
    } catch (e) {
      if (mounted) setState(() => _errorText = 'Gagal menyimpan perubahan: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobilePlatform = !kIsWeb && (Platform.isAndroid || Platform.isIOS);

    return AlertDialog(
      title: Text('Ubah Kondisi • ${widget.stock.locationName}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.item.itemCode} — ${widget.item.description}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: HtiColors.navyPrimary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ConditionStatusBadge(status: 'GOOD', count: widget.stock.qtyGood),
                    ConditionStatusBadge(status: 'SERVICE', count: widget.stock.qtyService),
                    ConditionStatusBadge(status: 'BROKEN', count: widget.stock.qtyBroken),
                  ],
                ),
                const SizedBox(height: 14),
                if (_errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HtiColors.statusBroken.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HtiColors.statusBroken.withValues(alpha: 0.4)),
                    ),
                    child: Text(_errorText!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _fromStatus,
                        decoration: const InputDecoration(labelText: 'Dari Status'),
                        items: const [
                          DropdownMenuItem(value: 'GOOD', child: Text('GOOD')),
                          DropdownMenuItem(value: 'SERVICE', child: Text('SERVICE')),
                          DropdownMenuItem(value: 'BROKEN', child: Text('BROKEN')),
                        ],
                        onChanged: _submitting ? null : (v) => setState(() => _fromStatus = v!),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward),
                    ),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _toStatus,
                        decoration: const InputDecoration(labelText: 'Ke Status'),
                        items: const [
                          DropdownMenuItem(value: 'GOOD', child: Text('GOOD')),
                          DropdownMenuItem(value: 'SERVICE', child: Text('SERVICE')),
                          DropdownMenuItem(value: 'BROKEN', child: Text('BROKEN')),
                        ],
                        onChanged: _submitting ? null : (v) => setState(() => _toStatus = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jumlah (${widget.item.unit})',
                    helperText: 'Tersedia di status $_fromStatus: $_availableForFrom ${widget.item.unit}',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1) return 'Minimal 1 unit.';
                    if (n > _availableForFrom) return 'Melebihi saldo tersedia ($_availableForFrom).';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _jobCodeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Job Code Proyek (Opsional)',
                    hintText: 'Contoh: 1P-31-180',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Kondisi / Kerusakan (Wajib)',
                    hintText: 'Jelaskan detail kerusakan atau hasil servis (min. 5 karakter)',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 5) ? 'Catatan minimal 5 karakter.' : null,
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _photoRequired
                        ? HtiColors.statusService.withValues(alpha: 0.08)
                        : HtiColors.slateBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _photoRequired ? HtiColors.statusService : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _photoRequired
                            ? 'Bukti Foto K3 ISO 45001 (WAJIB untuk $_toStatus)'
                            : 'Bukti Foto K3 (Opsional)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: _photoRequired ? HtiColors.statusService : HtiColors.navyPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_selectedPhoto != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _selectedPhoto!.bytes,
                            height: 140,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${_selectedPhoto!.filename} (${(_selectedPhoto!.sizeBytes / 1024).toStringAsFixed(0)} KB • EXIF dibersihkan)',
                          style: const TextStyle(fontSize: 11.5, color: Colors.blueGrey),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (isMobilePlatform)
                            OutlinedButton.icon(
                              onPressed: _submitting ? null : () => _pickPhoto(fromCamera: true),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Kamera'),
                            ),
                          OutlinedButton.icon(
                            onPressed: _submitting ? null : () => _pickPhoto(fromCamera: false),
                            icon: const Icon(Icons.photo_library_outlined),
                            label: Text(isMobilePlatform ? 'Galeri' : 'Pilih Foto'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Menyimpan...' : 'Simpan Perubahan'),
        ),
      ],
    );
  }
}

/// Modal Buat Transfer 2 Tahap (IN_TRANSIT) dengan Peringatan K3 (SRS-SAF-003)
class CreateTransferDialog extends ConsumerStatefulWidget {
  const CreateTransferDialog({
    super.key,
    required this.item,
    required this.sourceStock,
    required this.allLocations,
  });

  final InventoryItem item;
  final ItemStockEntry sourceStock;
  final List<LocationRef> allLocations;

  @override
  ConsumerState<CreateTransferDialog> createState() => _CreateTransferDialogState();
}

class _CreateTransferDialogState extends ConsumerState<CreateTransferDialog> {
  final _formKey = GlobalKey<FormState>();
  final _qtyCtrl = TextEditingController(text: '1');
  final _jobCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  late final String _idempotencyKey;

  int? _toLocationId;
  String _condition = 'GOOD';
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _idempotencyKey = _uuid.v4();
    final others = widget.allLocations.where((l) => l.id != widget.sourceStock.locationId).toList();
    if (others.isNotEmpty) _toLocationId = others.first.id;
    if (widget.sourceStock.qtyGood == 0 && widget.sourceStock.qtyService > 0) {
      _condition = 'SERVICE';
    } else if (widget.sourceStock.qtyGood == 0 && widget.sourceStock.qtyBroken > 0) {
      _condition = 'BROKEN';
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _jobCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int get _available => switch (_condition) {
        'GOOD' => widget.sourceStock.qtyGood,
        'SERVICE' => widget.sourceStock.qtyService,
        'BROKEN' => widget.sourceStock.qtyBroken,
        _ => 0,
      };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _toLocationId == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(inventoryRepositoryProvider).createTransfer(
            itemId: widget.item.id,
            fromLocationId: widget.sourceStock.locationId,
            toLocationId: _toLocationId!,
            conditionStatus: _condition,
            qty: int.parse(_qtyCtrl.text.trim()),
            senderNote: _noteCtrl.text,
            jobCode: _jobCtrl.text,
            expectedVersion: widget.sourceStock.version,
            idempotencyKey: _idempotencyKey,
          );
      ref.invalidate(inventorySearchProvider);
      ref.invalidate(dashboardSummaryProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal membuat transfer: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetLocs = widget.allLocations.where((l) => l.id != widget.sourceStock.locationId).toList();
    final isUnsafeCondition = _condition == 'BROKEN' || _condition == 'SERVICE';

    return AlertDialog(
      title: Text('Kirim Transfer dari ${widget.sourceStock.locationName}'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${widget.item.itemCode} — ${widget.item.description}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: HtiColors.navyPrimary),
                ),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<int>(
                  initialValue: _toLocationId,
                  decoration: const InputDecoration(labelText: 'Lokasi Tujuan'),
                  items: [
                    for (final loc in targetLocs)
                      DropdownMenuItem(value: loc.id, child: Text('${loc.name} (${loc.code})')),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _toLocationId = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _condition,
                  decoration: const InputDecoration(labelText: 'Kondisi Barang Dikirim'),
                  items: const [
                    DropdownMenuItem(value: 'GOOD', child: Text('GOOD')),
                    DropdownMenuItem(value: 'SERVICE', child: Text('SERVICE')),
                    DropdownMenuItem(value: 'BROKEN', child: Text('BROKEN')),
                  ],
                  onChanged: _submitting ? null : (v) => setState(() => _condition = v!),
                ),
                if (isUnsafeCondition) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: HtiColors.statusBroken.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: HtiColors.statusBroken),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: HtiColors.statusBroken),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PERINGATAN K3: Barang yang dikirim berstatus TIDAK LAYAK OPERASI (hanya untuk perbaikan/karantina).',
                            style: TextStyle(
                              color: HtiColors.statusBroken,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jumlah (${widget.item.unit})',
                    helperText: 'Tersedia $_condition di asal: $_available',
                  ),
                  validator: (v) {
                    final n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n < 1) return 'Minimal 1 unit.';
                    if (n > _available) return 'Melebihi saldo tersedia ($_available).';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _jobCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Job Code Proyek (Opsional)',
                    hintText: 'Contoh: 1P-31-180',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Catatan Pengiriman (Wajib)',
                    hintText: 'Nama kurir / keperluan proyek',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().length < 3) ? 'Catatan minimal 3 karakter.' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _submit,
          child: Text(_submitting ? 'Mengirim...' : 'Kirim (Status IN_TRANSIT)'),
        ),
      ],
    );
  }
}

/// Modal Update Job Code & Remarks Lokasi
Future<bool?> showRemarksModal(
  BuildContext context,
  WidgetRef ref,
  InventoryItem item,
  ItemStockEntry stock,
) {
  final jobCtrl = TextEditingController(text: stock.jobCode ?? '');
  final remCtrl = TextEditingController(text: stock.remarks ?? '');
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      var busy = false;
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Job Code & Remarks • ${stock.locationName}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: jobCtrl,
                  decoration: const InputDecoration(labelText: 'Job Code', hintText: '1P-31-180'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: remCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Remarks / Lokasi Detail'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref.read(inventoryRepositoryProvider).updateRemarks(
                              itemId: item.id,
                              locationId: stock.locationId,
                              expectedVersion: stock.version,
                              jobCode: jobCtrl.text,
                              remarks: remCtrl.text,
                            );
                        ref.invalidate(inventorySearchProvider);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() {
                          busy = false;
                          error = e.toString();
                        });
                      }
                    },
              child: Text(busy ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      );
    },
  );
}

/// Modal Stock In (Pengadaan) — SUPER_ADMIN & ADMIN_GUDANG
Future<bool?> showStockInModal(
  BuildContext context,
  WidgetRef ref,
  InventoryItem item,
  ItemStockEntry stock,
) {
  final qtyCtrl = TextEditingController(text: '1');
  final noteCtrl = TextEditingController();
  final key = _uuid.v4();
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      var busy = false;
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Stock In (Pengadaan) • ${stock.locationName}'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${item.itemCode} — ${item.description}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'Jumlah Tambah GOOD (${item.unit})'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Referensi PO / Catatan Pengadaan (Min. 5 karakter)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      if (qty < 1 || noteCtrl.text.trim().length < 5) {
                        setState(() => error = 'Jumlah minimal 1 dan catatan minimal 5 karakter.');
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref.read(inventoryRepositoryProvider).stockIn(
                              itemId: item.id,
                              locationId: stock.locationId,
                              qty: qty,
                              note: noteCtrl.text,
                              expectedVersion: stock.stockId != null ? stock.version : null,
                              idempotencyKey: key,
                            );
                        ref.invalidate(inventorySearchProvider);
                        ref.invalidate(dashboardSummaryProvider);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() {
                          busy = false;
                          error = e.toString();
                        });
                      }
                    },
              child: Text(busy ? 'Menyimpan...' : 'Tambah Stok'),
            ),
          ],
        ),
      );
    },
  );
}

/// Modal Disposal / Write-Off Broken (SUPER_ADMIN) dengan Konfirmasi 2 Langkah (SRS-SAF-004)
Future<bool?> showDisposalModal(
  BuildContext context,
  WidgetRef ref,
  InventoryItem item,
  ItemStockEntry stock,
) {
  final qtyCtrl = TextEditingController(text: '1');
  final noteCtrl = TextEditingController();
  final key = _uuid.v4();
  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      var busy = false;
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Disposal / Write-Off Aset Rusak (ISO)'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('${item.itemCode} — ${item.description}', style: const TextStyle(fontWeight: FontWeight.bold)),
                Text('Saldo BROKEN di ${stock.locationName}: ${stock.qtyBroken} ${item.unit}'),
                const SizedBox(height: 12),
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                  const SizedBox(height: 8),
                ],
                TextField(
                  controller: qtyCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Jumlah Hapus Permanen (BROKEN)'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nomor Berita Acara / Alasan Disposal (Min. 10 karakter)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: HtiColors.statusBroken),
              onPressed: busy
                  ? null
                  : () async {
                      final qty = int.tryParse(qtyCtrl.text.trim()) ?? 0;
                      if (qty < 1 || qty > stock.qtyBroken || noteCtrl.text.trim().length < 10) {
                        setState(() => error = 'Periksa jumlah (1..${stock.qtyBroken}) dan alasan min. 10 karakter.');
                        return;
                      }
                      final confirm = await showDialog<bool>(
                        context: ctx,
                        builder: (c2) => AlertDialog(
                          title: const Text('Konfirmasi Penghapusan Permanen'),
                          content: Text(
                            'Hapus permanen $qty ${item.unit} BROKEN dari ${item.itemCode} di ${stock.locationName}? Aksi ini dicatat permanen di Audit Trail ISO 9001.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c2, false), child: const Text('Batal')),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: HtiColors.statusBroken),
                              onPressed: () => Navigator.pop(c2, true),
                              child: const Text('Ya, Eksekusi Disposal'),
                            ),
                          ],
                        ),
                      );
                      if (confirm != true) return;
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref.read(inventoryRepositoryProvider).disposeBroken(
                              itemId: item.id,
                              locationId: stock.locationId,
                              qty: qty,
                              note: noteCtrl.text,
                              expectedVersion: stock.version,
                              idempotencyKey: key,
                            );
                        ref.invalidate(inventorySearchProvider);
                        ref.invalidate(dashboardSummaryProvider);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() {
                          busy = false;
                          error = e.toString();
                        });
                      }
                    },
              child: Text(busy ? 'Memproses...' : 'Eksekusi Disposal'),
            ),
          ],
        ),
      );
    },
  );
}

/// Modal Tambah Master Item Baru (Khusus SUPER_ADMIN)
Future<bool?> showCreateItemModal(
  BuildContext context,
  WidgetRef ref,
  List<CategoryRef> categories,
) {
  final descCtrl = TextEditingController();
  final specCtrl = TextEditingController();
  int? catId = categories.isNotEmpty ? categories.first.id : null;
  String unit = 'UNIT';

  return showDialog<bool>(
    context: context,
    builder: (ctx) {
      var busy = false;
      String? error;
      return StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Tambah Master Item Baru'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null) ...[
                  Text(error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                  const SizedBox(height: 8),
                ],
                DropdownButtonFormField<int>(
                  initialValue: catId,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: [
                    for (final c in categories)
                      DropdownMenuItem(value: c.id, child: Text('${c.code} — ${c.name}')),
                  ],
                  onChanged: (v) => setState(() => catId = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: 'Deskripsi / Nama Alat'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: specCtrl,
                  decoration: const InputDecoration(labelText: 'Spesifikasi / Merk (Opsional)'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: unit,
                  decoration: const InputDecoration(labelText: 'Satuan Standar'),
                  items: [for (final u in _allowedUnits) DropdownMenuItem(value: u, child: Text(u))],
                  onChanged: (v) => setState(() => unit = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: busy ? null : () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (catId == null || descCtrl.text.trim().length < 2) {
                        setState(() => error = 'Kategori dan deskripsi minimal 2 karakter.');
                        return;
                      }
                      setState(() {
                        busy = true;
                        error = null;
                      });
                      try {
                        await ref.read(inventoryRepositoryProvider).createMasterItem(
                              categoryId: catId!,
                              description: descCtrl.text,
                              specification: specCtrl.text,
                              unit: unit,
                            );
                        ref.invalidate(inventorySearchProvider);
                        ref.invalidate(dashboardSummaryProvider);
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } catch (e) {
                        setState(() {
                          busy = false;
                          error = e.toString();
                        });
                      }
                    },
              child: Text(busy ? 'Menyimpan...' : 'Buat Item (Auto-SKU)'),
            ),
          ],
        ),
      );
    },
  );
}
