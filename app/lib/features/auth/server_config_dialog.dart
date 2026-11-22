import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/server_config_storage.dart';
import '../../core/models/inventory_models.dart';
import '../../core/theme/app_theme.dart';

/// Dialog konfigurasi Server Base URL (Hybrid On-Premise LAN <-> Cloud VPS — SRS-EIF-007)
class ServerConfigDialog extends ConsumerStatefulWidget {
  const ServerConfigDialog({super.key});

  @override
  ConsumerState<ServerConfigDialog> createState() => _ServerConfigDialogState();
}

class _ServerConfigDialogState extends ConsumerState<ServerConfigDialog> {
  late final TextEditingController _urlController;
  bool _testing = false;
  bool _saving = false;
  HealthCheckResult? _healthResult;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    final current = ref.read(serverConfigProvider).valueOrNull ?? defaultServerBaseUrl;
    _urlController = TextEditingController(text: current);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _healthResult = null;
      _errorText = null;
    });
    final res = await ref.read(serverConfigProvider.notifier).testConnection(_urlController.text);
    if (!mounted) return;
    setState(() {
      _testing = false;
      _healthResult = res;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await ref.read(serverConfigProvider.notifier).setServerUrl(_urlController.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _errorText = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.dns_outlined, color: HtiColors.navyPrimary),
          SizedBox(width: 8),
          Text('Pengaturan Server PT HTI'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan alamat server Backend API (Cloud VPS atau LAN On-Premise PT HTI):',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: 'Server Base URL',
                hintText: 'https://inv.hti.co.id atau http://192.168.1.50:3000',
                errorText: _errorText,
                prefixIcon: const Icon(Icons.link),
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _testing ? null : _testConnection,
                icon: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.network_check),
                label: Text(_testing ? 'Menguji koneksi...' : 'Uji Koneksi (/api/v1/health)'),
              ),
            ),
            if (_healthResult != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (_healthResult!.ok ? HtiColors.statusGood : HtiColors.statusBroken)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _healthResult!.ok ? HtiColors.statusGood : HtiColors.statusBroken,
                  ),
                ),
                child: Text(
                  _healthResult!.message,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _healthResult!.ok ? HtiColors.statusGood : HtiColors.statusBroken,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Menyimpan...' : 'Simpan URL'),
        ),
      ],
    );
  }
}
