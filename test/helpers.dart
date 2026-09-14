import 'package:my_flutter_app/services/token_store.dart';

class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this.token]);
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async { token = value; }
  @override
  Future<void> delete() async { token = null; }
}
