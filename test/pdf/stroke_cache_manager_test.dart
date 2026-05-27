import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/stroke_cache_manager.dart';

void main() {
  group('StrokeCacheManager', () {
    test('should create picture cache', () {
      final manager = StrokeCacheManager();

      manager.createCacheSynchronously(
        [],
        (canvas, stroke) {},
        const Size(100, 100),
      );

      expect(manager.cachedPicture, isNotNull);
    });

    test('should restore from undo snapshot', () {
      final manager = StrokeCacheManager();

      // Create initial cache
      manager.createCacheSynchronously(
        [],
        (canvas, stroke) {},
        const Size(100, 100),
      );
      manager.saveUndoSnapshot(0);

      // Add more strokes (update cache)
      manager.createCacheSynchronously(
        [],
        (canvas, stroke) {},
        const Size(100, 100),
      );

      // Restore from snapshot
      final restored = manager.tryRestoreFromUndoSnapshot(0);
      expect(restored, isTrue);
    });

    test('should invalidate cache when stroke count changes', () {
      final manager = StrokeCacheManager();

      manager.createCacheSynchronously(
        [],
        (canvas, stroke) {},
        const Size(100, 100),
      );

      expect(manager.isCacheValid(0), isTrue);
      expect(manager.isCacheValid(5), isFalse);
    });

    test('should limit undo snapshots to max count', () {
      final manager = StrokeCacheManager();

      // Create many snapshots
      for (int i = 0; i < 15; i++) {
        manager.createCacheSynchronously(
          [],
          (canvas, stroke) {},
          const Size(100, 100),
        );
        manager.saveUndoSnapshot(i);
      }

      // Should only keep last 10 snapshots
      expect(manager.undoSnapshotCount, lessThanOrEqualTo(10));
    });
  });
}
