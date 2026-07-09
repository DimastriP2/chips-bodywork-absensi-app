import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

const String baseUrl = 'http://192.168.1.4:8000/api';

void main() {
  runApp(const ChipsApp());
}

class ChipsApp extends StatelessWidget {
  const ChipsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chips Bodywork',
      home: LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  Future<void> login() async {
    setState(() => loading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': emailController.text.trim(),
          'password': passwordController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.clear();

        await prefs.setString('token', data['token']);
        await prefs.setString('name', data['user']['name']);
        await prefs.setString('email', data['user']['email']);

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainPage()),
        );
      } else {
        showMessage(data['message'] ?? 'Login gagal', Colors.red);
      }
    } catch (e) {
      showMessage('Gagal terhubung ke server: $e', Colors.red);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xffdc2626);
    const dark = Color(0xff111827);

    return Scaffold(
      backgroundColor: const Color(0xfff4f6f9),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(Icons.location_city, size: 70, color: red),
                const SizedBox(height: 18),
                const Text(
                  'Chips Bodywork',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: dark,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aplikasi Absensi Karyawan',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),
                const SizedBox(height: 36),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: red,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: loading ? null : login,
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                      'LOGIN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Chips Motor Bodywork',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int selectedIndex = 0;

  String name = '';
  String email = '';
  String position = '-';

  @override
  void initState() {
    super.initState();
    loadDrawerUser();
  }

  Future<void> loadDrawerUser() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      name = prefs.getString('name') ?? 'Karyawan';
      email = prefs.getString('email') ?? '-';
    });

    await fetchProfileForDrawer();
  }

  Future<void> fetchProfileForDrawer() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final employee = data['employee'];

        if (employee != null) {
          setState(() {
            position = employee['position']?.toString() ?? '-';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.clear();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  String getTitle() {
    if (selectedIndex == 0) return 'Dashboard Absen';
    if (selectedIndex == 1) return 'Profil Akun';
    return 'Rekap Absensi Saya';
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xff111827);
    const red = Color(0xffdc2626);

    final pages = [
      const DashboardPage(),
      const ProfilePage(),
      const HistoryPage(),
    ];

    return Scaffold(
      backgroundColor: const Color(0xfff4f6f9),
      appBar: AppBar(
        backgroundColor: dark,
        title: Text(
          getTitle(),
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 55, 20, 24),
              color: dark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const CircleAvatar(
                    radius: 34,
                    backgroundColor: red,
                    child: Icon(Icons.person, color: Colors.white, size: 38),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: const TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    position,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            drawerItem(icon: Icons.dashboard, title: 'Dashboard', index: 0),
            drawerItem(icon: Icons.person, title: 'Profil Saya', index: 1),
            drawerItem(icon: Icons.history, title: 'Rekap Absensi', index: 2),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout, color: red),
              title: const Text(
                'Logout',
                style: TextStyle(color: red, fontWeight: FontWeight.bold),
              ),
              onTap: logout,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
      body: pages[selectedIndex],
    );
  }

  Widget drawerItem({
    required IconData icon,
    required String title,
    required int index,
  }) {
    const red = Color(0xffdc2626);

    return ListTile(
      leading: Icon(
        icon,
        color: selectedIndex == index ? red : Colors.grey[700],
      ),
      title: Text(
        title,
        style: TextStyle(
          color: selectedIndex == index ? red : Colors.black87,
          fontWeight:
          selectedIndex == index ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: selectedIndex == index,
      onTap: () {
        Navigator.pop(context);
        setState(() => selectedIndex = index);
      },
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String name = '';
  bool loadingAttendance = false;
  bool hasCheckedIn = false;
  bool hasCheckedOut = false;

  double? currentLat;
  double? currentLng;

  @override
  void initState() {
    super.initState();
    loadUser();
    fetchTodayAttendance();
    loadCurrentLocationForMap();
  }

  Future<void> loadUser() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      name = prefs.getString('name') ?? 'Karyawan';
      hasCheckedIn = prefs.getBool('hasCheckedIn') ?? false;
      hasCheckedOut = prefs.getBool('hasCheckedOut') ?? false;
      currentLat = prefs.getDouble('currentLat');
      currentLng = prefs.getDouble('currentLng');
    });
  }
  Future<void> loadCurrentLocationForMap() async {
    try {
      final position = await getCurrentLocation();

      if (!mounted) return;

      setState(() {
        currentLat = position.latitude;
        currentLng = position.longitude;
      });
    } catch (e) {
      debugPrint('Gagal mengambil lokasi awal: $e');
    }
  }

  Future<void> saveAttendanceStatus(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await prefs.setString('attendanceDate', today);

    if (type == 'checkin') {
      await prefs.setBool('hasCheckedIn', true);
      setState(() => hasCheckedIn = true);
    }

    if (type == 'checkout') {
      await prefs.setBool('hasCheckedOut', true);
      setState(() => hasCheckedOut = true);
    }
  }
  Future<void> fetchTodayAttendance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) return;

      final response = await http.get(
        Uri.parse('$baseUrl/history'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final attendances = data['attendances'] ?? [];

        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

        final todayAttendance = attendances.firstWhere(
              (item) => item['date'].toString() == today,
          orElse: () => null,
        );

        if (todayAttendance != null) {
          setState(() {
            hasCheckedIn = todayAttendance['check_in_time'] != null;
            hasCheckedOut = todayAttendance['check_out_time'] != null;
          });
        } else {
          setState(() {
            hasCheckedIn = false;
            hasCheckedOut = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Gagal mengambil status absen: $e');
    }
  }

  Future<Position> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw Exception('GPS belum aktif. Aktifkan lokasi terlebih dahulu.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Izin lokasi ditolak permanen.');
    }

    if (permission == LocationPermission.denied) {
      throw Exception('Izin lokasi ditolak.');
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
      timeLimit: const Duration(seconds: 30),
    );
  }

  Future<void> attendance(String type) async {
    setState(() => loadingAttendance = true);

    try {
      if (type == 'checkin' && hasCheckedIn) {
        throw Exception('Anda sudah melakukan absen masuk hari ini.');
      }

      if (type == 'checkout' && hasCheckedOut) {
        throw Exception('Anda sudah melakukan absen pulang hari ini.');
      }

      if (type == 'checkout' && !hasCheckedIn) {
        throw Exception('Anda harus absen masuk terlebih dahulu.');
      }

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('Token tidak ditemukan. Silakan login ulang.');
      }

      final position = await getCurrentLocation();

      await prefs.setDouble('currentLat', position.latitude);
      await prefs.setDouble('currentLng', position.longitude);

      setState(() {
        currentLat = position.latitude;
        currentLng = position.longitude;
      });

      final url = type == 'checkin'
          ? '$baseUrl/checkin'
          : '$baseUrl/checkout';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'latitude': position.latitude.toString(),
          'longitude': position.longitude.toString(),
        }),
      );

      final data = jsonDecode(response.body);
      final isSuccess = response.statusCode == 200 || response.statusCode == 201;

      if (isSuccess) {
        await fetchTodayAttendance();
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(data['message'] ?? 'Berhasil'),
          backgroundColor: isSuccess ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => loadingAttendance = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const red = Color(0xffdc2626);
    const dark = Color(0xff111827);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Halo, $name',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: dark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Silakan lakukan absensi sesuai lokasi kantor.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: statusCard(
                    title: 'Absen Masuk',
                    value: hasCheckedIn ? 'Sudah' : 'Belum',
                    icon: Icons.login,
                    color: hasCheckedIn ? Colors.green : red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: statusCard(
                    title: 'Absen Pulang',
                    value: hasCheckedOut ? 'Sudah' : 'Belum',
                    icon: Icons.logout,
                    color: hasCheckedOut ? Colors.green : red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              clipBehavior: Clip.antiAlias,
              child: currentLat == null || currentLng == null
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(currentLat!, currentLng!),
                  zoom: 17,
                ),
                markers: {
                  Marker(
                    markerId: const MarkerId('lokasi_saya'),
                    position: LatLng(currentLat!, currentLng!),
                    infoWindow: const InfoWindow(
                      title: 'Lokasi Saat Absen',
                    ),
                  ),
                },
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: false,
              ),
            ),
            const SizedBox(height: 24),
            if (loadingAttendance)
              const Center(child: CircularProgressIndicator()),
            if (!loadingAttendance)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasCheckedIn ? Colors.grey : red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: hasCheckedIn ? null : () => attendance('checkin'),
                  icon: const Icon(Icons.login, color: Colors.white),
                  label: Text(
                    hasCheckedIn ? 'Sudah Absen Masuk' : 'Absen Masuk',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (!loadingAttendance)
              SizedBox(
                width: double.infinity,
                height: 55,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: hasCheckedOut ? Colors.grey : red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: hasCheckedOut ? null : () => attendance('checkout'),
                  icon: Icon(
                    Icons.logout,
                    color: hasCheckedOut ? Colors.grey : red,
                  ),
                  label: Text(
                    hasCheckedOut ? 'Sudah Absen Pulang' : 'Absen Pulang',
                    style: TextStyle(color: hasCheckedOut ? Colors.grey : red),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget statusCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool loading = true;
  bool changingPassword = false;

  bool showOldPassword = false;
  bool showNewPassword = false;
  bool showConfirmPassword = false;

  Map<String, dynamic>? user;
  Map<String, dynamic>? employee;

  final oldPasswordController = TextEditingController();
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchProfile();
  }

  @override
  void dispose() {
    oldPasswordController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          user = data['user'];
          employee = data['employee'];
        });
      }
    } catch (e) {
      debugPrint(e.toString());
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> changePassword() async {
    if (oldPasswordController.text.isEmpty ||
        newPasswordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      showMessage('Semua field password wajib diisi', Colors.red);
      return;
    }

    if (newPasswordController.text.length < 8) {
      showMessage(
        'Password baru minimal 8 karakter',
        Colors.red,
      );
      return;
    }

    if (newPasswordController.text !=
        confirmPasswordController.text) {
      showMessage(
        'Konfirmasi password tidak sama',
        Colors.red,
      );
      return;
    }

    setState(() => changingPassword = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.post(
        Uri.parse('$baseUrl/change-password'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'old_password': oldPasswordController.text,
          'new_password': newPasswordController.text,
          'new_password_confirmation':
          confirmPasswordController.text,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        oldPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();

        showMessage(
          data['message'] ?? 'Password berhasil diubah',
          Colors.green,
        );
      } else {
        showMessage(
          data['message'] ?? 'Gagal mengubah password',
          Colors.red,
        );
      }
    } catch (e) {
      showMessage(
        'Terjadi kesalahan: $e',
        Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => changingPassword = false);
      }
    }
  }

  void showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const dark = Color(0xff111827);
    const red = Color(0xffdc2626);

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [

            const CircleAvatar(
              radius: 45,
              backgroundColor: red,
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 50,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              user?['name']?.toString() ?? '-',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: dark,
              ),
            ),

            const SizedBox(height: 6),

            Text(
              user?['email']?.toString() ?? '-',
              style: const TextStyle(
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 24),

            profileItem(
              'NIK',
              employee?['employee_number'],
            ),

            profileItem(
              'Posisi',
              employee?['position'],
            ),

            profileItem(
              'No HP',
              employee?['phone'],
            ),

            profileItem(
              'Alamat',
              employee?['address'],
            ),

            const SizedBox(height: 30),

            const Divider(),

            const SizedBox(height: 20),

            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Ganti Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: oldPasswordController,
              obscureText: !showOldPassword,
              decoration: InputDecoration(
                labelText: 'Password Lama',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    showOldPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showOldPassword = !showOldPassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: newPasswordController,
              obscureText: !showNewPassword,
              decoration: InputDecoration(
                labelText: 'Password Baru',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    showNewPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showNewPassword = !showNewPassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 15),

            TextField(
              controller: confirmPasswordController,
              obscureText: !showConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Konfirmasi Password Baru',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showConfirmPassword =
                      !showConfirmPassword;
                    });
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: red,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(16),
                  ),
                ),
                onPressed: changingPassword
                    ? null
                    : changePassword,
                icon: changingPassword
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                  CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(
                  Icons.lock_reset,
                  color: Colors.white,
                ),
                label: const Text(
                  'UBAH PASSWORD',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget profileItem(String title, dynamic value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xfff9fafb),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value?.toString() ?? '-',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  bool loading = true;
  List<dynamic> histories = [];

  @override
  void initState() {
    super.initState();
    fetchHistory();
  }

  Future<void> fetchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      final response = await http.get(
        Uri.parse('$baseUrl/history'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          histories = data['attendances'] ?? [];
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: fetchHistory,
      child: histories.isEmpty
          ? ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 150),
          Center(
            child: Text(
              'Belum ada riwayat absensi',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      )
          : ListView.builder(
        padding: const EdgeInsets.all(24),
        itemCount: histories.length,
        itemBuilder: (context, index) {
          final item = histories[index];

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['date']?.toString() ?? '-',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                historyRow(
                  Icons.login,
                  'Masuk',
                  item['check_in_time']?.toString() ?? '-',
                ),
                const SizedBox(height: 8),
                historyRow(
                  Icons.logout,
                  'Pulang',
                  item['check_out_time']?.toString() ?? '-',
                ),
                const SizedBox(height: 8),
                historyRow(
                  Icons.location_on,
                  'Jarak',
                  item['distance'] == null
                      ? '-'
                      : '${item['distance']} meter',
                ),
                const SizedBox(height: 8),
                historyRow(
                  Icons.verified,
                  'Status',
                  item['status']?.toString() ?? '-',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget historyRow(IconData icon, String label, String value) {
    const red = Color(0xffdc2626);

    return Row(
      children: [
        Icon(icon, size: 18, color: red),
        const SizedBox(width: 8),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}