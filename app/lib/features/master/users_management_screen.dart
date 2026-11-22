import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../inventory/inventory_providers.dart';
import 'users_repository.dart';

class UsersManagementScreen extends ConsumerWidget {
  const UsersManagementScreen({super.key});

  Future<void> _showCreateUserDialog(
    BuildContext context,
    WidgetRef ref,
    List<LocationRef> locations,
  ) async {
    final userCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    var role = UserRole.petugasLapangan;
    int? locId = locations.isNotEmpty ? locations.first.id : null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var busy = false;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) {
            final needsLocation = role == UserRole.adminGudang || role == UserRole.petugasLapangan;
            return AlertDialog(
              title: const Text('Tambah Pengguna Baru (RBAC)'),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (error != null) ...[
                        Text(error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                        const SizedBox(height: 8),
                      ],
                      TextField(
                        controller: userCtrl,
                        decoration: const InputDecoration(labelText: 'Username'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Nama Lengkap'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: passCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Kata Sandi Awal (Wajib diganti saat login)',
                          helperText: 'Min. 8 karakter, huruf besar, huruf kecil & angka',
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<UserRole>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Peran (Role)'),
                        items: [
                          for (final r in UserRole.values)
                            DropdownMenuItem(value: r, child: Text(r.displayLabel)),
                        ],
                        onChanged: (v) => setState(() => role = v!),
                      ),
                      if (needsLocation) ...[
                        const SizedBox(height: 10),
                        DropdownButtonFormField<int>(
                          initialValue: locId,
                          decoration: const InputDecoration(labelText: 'Lokasi Penugasan (Write Local)'),
                          items: [
                            for (final l in locations)
                              DropdownMenuItem(value: l.id, child: Text('${l.name} (${l.code})')),
                          ],
                          onChanged: (v) => setState(() => locId = v),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: busy ? null : () => Navigator.pop(ctx), child: const Text('Batal')),
                ElevatedButton(
                  onPressed: busy
                      ? null
                      : () async {
                          setState(() {
                            busy = true;
                            error = null;
                          });
                          try {
                            await ref.read(usersRepositoryProvider).createUser(
                                  username: userCtrl.text,
                                  fullName: nameCtrl.text,
                                  password: passCtrl.text,
                                  role: role,
                                  assignedLocationId: needsLocation ? locId : null,
                                );
                            ref.invalidate(managedUsersProvider);
                            if (ctx.mounted) Navigator.pop(ctx);
                          } catch (e) {
                            setState(() {
                              busy = false;
                              error = e.toString();
                            });
                          }
                        },
                  child: Text(busy ? 'Menyimpan...' : 'Buat Akun'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmRevokeSessions(
    BuildContext context,
    WidgetRef ref,
    ManagedUserRecord target,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remote Force-Logout (Cabut Semua Sesi)'),
        content: Text(
          'Cabut seluruh sesi perangkat aktif milik ${target.fullName} (@${target.username})? '
          'Gunakan fitur ini bila HP lapangan hilang/dicuri (SRS-SEC-011).',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: HtiColors.statusBroken),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cabut Semua Sesi'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final count = await ref.read(usersRepositoryProvider).revokeAllSessions(target.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count sesi aktif milik @${target.username} telah dicabut.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    }
  }

  Future<void> _confirmToggleActive(
    BuildContext context,
    WidgetRef ref,
    ManagedUserRecord target,
  ) async {
    final nextActive = !target.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(nextActive ? 'Aktifkan Akun' : 'Nonaktifkan Akun'),
        content: Text(
          '${nextActive ? 'Aktifkan kembali' : 'Nonaktifkan dan keluarkan'} akun ${target.fullName} (@${target.username})?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: nextActive ? HtiColors.statusGood : HtiColors.statusBroken,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(nextActive ? 'Aktifkan' : 'Nonaktifkan'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(usersRepositoryProvider).updateUser(target.id, isActive: nextActive);
    ref.invalidate(managedUsersProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(managedUsersProvider);
    final locations = ref.watch(locationsProvider).valueOrNull ?? const <LocationRef>[];

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Manajemen Pengguna & Keamanan Sesi',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: HtiColors.navyPrimary),
                    ),
                    Text(
                      'Kelola RBAC lokasi (Read Global, Write Local) dan Remote Force-Logout perangkat hilang.',
                      style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateUserDialog(context, ref, locations),
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Tambah User'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: usersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(err.toString(), style: const TextStyle(color: HtiColors.statusBroken)),
            ),
            data: (users) => ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: users.length,
              itemBuilder: (_, idx) {
                final u = users[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: u.isActive ? HtiColors.navyPrimary : Colors.grey,
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    title: Text(
                      '${u.fullName} (@${u.username})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${u.role.displayLabel} • '
                      '${u.assignedLocation != null ? u.assignedLocation!.name : 'Semua Lokasi'}'
                      '${u.mustChangePassword ? ' • Wajib Ganti Sandi' : ''}'
                      '${!u.isActive ? ' • NONAKTIF' : ''}',
                    ),
                    trailing: Wrap(
                      spacing: 6,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _confirmRevokeSessions(context, ref, u),
                          icon: const Icon(Icons.phonelink_erase_outlined, size: 16),
                          label: const Text('Cabut Sesi'),
                        ),
                        OutlinedButton(
                          onPressed: () => _confirmToggleActive(context, ref, u),
                          child: Text(u.isActive ? 'Nonaktifkan' : 'Aktifkan'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
