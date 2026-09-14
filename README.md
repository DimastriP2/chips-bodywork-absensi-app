# Chips Bodywork — Aplikasi Absensi Flutter

Aplikasi karyawan untuk check in/check out berbasis lokasi, riwayat per bulan,
ringkasan kehadiran, dan pengelolaan sesi. Proyek portofolio Dimas Tri Pamungkas.

## Backend yang diperlukan

Aplikasi ini menggunakan penambahan API pada
[PR backend #1](https://github.com/DimastriP2/chips-bodywork-absensi-api/pull/1).
Jalankan branch backend `codex/portfolio-attendance-upgrade` beserta migrasinya
sebelum menguji branch mobile. Backend lama belum menyediakan endpoint status,
ringkasan, lokasi, dan logout yang dibutuhkan.

## Perubahan utama

- Status/tanggal absensi mengikuti server Asia/Jakarta; cache boolean lama dihapus.
- Status dimuat ulang saat kembali ke aplikasi, tiap menit pada beranda, sebelum
  menulis absensi, serta setelah berhasil/gagal/timeout.
- Tombol terkunci selama proses; check out tidak aktif sebelum check in.
- Token menggunakan secure storage; token lama dipindahkan dari SharedPreferences
  setelah penyimpanan aman berhasil. Password tidak dipangkas saat login.
- Satu API client menangani timeout, JSON invalid, validasi, 401, dan Retry-After.
- Ringkasan bulanan, riwayat dengan pagination serta navigasi bulan.
- GPS berakurasi tinggi, pesan izin/lokasi gagal, dan tombol buka pengaturan.
- Peta opsional menampilkan titik kantor/perangkat serta lingkaran radius.
- Navigasi bawah, empty/error states, form validation, serta controller yang dibersihkan.

## Menjalankan

Gunakan Flutter stable dengan Dart yang memenuhi `^3.11.5` sesuai pubspec.

```sh
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

`10.0.2.2` adalah host dari emulator Android. Untuk perangkat fisik, gunakan alamat
backend yang dapat dijangkau perangkat. HTTP hanya untuk debug lokal; build release
mensyaratkan HTTPS. Jangan memakai alamat server atau kunci asli di source.

Akun contoh dibuat dari `DemoSeeder` pada backend. Password acak ditampilkan saat
seeder dijalankan. Login admin dipakai pada web; gunakan akun staff untuk absensi mobile.

## Mengaktifkan peta Google

Peta secara default tidak ditampilkan sampai konfigurasi build mengaktifkannya.
Pembacaan GPS, jarak, radius, dan absensi tetap tersedia tanpa tampilan peta.

### Android

Sediakan `MAPS_API_KEY` melalui environment build atau properti Gradle lokal
`~/.gradle/gradle.properties`, bukan file yang di-commit. Contoh properti:

```properties
MAPS_API_KEY=isi_kunci_maps_android_anda
```

Lalu jalankan:

```sh
flutter run --dart-define=API_BASE_URL=https://domain-backend-anda/api --dart-define=MAPS_ENABLED=true
```

Aktifkan Maps SDK for Android dan batasi key pada package ID serta fingerprint
sertifikat aplikasi. Key lama sebelumnya tertulis di manifest publik; menghapusnya
dari versi terbaru tidak menghapus riwayat Git. Ganti atau batasi key lama di Google
Cloud sebelum menggunakan deployment nyata.

### iOS

Tetapkan user-defined build setting `MAPS_API_KEY` pada konfigurasi Xcode lokal,
aktifkan Maps SDK for iOS, lalu gunakan `--dart-define=MAPS_ENABLED=true`.
Info.plist memasok key ke AppDelegate; keychain entitlement dan izin lokasi sudah
disiapkan. Jalankan build/uji pada macOS dan perangkat iOS sebelum distribusi.
Jangan mengaktifkan peta jika key platform belum tersedia.

## Pengujian

```sh
flutter analyze
flutter test
flutter build apk --debug --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
```

GitHub Actions menjalankan analisis, tes, dan build Android debug. Tes memakai server
palsu untuk kontrak API dan tidak mengakses data karyawan nyata.

Tes mencakup header token, invalid JSON, validasi, 401, respons 401 terlambat dari sesi
lama, rate limit, timeout tanpa retry POST, form login, password whitespace, dan
tombol absensi saat status belum valid. Pengujian perangkat tetap diperlukan untuk
KeyStore/Keychain, izin GPS, peta native, serta integrasi dengan backend berjalan.

## Struktur

| Folder/file | Isi |
| --- | --- |
| lib/main.dart | Bootstrap, pemulihan sesi, navigasi |
| lib/services/api_client.dart | HTTP, timeout, respons error, token |
| lib/services/token_store.dart | Secure storage dan migrasi token lama |
| lib/services/location_service.dart | GPS dan permission |
| lib/screens | Login, beranda, riwayat, profil |
| test | Unit dan widget tests |

## Batasan yang perlu dipahami

- ZIP unggahan belum dibandingkan byte-per-byte dengan repo ini.
- Tidak ada klaim GPS anti-palsu atau pelacakan lokasi terus-menerus.
- Data ringkasan adalah durasi masuk–pulang, belum dikurangi istirahat.
- Status offline tidak dianggap absensi berhasil; mutasi tidak diulang otomatis.
- Logout memerlukan konfirmasi server. Jika koneksi gagal, sesi tetap tersedia
  agar pencabutan token dapat dicoba kembali.
- Android release signing masih memakai konfigurasi awal proyek; siapkan keystore
  rilis sendiri sebelum distribusi. APK debug untuk pengujian, bukan rilis perusahaan.
- Target pengujian CI Android. iOS/desktop/web belum divalidasi.
- Shift malam, izin/cuti, audit trail, dan retensi riwayat saat akun dinonaktifkan
  berada pada roadmap backend.

## Referensi

- [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage)
- [Geolocator](https://pub.dev/packages/geolocator)
- [Kontrak backend](https://github.com/DimastriP2/chips-bodywork-absensi-api/blob/codex/portfolio-attendance-upgrade/docs/API.md)
