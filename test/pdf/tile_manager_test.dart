import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/tile_manager.dart';

void main() {
  group('TileManager', () {
    test('getTile returns null for missing tile', () {
      final manager = TileManager();
      expect(manager.getTile(0, 0, 0, 1.0), isNull);
    });

    test('bucketizeZoom returns correct bucket', () {
      final manager = TileManager();
      expect(manager.bucketizeZoom(1.0), equals(2)); // 1.0 / 0.5 = 2
      expect(manager.bucketizeZoom(1.5), equals(3)); // 1.5 / 0.5 = 3
      expect(manager.bucketizeZoom(5.0), equals(10)); // 5.0 / 0.5 = 10
    });

    test('LRU eviction removes oldest entry', () {
      final manager = TileManager();
      // Fill up to max entries
      for (int i = 0; i < TileManager.maxEntries; i++) {
        manager.updateLru('key_$i');
      }
      expect(manager.lruOrder.length, equals(TileManager.maxEntries));

      // Add one more - should evict oldest
      manager.updateLru('new_key');
      expect(manager.lruOrder.length, equals(TileManager.maxEntries));
      expect(manager.lruOrder.first, equals('key_1')); // key_0 should be evicted
    });

    test('clear removes all entries', () {
      final manager = TileManager();
      for (int i = 0; i < 5; i++) {
        manager.updateLru('key_$i');
      }
      manager.clear();
      expect(manager.size, equals(0));
      expect(manager.lruOrder.length, equals(0));
    });
  });
}
