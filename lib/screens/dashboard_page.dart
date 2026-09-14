import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/api_client.dart';
import '../services/location_service.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.api, this.location});
  final ApiClient api;
  final LocationService? location;
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> with WidgetsBindingObserver {
  late final LocationService location;
  Timer? refreshTimer;
  bool loading = false;
  bool submitting = false;
  bool locating = false;
  bool currentStatus = false;
  String? error;
  String? locationError;
  bool showSettings = false;
  Map<String, dynamic>? today;
  Map<String, dynamic>? summary;
  Map<String, dynamic>? office;
  String name = 'Karyawan';
  Position? position;

  @override
  void initState() {
    super.initState();
    location = widget.location ?? LocationService();
    WidgetsBinding.instance.addObserver(this);
    refreshData();
    locate();
    refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => refreshData());
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshData();
  }

  Future<void> refreshData() async {
    if (submitting || loading) return;
    setState(() { loading = true; currentStatus = false; error = null; });
    try {
      final results = await Future.wait([
        widget.api.get('attendance/today'),
        widget.api.get('attendance/summary'),
        widget.api.get('office'),
        widget.api.get('profile'),
      ]);
      if (!mounted) return;
      setState(() {
        today = results[0];
        summary = results[1]['summary'] as Map<String, dynamic>;
        office = results[2]['office'] as Map<String, dynamic>;
        name = (results[3]['user'] as Map)['name']?.toString() ?? 'Karyawan';
        currentStatus = true;
      });
    } catch (e) {
      if (mounted) setState(() => error = e is ApiException ? e.message : 'Data kehadiran belum dapat dimuat.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> locate() async {
    if (locating || submitting) return;
    setState(() { locating = true; locationError = null; showSettings = false; });
    try {
      final value = await location.current();
      if (mounted) setState(() => position = value);
    } catch (e) {
      if (mounted) {
        setState(() {
          position = null;
          locationError = e is LocationFailure ? e.message : 'Lokasi belum tersedia. Coba lagi.';
          showSettings = e is LocationFailure && e.openSettings;
        });
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> record(bool checkingOut) async {
    if (submitting || loading || !currentStatus) return;
    setState(() { submitting = true; currentStatus = false; });
    String message;
    try {
      final fresh = await widget.api.get('attendance/today');
      final state = fresh['state'];
      if ((checkingOut && state != 'checked_in') ||
          (!checkingOut && state != 'not_checked_in')) {
        throw const ApiException('Status absensi berubah. Periksa status terbaru.');
      }
      final gps = await location.current();
      if (!mounted) return;
      setState(() { position = gps; locationError = null; });
      final result = await widget.api.post(checkingOut ? 'checkout' : 'checkin', {
        'latitude': gps.latitude, 'longitude': gps.longitude,
      });
      message = result['message']?.toString() ?? 'Absensi berhasil disimpan.';
    } catch (e) {
      message = e is ApiException || e is LocationFailure
          ? e.toString() : 'Absensi belum dapat dipastikan. Periksa status terbaru.';
    } finally {
      if (mounted) setState(() => submitting = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    // Reconcile after success, conflict, timeout, or failure. Never auto-retry a write.
    await refreshData();
  }

  double number(dynamic value) => double.tryParse(value.toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final attendance = today?['attendance'] as Map<String, dynamic>?;
    final state = today?['state'];
    final valid = currentStatus && !loading && !submitting;
    final colors = Theme.of(context).colorScheme;
    final officePoint = office == null ? null : LatLng(
      number(office!['latitude']), number(office!['longitude']),
    );
    final userPoint = position == null ? null : LatLng(position!.latitude, position!.longitude);
    final distance = officePoint == null || userPoint == null ? null
        : Geolocator.distanceBetween(officePoint.latitude, officePoint.longitude,
            userPoint.latitude, userPoint.longitude);

    return RefreshIndicator(
      onRefresh: refreshData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text('Halo, $name', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(today == null ? 'Memuat status kehadiran…'
              : '${today!['date']} · ${today!['timezone']}',
            style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Card(child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(error!, style: TextStyle(color: colors.error)),
              const Text('Tombol absensi aktif setelah status terbaru berhasil dimuat.'),
              TextButton(onPressed: loading ? null : refreshData, child: const Text('Muat ulang')),
            ]),
          )),
          Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(state == 'checked_out' ? 'Absensi hari ini lengkap'
                  : state == 'checked_in' ? 'Sudah masuk, belum pulang'
                  : currentStatus ? 'Siap memulai hari kerja' : 'Status belum terverifikasi',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: timeTile('Masuk', attendance?['check_in_time'])),
                Expanded(child: timeTile('Pulang', attendance?['check_out_time'])),
              ]),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: valid && state == 'not_checked_in' ? () => record(false) : null,
                icon: const Icon(Icons.login),
                label: Text(submitting ? 'Memproses…' : 'Absen masuk'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: valid && state == 'checked_in' ? () => record(true) : null,
                icon: const Icon(Icons.logout),
                label: const Text('Absen pulang'),
              ),
            ]),
          )),
          const SizedBox(height: 16),
          Text('Lokasi kantor', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (officePoint != null && const bool.fromEnvironment('MAPS_ENABLED')) ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(height: 220, child: GoogleMap(
              key: ValueKey('$officePoint/$userPoint'),
              initialCameraPosition: CameraPosition(target: userPoint ?? officePoint, zoom: 16),
              markers: {
                Marker(markerId: const MarkerId('office'), position: officePoint,
                    infoWindow: InfoWindow(title: office!['office_name'].toString())),
                if (userPoint != null) Marker(
                  markerId: const MarkerId('employee'), position: userPoint,
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
                  infoWindow: const InfoWindow(title: 'Lokasi perangkat terakhir'),
                ),
              },
              circles: {Circle(
                circleId: const CircleId('office-radius'), center: officePoint,
                radius: number(office!['radius']), strokeWidth: 2,
                strokeColor: colors.primary,
                fillColor: colors.primary.withValues(alpha: 0.12),
              )},
              zoomControlsEnabled: false,
              myLocationButtonEnabled: false,
            )),
          ),
          if (office != null) Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text('${office!['office_name']} · Radius ${office!['radius']} m'
              '${distance == null ? '' : '\nPerkiraan jarak Anda: ${distance.round()} m'}'),
          ),
          if (position != null) Text(
            'Akurasi GPS ±${position!.accuracy.round()} m. Lokasi diambil ulang saat absen.',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          if (locationError != null) Text(locationError!, style: TextStyle(color: colors.error)),
          Wrap(spacing: 8, children: [
            TextButton.icon(
              onPressed: locating || submitting ? null : locate,
              icon: const Icon(Icons.my_location),
              label: Text(locating ? 'Mencari lokasi…' : 'Perbarui lokasi'),
            ),
            if (showSettings) TextButton(
              onPressed: () async { await Geolocator.openAppSettings(); },
              child: const Text('Pengaturan aplikasi'),
            ),
            if (showSettings) TextButton(
              onPressed: () async { await Geolocator.openLocationSettings(); },
              child: const Text('Pengaturan GPS'),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Ringkasan bulan ini', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (summary != null) Card(child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              metric('Hari tercatat hadir', '${summary!['present_days']} hari'),
              metric('Masuk & pulang lengkap', '${summary!['completed_days']} hari'),
              metric('Belum ada jam pulang', '${summary!['incomplete_days']} hari'),
              metric('Durasi tercatat',
                '${number(summary!['recorded_minutes']) ~/ 60} jam '
                '${number(summary!['recorded_minutes']).toInt() % 60} menit'),
              const Text('Durasi belum dikurangi istirahat.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]),
          )),
        ],
      ),
    );
  }

  Widget timeTile(String title, dynamic time) => Column(children: [
    Text(title, style: const TextStyle(color: Colors.grey)),
    const SizedBox(height: 6),
    Text(time?.toString() ?? '—', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
  ]);

  Widget metric(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );
}
