import 'package:flutter/material.dart';
import '../services/api_client.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.api, required this.onLogin});
  final ApiClient api;
  final VoidCallback onLogin;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool obscure = true;
  String? error;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    if (loading || !form.currentState!.validate()) return;
    setState(() { loading = true; error = null; });
    try {
      final data = await widget.api.post('login', {
        'email': email.text.trim(),
        // Whitespace is part of a password; never trim it.
        'password': password.text,
      }, authenticated: false);
      final token = data['token'];
      if (token is! String || token.isEmpty) {
        throw const ApiException('Server tidak mengirim sesi login yang valid.');
      }
      await widget.api.tokens.write(token);
      if (mounted) widget.onLogin();
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : 'Sesi tidak dapat disimpan. Coba lagi.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(child: Padding(
            padding: const EdgeInsets.all(28),
            child: Form(key: form, child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.location_city, size: 64, color: Color(0xffdc2626)),
                const SizedBox(height: 20),
                const Text('Chips Bodywork', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Masuk untuk mencatat kehadiran Anda.', textAlign: TextAlign.center),
                const SizedBox(height: 28),
                TextFormField(
                  controller: email,
                  enabled: !loading,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (value) => value == null || !value.contains('@') ? 'Masukkan email yang valid.' : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: password,
                  enabled: !loading,
                  obscureText: obscure,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => login(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      tooltip: obscure ? 'Tampilkan password' : 'Sembunyikan password',
                      onPressed: () => setState(() => obscure = !obscure),
                      icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                  validator: (value) => value == null || value.isEmpty ? 'Password wajib diisi.' : null,
                ),
                if (error != null) Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: loading ? null : login,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(loading ? 'Memproses…' : 'Masuk'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Akun disediakan oleh admin perusahaan.', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            )),
          )),
        ),
      )),
    );
  }
}
