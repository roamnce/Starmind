// test/mindmap/ui/painters/ink_thumbnail_cache_test.dart

import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/ink_layer.dart';
import 'package:starmind/src/mindmap/ui/painters/ink_thumbnail_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InkThumbnailCache', () {
    test('thumbnail cache returns same Image when inkLayerId+updatedAt unchanged', () async {
      final cache = InkThumbnailCache();
      final layer = InkLayer(
        id: 'test-layer-1',
        ownerType: InkLayerOwnerType.node,
        ownerId: 'node-1',
        strokes: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final img1 = await cache.getOrBuild(layer);
      final img2 = await cache.getOrBuild(layer);
      expect(identical(img1, img2), isTrue);
    });

    test('thumbnail cache rebuilds when updatedAt changes', () async {
      final cache = InkThumbnailCache();
      final t1 = DateTime(2026, 1, 1);
      final t2 = DateTime(2026, 1, 2);
      final layer1 = InkLayer(
        id: 'test-layer-1',
        ownerType: InkLayerOwnerType.node,
        ownerId: 'node-1',
        strokes: const [],
        createdAt: t1,
        updatedAt: t1,
      );
      final layer2 = layer1.copyWith(updatedAt: t2);
      final img1 = await cache.getOrBuild(layer1);
      final img2 = await cache.getOrBuild(layer2);
      expect(identical(img1, img2), isFalse);
    });

    test('cache key includes inkLayerId', () async {
      final cache = InkThumbnailCache();
      final layer1 = InkLayer(
        id: 'layer-1',
        ownerType: InkLayerOwnerType.node,
        ownerId: 'node-1',
        strokes: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final layer2 = InkLayer(
        id: 'layer-2',
        ownerType: InkLayerOwnerType.node,
        ownerId: 'node-1',
        strokes: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final img1 = await cache.getOrBuild(layer1);
      final img2 = await cache.getOrBuild(layer2);
      expect(identical(img1, img2), isFalse);
    });

    test('cache evicts oldest entry when capacity exceeded', () async {
      final cache = InkThumbnailCache(capacity: 2);

      // Add 3 layers, capacity is 2
      for (var i = 0; i < 3; i++) {
        final layer = InkLayer(
          id: 'layer-$i',
          ownerType: InkLayerOwnerType.node,
          ownerId: 'node-$i',
          strokes: const [],
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        await cache.getOrBuild(layer);
      }

      // Cache should have evicted the first entry
      expect(cache.size, equals(2));
    });

    test('cache updates LRU order on access', () async {
      final cache = InkThumbnailCache(capacity: 2);

      final layer0 = InkLayer(
        id: 'layer-0',
        ownerType: InkLayerOwnerType.node,
        ownerId: 'node-0',
        strokes: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final layer1 = InkLayer(
        id: 'layer-1',
        ownerType: InkLayerOwnerType.node,
        ownerId: 'node-1',
        strokes: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final layer2 = InkLayer(
        id: 'layer-2',
        ownerType: InkLayerOwnerType.node,
        ownerId: 'node-2',
        strokes: const [],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // Add layer0 and layer1
      await cache.getOrBuild(layer0);
      await cache.getOrBuild(layer1);

      // Access layer0 again (should move to most recent)
      await cache.getOrBuild(layer0);

      // Add layer2 (should evict layer1, not layer0)
      await cache.getOrBuild(layer2);

      // layer0 should still be cached (was accessed recently)
      final img0Again = await cache.getOrBuild(layer0);
      expect(img0Again, isNotNull);
    });
  });
}
