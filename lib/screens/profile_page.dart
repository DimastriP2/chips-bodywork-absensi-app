import 'package:flutter/material.dart';
import '../services/api_client.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.api});
  final ApiClient api;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final form = GlobalKey<FormState>();
  final oldPassword = TextEditingController();
  final newPassword = TextEditingController();
  final confirmation = TextEditingController();
  Map<String, dynamic>? profile;
  String? error;
  bool loading = false;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    fetch();
  }

  @override
  void dispose() {
    oldPassword.dispose();
    newPassword.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> fetch() async {
    if (loading) return;
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.api.get('profile');
      if (mounted) setState(() => profile = data);
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : 'Profil belum dapat dimuat.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> changePassword() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final data = await widget.api.post('change-password', {
        'old_password': oldPassword.text,
        'new_password': newPassword.text,
        'new_password_confirmation': confirmation.text,
      });
      if (!mounted) return;
      oldPassword.clear();
      newPassword.clear();
      confirmation.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message']?.toString() ?? 'Password berhasil diubah.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(
          e is ApiException ? e.message : 'Password belum dapat diubah.',
        )));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = profile?['user'] as Map<String, dynamic>?;
    final employee = profile?['employee'] as Map<String, dynamic>?;
    return RefreshIndicator(
      onRefresh: fetch,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (loading) const LinearProgressIndicator(),
          if (error != null) Column(children: [
            Text(error!),
            TextButton(onPressed: loading ? null : fetch, child: const Text('Muat ulang')),
          ]),
          if (profile != null) ...[
            const CircleAvatar(radius: 36, child: Icon(Icons.person, size: 40)),
            const SizedBox(height: 12),
            Text(user?['name']?.toString() ?? 'Karyawan', textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(user?['email']?.toString() ?? '—', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            if (employee == null)
              const Card(child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Profil karyawan belum tersedia. Hubungi admin agar akun dapat digunakan untuk absensi.'),
              )),
            for (final field in {
              'Nomor karyawan': employee?['employee_number'],
              'Posisi': employee?['position'],
              'No. telepon': employee?['phone'],
              'Alamat': employee?['address'],
            }.entries) Card(child: ListTile(
              title: Text(field.key, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              subtitle: Text(field.value?.toString() ?? '—'),
            )),
            const SizedBox(height: 24),
            Text('Ganti password', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Form(key: form, child: Column(children: [
              passwordField(oldPassword, 'Password lama',
                (value) => value == null || value.isEmpty ? 'Password lama wajib diisi.' : null),
              const SizedBox(height: 16),
              passwordField(newPassword, 'Password baru',
                (value) => value == null || value.length < 8 ? 'Minimal 8 karakter.' : null),
              const SizedBox(height: 16),
              passwordField(confirmation, 'Konfirmasi password baru',
                (value) => value != newPassword.text ? 'Konfirmasi belum sama.' : null),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: saving ? null : changePassword,
                icon: const Icon(Icons.lock_reset),
                label: Text(saving ? 'Menyimpan…' : 'Simpan password'),
              ),
            ])),
          ],
        ],
      ),
    );
  }

  Widget passwordField(TextEditingController controller, String label,
      String? Function(String?) validator) => TextFormField(
    controller: controller,
    obscureText: true,
    enabled: !saving,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(labelText: label),
    validator: validator,
  );
}
