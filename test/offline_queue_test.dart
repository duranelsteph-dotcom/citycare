import 'package:citycare/data/datasources/offline_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline queue appends points and keeps client timestamps', () {
    final queue = OfflineQueue();
    queue.enqueueLocation({
      'latitude': 3.84,
      'longitude': 11.50,
      'recorded_at': '2026-08-28T07:00:00.000Z',
    });
    queue.enqueueLocation({
      'latitude': 3.85,
      'longitude': 11.51,
      'recorded_at': '2026-08-28T07:01:00.000Z',
    });
    queue.enqueueSos({
      'description': 'Déclenchement discret (application)',
      'recorded_at': '2026-08-28T07:02:00.000Z',
    });

    expect(queue.pendingCount, 3);
    expect(queue.locations.length, 2);
    expect(queue.locations.first['latitude'], 3.84);
    expect(queue.locations.last['latitude'], 3.85);

    final restored = OfflineQueue()..loadFrom(queue.encode());
    expect(restored.locations.length, 2);
    expect(restored.sos.single['description'], 'Déclenchement discret (application)');
    expect(restored.locations.first['recorded_at'], '2026-08-28T07:00:00.000Z');
    expect(restored.locations.last['recorded_at'], '2026-08-28T07:01:00.000Z');
  });
}
