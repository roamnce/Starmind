import 'dart:ui' as ui;

/// 瓦片缓存条目
class TileEntry {
  final ui.Image image;
  final DateTime lastAccess;

  TileEntry({required this.image, required this.lastAccess});
}

/// 瓦片缓存管理器，使用 LRU 淘汰策略
class TileManager {
  /// 瓦片缓存: key = "pageIndex_tileX_tileY_zoomBucket"
  final Map<String, TileEntry> _cache = {};

  /// LRU 队列
  final List<String> _lruOrder = [];

  /// 最大缓存条目数 (约 100-200MB 内存)
  static const int maxEntries = 20;

  /// 缩放分桶量子 (每 0.5x 一个桶)
  static const double zoomQuantum = 0.5;

  /// 获取 LRU 队列（仅供测试）
  List<String> get lruOrder => List.unmodifiable(_lruOrder);

  /// 将缩放值分桶
  int bucketizeZoom(double zoom) => (zoom / zoomQuantum).round();

  /// 获取当前缓存大小
  int get size => _cache.length;

  /// 生成缓存键
  String _makeKey(int pageIndex, int tileX, int tileY, int zoomBucket) {
    return '${pageIndex}_${tileX}_${tileY}_$zoomBucket';
  }

  /// 获取瓦片
  TileEntry? getTile(int pageIndex, int tileX, int tileY, double zoom) {
    final zoomBucket = bucketizeZoom(zoom);
    final key = _makeKey(pageIndex, tileX, tileY, zoomBucket);

    if (_cache.containsKey(key)) {
      _updateLru(key);
      return _cache[key];
    }
    return null;
  }

  /// 存储瓦片
  void storeTile(int pageIndex, int tileX, int tileY, double zoom, ui.Image image) {
    final zoomBucket = bucketizeZoom(zoom);
    final key = _makeKey(pageIndex, tileX, tileY, zoomBucket);

    // LRU 淘汰
    if (_cache.length >= maxEntries && !_cache.containsKey(key)) {
      _evictOldest();
    }

    _cache[key] = TileEntry(image: image, lastAccess: DateTime.now());
    _updateLru(key);
  }

  /// 更新 LRU 顺序
  void updateLru(String key) {
    _updateLru(key);
  }

  void _updateLru(String key) {
    _lruOrder.remove(key);
    _lruOrder.add(key);

    // LRU 淘汰：当队列超过最大条目数时淘汰最旧的
    while (_lruOrder.length > maxEntries) {
      _evictOldest();
    }
  }

  /// 淘汰最旧的条目
  void _evictOldest() {
    if (_lruOrder.isEmpty) return;
    final oldest = _lruOrder.removeAt(0);
    _cache.remove(oldest)?.image.dispose();
  }

  /// 清除所有缓存
  void clear() {
    for (final entry in _cache.values) {
      entry.image.dispose();
    }
    _cache.clear();
    _lruOrder.clear();
  }
}
