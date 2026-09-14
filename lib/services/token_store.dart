import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _key = 'chips_mobile_token';

  Future<void> migrateLegacyToken() async {
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString('token');
    if (legacy != null && await _storage.read(key: _key) == null) {
      // Remove the legacy copy only after the secure write succeeds.
      await _storage.write(key: _key, value: legacy);
    }
    for (final key in [
      'token', 'name', 'email', 'hasCheckedIn', 'hasCheckedOut',
      'attendanceDate', 'currentLat', 'currentLng',
    ]) {
      await prefs.remove(key);
    }
  }

  @override
  Future<String?> read() => _storage.read(key: _key);

  @override
  Future<void> write(String token) => _storage.write(key: _key, value: token);

  @override
  Future<void> delete() => _storage.delete(key: _key);
}
