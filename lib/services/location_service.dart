import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationFailure implements Exception {
  const LocationFailure(this.message, {this.openSettings = false});
  final String message;
  final bool openSettings;
  @override
  String toString() => message;
}

class LocationService {
  Future<Position> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure('GPS belum aktif. Aktifkan lokasi lalu coba lagi.', openSettings: true);
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationFailure('Izinkan akses lokasi melalui pengaturan aplikasi.', openSettings: true);
    }
    if (permission == LocationPermission.denied) {
      throw const LocationFailure('Izin lokasi diperlukan untuk melakukan absensi.');
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
    } on TimeoutException {
      throw const LocationFailure('Lokasi belum ditemukan. Pindah ke area terbuka lalu coba lagi.');
    }
  }
}
