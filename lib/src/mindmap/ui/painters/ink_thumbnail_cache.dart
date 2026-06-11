// lib/src/mindmap/ui/painters/ink_thumbnail_cache.dart

import 'dart:collection';
import 'dart:ui' as ui;

import '../../ink/ink_layer.dart';
import 'ink_thumbnail_painter.dart';

/// 墨迹缩略图 LRU 缓存。
///
/// 按 `inkLayerId + updatedAt` 组合键缓存 [ui.Image]，
/// 容量默认 100，超出时按 LRU（最近最少使用）策略淘汰。
///
/// 缓存键格式：`{inkLayerId}_{updatedAt.toIso8601String()}`。
class InkThumbnailCache {
  /// 缓存容量。
  final int capacity;

  /// LRU 缓存存储（LinkedHashMap 保证插入顺序）。
  final LinkedHashMap<String, ui.Image> _cache = LinkedHashMap<String, ui.Image>();

  /// 创建缓存实例。
  ///
  /// @param capacity 最大缓存条目数；默认 100。
  InkThumbnailCache({this.capacity = 100});

  /// 当前缓存条目数。
  int get size => _cache.length;

  /// 根据 [InkLayer] 获取或构建缩略图。
  ///
  /// 如果缓存中存在匹配的缩略图，直接返回；
  /// 否则调用 [InkThumbnailPainter.buildThumbnail] 构建新缩略图并缓存。
  ///
  /// 缓存键由 `layer.id` 和 `layer.updatedAt.toIso8601String()` 组合，
  /// 确保 updatedAt 变化时触发重新渲染。
  ///
  /// @param layer 墨迹层。
  /// @return 48x48 缩略图 [ui.Image]。
  Future<ui.Image> getOrBuild(InkLayer layer) async {
    final key = _buildKey(layer);

    // 如果缓存命中，移动到末尾（标记为最近使用）
    if (_cache.containsKey(key)) {
      final image = _cache.remove(key)!;
      _cache[key] = image;
      return image;
    }

    // 构建新缩略图
    final image = await InkThumbnailPainter.buildThumbnail(layer);

    // 添加到缓存
    _cache[key] = image;

    // 如果超出容量，淘汰最旧的（LinkedHashMap 头部）
    if (_cache.length > capacity) {
      final oldestKey = _cache.keys.first;
      final oldestImage = _cache.remove(oldestKey)!;
      oldestImage.dispose(); // 释放原生图像资源
    }

    return image;
  }

  /// 清空缓存，释放所有图像资源。
  void clear() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
  }

  /// 构建缓存键。
  ///
  /// 格式：`{layer.id}_{layer.updatedAt.toIso8601String()}`。
  static String _buildKey(InkLayer layer) {
    return '${layer.id}_${layer.updatedAt.toIso8601String()}';
  }
}