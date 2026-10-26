import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) => const FlutterSecureStorage());

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore(ref.watch(secureStorageProvider)));

class TokenStore {
  TokenStore(this._storage);

  static const _key = 'auth_token';

  final FlutterSecureStorage _storage;
  String? _cached;
  bool _loaded = false;

  Future<String?> read() async {
    if (!_loaded) {
      _cached = await _storage.read(key: _key);
      _loaded = true;
    }
    return _cached;
  }

  Future<void> write(String token) async {
    await _storage.write(key: _key, value: token);
    _cached = token;
    _loaded = true;
  }

  Future<void> clear() async {
    await _storage.delete(key: _key);
    _cached = null;
    _loaded = true;
  }
}
