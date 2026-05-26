// lib/src/pdf/static_picture_cache.dart
import 'dart:ui' as ui;

/// 静态内容 Picture 缓存
///
/// 将静态内容（PDF 页面、已保存笔迹）录制为 ui.Picture 缓存，
/// 避免每帧重绘，提升渲染性能。
///
/// 参考：HandWriter _StaticPictureCache
class StaticPictureCache {
  /// LRU 最大条目数
  static const int maxEntries = 6;

  /// 缩放分桶量子（用于量化缩放级别）
  static const double zoomQuantum = 0.5;

  final Map<_CacheKey, ui.Picture> _cache = {};
  final List<_CacheKey> _lruOrder = [];

  /// 查找缓存的 Picture
  ui.Picture? lookup(String pageId, double zoom) {
    final zoomBucket = (zoom / zoomQuantum).round();
    final key = _CacheKey(pageId, zoomBucket);

    if (_cache.containsKey(key)) {
      // LRU 更新：移到最后（最新）
      _lruOrder.remove(key);
      _lruOrder.add(key);
      return _cache[key];
    }
    return null;
  }

  /// 存储 Picture 到缓存
  void store(String pageId, double zoom, ui.Picture picture) {
    final zoomBucket = (zoom / zoomQuantum).round();
    final key = _CacheKey(pageId, zoomBucket);

    // 如果已存在，先移除旧的
    if (_cache.containsKey(key)) {
      _lruOrder.remove(key);
      _cache.remove(key);
    }

    // LRU 淘汰
    while (_cache.length >= maxEntries) {
      final oldest = _lruOrder.removeAt(0);
      _cache.remove(oldest)?.dispose();
    }

    _cache[key] = picture;
    _lruOrder.add(key);
  }

  /// 清除所有缓存
  void clear() {
    for (final picture in _cache.values) {
      picture.dispose();
    }
    _cache.clear();
    _lruOrder.clear();
  }

  /// 释放资源
  void dispose() {
    clear();
  }

  /// 获取当前缓存条目数
  int get length => _cache.length;
}

/// 缓存键
class _CacheKey {
  final String pageId;
  final int zoomBucket;

  _CacheKey(this.pageId, this.zoomBucket);

  @override
  bool operator ==(Object other) =>
      other is _CacheKey && pageId == other.pageId && zoomBucket == other.zoomBucket;

  @override
  int get hashCode => Object.hash(pageId, zoomBucket);
}
