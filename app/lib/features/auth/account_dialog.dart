import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/server_config_storage.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';
import 'server_config_dialog.dart';

/// Dialog Profil Akun, Ganti Kata Sandi Sukarela & Pengaturan Server (Desktop & Android)
class AccountProfileDialog extends ConsumerStatefulWidget {
  const AccountProfileDialog({super.key});

  @override
  ConsumerState<AccountProfileDialog> createState() => _AccountProfileDialogState();
}

class _AccountProfileDialogState extends ConsumerState<AccountProfileDialog> {
  bool _showPasswordForm = false;
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? _validatePassword(String? v) {
    if (v == null || v.length < 8) return 'Minimal 8 karakter.';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Wajib mengandung huruf besar.';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Wajib mengandung huruf kecil.';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Wajib mengandung angka.';
    return null;
  }

  Future<void> _submitPasswordChange() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _currentCtrl.text,
            newPassword: _newCtrl.text,
          );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal mengganti kata sandi: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final serverUrl = ref.watch(serverConfigProvider).valueOrNull ?? defaultServerBaseUrl;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.account_circle_outlined, color: HtiColors.navyPrimary),
          SizedBox(width: 8),
          Text('Profil & Keamanan Akun'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (user != null) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: HtiColors.navyPrimary,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '@${user.username} • ${user.role.displayLabel}\n'
                    'Lokasi Tugas: ${user.assignedLocation?.name ?? 'Semua Lokasi (Global)'}',
                  ),
                ),
                const Divider(),
              ],
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dns_outlined, color: HtiColors.navyPrimary),
                title: const Text('Server Backend API', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: Text(serverUrl, style: const TextStyle(fontSize: 12)),
                trailing: TextButton(
                  onPressed: () => showDialog<bool>(
                    context: context,
                    builder: (_) => const ServerConfigDialog(),
                  ),
                  child: const Text('Ubah'),
                ),
              ),
              const SizedBox(height: 8),
              if (!_showPasswordForm)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _showPasswordForm = true),
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Ganti Kata Sandi'),
                )
              else
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Ganti Kata Sandi Akun',
                        style: TextStyle(fontWeight: FontWeight.bold, color: HtiColors.navyPrimary),
                      ),
                      const SizedBox(height: 8),
                      if (_error != null) ...[
                        Text(_error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                        const SizedBox(height: 8),
                      ],
                      TextFormField(
                        controller: _currentCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Kata Sandi Saat Ini'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi.' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _newCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Kata Sandi Baru',
                          helperText: 'Min. 8 karakter, huruf besar, kecil & angka',
                        ),
                        validator: _validatePassword,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Konfirmasi Kata Sandi Baru'),
                        validator: (v) => v != _newCtrl.text ? 'Konfirmasi tidak cocok.' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _submitting ? null : () => setState(() => _showPasswordForm = false),
                            child: const Text('Batal'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: _submitting ? null : _submitPasswordChange,
                            child: Text(_submitting ? 'Menyimpan...' : 'Simpan Sandi'),
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
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Tutup'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(backgroundColor: HtiColors.statusBroken),
          onPressed: () {
            Navigator.of(context).pop();
            ref.read(authControllerProvider.notifier).logout();
          },
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Keluar'),
        ),
      ],
    );
  }
}
