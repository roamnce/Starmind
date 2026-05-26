// test/pdf/static_picture_cache_test.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/static_picture_cache.dart';

void main() {
  group('StaticPictureCache', () {
    late StaticPictureCache cache;

    setUp(() {
      cache = StaticPictureCache();
    });

    tearDown(() {
      cache.dispose();
    });

    test('stores and retrieves picture', () async {
      // 创建测试 Picture
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint()..color = Colors.red);
      final picture = recorder.endRecording();

      cache.store('page-0', 1.0, picture);

      final retrieved = cache.lookup('page-0', 1.0);

      expect(retrieved, isNotNull);
      expect(retrieved, same(picture));
    });

    test('returns null for missing entry', () {
      final result = cache.lookup('nonexistent', 1.0);
      expect(result, isNull);
    });

    test('zoom buckets work correctly', () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
      final picture = recorder.endRecording();

      cache.store('page-0', 1.2, picture);

      // 1.2 / 0.5 = 2.4 → bucket 2
      // 查询 0.9 / 0.5 = 1.8 → bucket 2 (相同)
      final result = cache.lookup('page-0', 0.9);

      expect(result, same(picture));
    });

    test('LRU eviction removes oldest entry', () async {
      // 填充到最大容量
      for (int i = 0; i < StaticPictureCache.maxEntries; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(Rect.fromLTWH(0, 0, 100, 100), Paint());
        final picture = recorder.endRecording();
        cache.store('page-$i', 1.0, picture);
      }

      // 添加一个新条目，应触发淘汰
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
      final newPicture = recorder.endRecording();
      cache.store('page-new', 1.0, newPicture);

      // 最旧的 page-0 应该被淘汰
      expect(cache.lookup('page-0', 1.0), isNull);
      expect(cache.lookup('page-new', 1.0), isNotNull);
    });

    test('LRU updates on access', () async {
      // 添加两个条目
      for (int i = 0; i < 2; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(Rect.fromLTWH(0, 0, 100, 100), Paint());
        final picture = recorder.endRecording();
        cache.store('page-$i', 1.0, picture);
      }

      // 访问 page-0，使其成为最新
      cache.lookup('page-0', 1.0);

      // 填充剩余容量
      for (int i = 2; i < StaticPictureCache.maxEntries; i++) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(Rect.fromLTWH(0, 0, 100, 100), Paint());
        final picture = recorder.endRecording();
        cache.store('page-$i', 1.0, picture);
      }

      // 添加新条目，page-1 应该被淘汰（因为它最旧且未被访问）
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(const Rect.fromLTWH(0, 0, 100, 100), Paint());
      final newPicture = recorder.endRecording();
      cache.store('page-new', 1.0, newPicture);

      // page-0 被访问过，应该还在
      expect(cache.lookup('page-0', 1.0), isNotNull);
    });
  });
}
