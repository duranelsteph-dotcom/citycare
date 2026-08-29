import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'offline_queue.dart';

/// File hors ligne : positions et SOS uniquement, jamais de secret kit.
class OfflineQueueStore {
  OfflineQueueStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
            );

  static const key = 'citycare_offline_queue';
  final FlutterSecureStorage _storage;

  Future<void> loadInto(OfflineQueue queue) async {
    queue.loadFrom(await _storage.read(key: key));
  }

  Future<void> save(OfflineQueue queue) async {
    if (!queue.hasPending) {
      await _storage.delete(key: key);
      return;
    }
    await _storage.write(key: key, value: queue.encode());
  }
}
