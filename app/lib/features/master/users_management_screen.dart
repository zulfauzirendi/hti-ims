import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/inventory_models.dart';
import '../../core/models/user_model.dart';
import '../../core/theme/app_theme.dart';
import '../dashboard/dashboard_repository.dart';
import '../inventory/inventory_providers.dart';
import '../inventory/inventory_repository.dart';
import 'users_repository.dart';

/// Pusat Manajemen SUPER_ADMIN: Pengguna (RBAC & Remote Force-Logout), Master Kategori, dan Master Lokasi
class UsersManagementScreen extends ConsumerWidget {
  const UsersManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.white,
            child: const TabBar(
              labelColor: HtiColors.navyPrimary,
              indicatorColor: HtiColors.amberAccent,
              tabs: [
                Tab(icon: Icon(Icons.manage_accounts_outlined), text: 'Pengguna & Sesi'),
                Tab(icon: Icon(Icons.category_outlined), text: 'Master Kategori'),
                Tab(icon: Icon(Icons.location_on_outlined), text: 'Master Lokasi'),
              ],
            ),
          ),
          const Divider(height: 1),
          const Expanded(
            child: TabBarView(
              children: [
                _UsersTab(),
                _CategoriesTab(),
                _LocationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UsersTab extends ConsumerWidget {
  const _UsersTab();

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

  Future<void> _showResetPasswordDialog(
    BuildContext context,
    WidgetRef ref,
    ManagedUserRecord target,
  ) async {
    final passCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var busy = false;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text('Reset Kata Sandi • @${target.username}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Reset kata sandi otomatis mencabut seluruh sesi aktif dan mewajibkan pengguna mengganti sandi saat login berikutnya.',
                    style: TextStyle(fontSize: 12.5, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 12),
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Kata Sandi Sementara Baru',
                      helperText: 'Min. 8 karakter, huruf besar, huruf kecil & angka',
                    ),
                  ),
                ],
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
                          await ref
                              .read(usersRepositoryProvider)
                              .updateUser(target.id, resetPassword: passCtrl.text);
                          ref.invalidate(managedUsersProvider);
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Kata sandi @${target.username} berhasil direset.')),
                            );
                          }
                        } catch (e) {
                          setState(() {
                            busy = false;
                            error = e.toString();
                          });
                        }
                      },
                child: Text(busy ? 'Mereset...' : 'Reset Kata Sandi'),
              ),
            ],
          ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Kelola RBAC lokasi (Read Global, Write Local), Reset Sandi & Remote Force-Logout.',
                  style: TextStyle(fontSize: 12.5, color: Colors.blueGrey),
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
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: u.isActive ? HtiColors.navyPrimary : Colors.grey,
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${u.fullName} (@${u.username})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                  ),
                                  Text(
                                    '${u.role.displayLabel} • '
                                    '${u.assignedLocation != null ? u.assignedLocation!.name : 'Semua Lokasi'}'
                                    '${u.mustChangePassword ? ' • Wajib Ganti Sandi' : ''}'
                                    '${!u.isActive ? ' • NONAKTIF' : ''}',
                                    style: const TextStyle(fontSize: 12.5, color: Colors.blueGrey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _showResetPasswordDialog(context, ref, u),
                              icon: const Icon(Icons.key_outlined, size: 16),
                              label: const Text('Reset Sandi'),
                            ),
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

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  Future<void> _showCategoryDialog(BuildContext context, WidgetRef ref, [CategoryRef? editing]) async {
    final codeCtrl = TextEditingController(text: editing?.code ?? '');
    final nameCtrl = TextEditingController(text: editing?.name ?? '');

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var busy = false;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(editing == null ? 'Tambah Kategori Baru' : 'Edit Kategori • ${editing.code}'),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                    const SizedBox(height: 8),
                  ],
                  if (editing == null) ...[
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kode Kategori (Huruf Besar, maks 10)',
                        hintText: 'Contoh: WLD',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Kategori'),
                  ),
                ],
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
                          final repo = ref.read(inventoryRepositoryProvider);
                          if (editing == null) {
                            await repo.createCategory(code: codeCtrl.text, name: nameCtrl.text);
                          } else {
                            await repo.updateCategory(id: editing.id, name: nameCtrl.text);
                          }
                          ref.invalidate(categoriesProvider);
                          ref.invalidate(dashboardSummaryProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(categoriesProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Kelola taksonomi kategori alat (prefix kode SKU otomatis).',
                  style: TextStyle(fontSize: 12.5, color: Colors.blueGrey),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCategoryDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Tambah Kategori'),
              ),
            ],
          ),
        ),
        Expanded(
          child: catsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (cats) => ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: cats.length,
              itemBuilder: (_, idx) {
                final c = cats[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: HtiColors.navyPrimary.withValues(alpha: 0.1),
                      child: Text(c.code, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: IconButton(
                      tooltip: 'Edit Nama Kategori',
                      onPressed: () => _showCategoryDialog(context, ref, c),
                      icon: const Icon(Icons.edit_outlined),
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

class _LocationsTab extends ConsumerWidget {
  const _LocationsTab();

  Future<void> _showLocationDialog(BuildContext context, WidgetRef ref, [LocationRef? editing]) async {
    final codeCtrl = TextEditingController(text: editing?.code ?? '');
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    var locType = editing?.locationType ?? 'SITE';

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        var busy = false;
        String? error;
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text(editing == null ? 'Tambah Lokasi Baru' : 'Edit Lokasi • ${editing.code}'),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (error != null) ...[
                    Text(error!, style: const TextStyle(color: HtiColors.statusBroken, fontSize: 12.5)),
                    const SizedBox(height: 8),
                  ],
                  if (editing == null) ...[
                    TextField(
                      controller: codeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kode Lokasi (Huruf Besar/Angka/-)',
                        hintText: 'Contoh: SITE-JIIPE',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Nama Lokasi'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: locType,
                    decoration: const InputDecoration(labelText: 'Tipe Lokasi'),
                    items: const [
                      DropdownMenuItem(value: 'WAREHOUSE', child: Text('WAREHOUSE (Gudang)')),
                      DropdownMenuItem(value: 'SITE', child: Text('SITE (Lokasi Proyek)')),
                    ],
                    onChanged: (v) => setState(() => locType = v!),
                  ),
                ],
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
                          final repo = ref.read(inventoryRepositoryProvider);
                          if (editing == null) {
                            await repo.createLocation(
                              code: codeCtrl.text,
                              name: nameCtrl.text,
                              locationType: locType,
                            );
                          } else {
                            await repo.updateLocation(
                              id: editing.id,
                              name: nameCtrl.text,
                              locationType: locType,
                            );
                          }
                          ref.invalidate(locationsProvider);
                          ref.invalidate(dashboardSummaryProvider);
                          ref.invalidate(inventorySearchProvider);
                          if (ctx.mounted) Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locsAsync = ref.watch(locationsProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  'Tambah lokasi proyek/gudang baru — langsung aktif di seluruh pencarian & transfer (SRS-ADP-003).',
                  style: TextStyle(fontSize: 12.5, color: Colors.blueGrey),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showLocationDialog(context, ref),
                icon: const Icon(Icons.add_location_alt_outlined),
                label: const Text('Tambah Lokasi'),
              ),
            ],
          ),
        ),
        Expanded(
          child: locsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text(e.toString())),
            data: (locs) => ListView.builder(
              padding: const EdgeInsets.all(14),
              itemCount: locs.length,
              itemBuilder: (_, idx) {
                final l = locs[idx];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      l.locationType == 'SITE' ? Icons.engineering_outlined : Icons.warehouse_outlined,
                      color: HtiColors.navyPrimary,
                    ),
                    title: Text('${l.name} (${l.code})', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Tipe: ${l.locationType}'),
                    trailing: IconButton(
                      tooltip: 'Edit Lokasi',
                      onPressed: () => _showLocationDialog(context, ref, l),
                      icon: const Icon(Icons.edit_outlined),
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
