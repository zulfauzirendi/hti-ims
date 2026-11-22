import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

/// Layar wajib ganti kata sandi saat login pertama / pasca reset admin (SRS-SEC-012)
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
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

  String? _validateNewPassword(String? v) {
    if (v == null || v.length < 8) return 'Minimal 8 karakter.';
    if (!RegExp(r'[A-Z]').hasMatch(v)) return 'Wajib mengandung minimal 1 huruf besar.';
    if (!RegExp(r'[a-z]').hasMatch(v)) return 'Wajib mengandung minimal 1 huruf kecil.';
    if (!RegExp(r'[0-9]').hasMatch(v)) return 'Wajib mengandung minimal 1 angka.';
    return null;
  }

  Future<void> _submit() async {
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
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memperbarui kata sandi: $e');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wajib Ganti Kata Sandi'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout, color: Colors.white),
            label: const Text('Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Halo, ${user?.fullName ?? "Pengguna"}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Demi keamanan akun (OWASP/ISO), Anda wajib mengganti kata sandi awal sebelum mengakses sistem inventaris.',
                        style: TextStyle(fontSize: 13, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 16),
                      if (_error != null) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: HtiColors.statusBroken.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(_error!, style: const TextStyle(color: HtiColors.statusBroken)),
                        ),
                        const SizedBox(height: 14),
                      ],
                      TextFormField(
                        controller: _currentCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Kata Sandi Saat Ini'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi.' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _newCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Kata Sandi Baru',
                          helperText: 'Min. 8 karakter, huruf besar, huruf kecil, dan angka',
                        ),
                        validator: _validateNewPassword,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Konfirmasi Kata Sandi Baru'),
                        validator: (v) => v != _newCtrl.text ? 'Konfirmasi kata sandi tidak cocok.' : null,
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: Text(_submitting ? 'Memperbarui...' : 'Simpan Kata Sandi Baru'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
