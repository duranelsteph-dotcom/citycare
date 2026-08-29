abstract class TokenStore {
  Future<void> save(String token);
  Future<String?> read();
  Future<void> clear();
}

class MemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<void> save(String token) async => _token = token;

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> clear() async => _token = null;
}
