import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/dashboard_page.dart';
import 'screens/history_page.dart';
import 'screens/login_page.dart';
import 'screens/profile_page.dart';
import 'services/api_client.dart';
import 'services/token_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id');
  runApp(const ChipsApp());
}

class ChipsApp extends StatefulWidget {
  const ChipsApp({super.key, this.client});
  final ApiClient? client;

  @override
  State<ChipsApp> createState() => _ChipsAppState();
}

class _ChipsAppState extends State<ChipsApp> {
  late final ApiClient api;
  bool ready = false;
  bool authenticated = false;
  String? startupError;
  int sessionVersion = 0;

  @override
  void initState() {
    super.initState();
    api = widget.client ?? ApiClient(tokens: SecureTokenStore());
    api.onUnauthorized = () {
      if (mounted) {
        setState(() {
          authenticated = false;
          sessionVersion++;
        });
      }
    };
    restoreSession();
  }

  Future<void> restoreSession() async {
    setState(() { startupError = null; ready = false; });
    try {
      final tokens = api.tokens;
      if (tokens is SecureTokenStore) await tokens.migrateLegacyToken();
      final token = await tokens.read();
      if (!mounted) return;
      setState(() {
        authenticated = token != null && token.isNotEmpty;
        ready = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          ready = true;
          startupError = 'Penyimpanan sesi belum tersedia. Silakan coba lagi.';
        });
      }
    }
  }

  @override
  void dispose() {
    api.onUnauthorized = null;
    if (widget.client == null) api.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = ColorScheme.fromSeed(seedColor: const Color(0xffdc2626));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chips Bodywork',
      theme: ThemeData(
        colorScheme: colors,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xfff4f6f9),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: !ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : startupError != null
              ? Scaffold(body: Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(startupError!),
                    TextButton(onPressed: restoreSession, child: const Text('Coba lagi')),
                  ],
                )))
              : authenticated
                  ? MainPage(
                      key: ValueKey(sessionVersion),
                      api: api,
                      onLogout: () {
                        if (mounted) {
                          setState(() { authenticated = false; sessionVersion++; });
                        }
                      },
                    )
                  : LoginPage(api: api, onLogin: () {
                      setState(() { authenticated = true; sessionVersion++; });
                    }),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key, required this.api, required this.onLogout});
  final ApiClient api;
  final VoidCallback onLogout;
  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int index = 0;
  bool loggingOut = false;

  Future<void> logout() async {
    if (loggingOut) return;
    setState(() => loggingOut = true);
    try {
      await widget.api.post('logout', {});
      await widget.api.tokens.delete();
      if (mounted) widget.onLogout();
    } catch (error) {
      // Keep the session available to retry when server revocation was not confirmed.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
      }
    } finally {
      if (mounted) setState(() => loggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(api: widget.api),
      HistoryPage(api: widget.api),
      ProfilePage(api: widget.api),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(['Kehadiran', 'Riwayat absensi', 'Profil saya'][index]),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: loggingOut ? null : logout,
            icon: loggingOut
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: pages[index]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.history), label: 'Riwayat'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profil'),
        ],
      ),
    );
  }
}
