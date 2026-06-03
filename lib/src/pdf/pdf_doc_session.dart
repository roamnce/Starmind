import 'dart:collection';
import 'package:flutter/material.dart';
import 'pdf_service.dart';
import '../rust/api/pdf.dart' show CharInfo;

/// LRU Cache with maximum size limit.
class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _cache = LinkedHashMap();

  LruCache({required this.maxSize});

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    // Move to end (most recently used)
    final value = _cache.remove(key);
    if (value != null) {
      _cache[key] = value;
    }
    return value;
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxSize) {
      // Remove oldest (first entry)
      _cache.remove(_cache.keys.first);
    }
    _cache[key] = value;
  }

  void clear() {
    _cache.clear();
  }

  int get length => _cache.length;
}

/// Manages PDF document lifecycle and page data caching.
///
/// Responsibilities:
/// - Load/close PDF documents via PdfService
/// - Cache page sizes and character info with LRU eviction
/// - Track loading state for UI feedback
///
/// This is a deep module: callers only need to call loadDoc/closeDoc
/// and getPageSize/getPageChars. All FFI complexity is hidden inside.
class PdfDocSession extends ChangeNotifier {
  final PdfService _pdfService;

  PdfDocSession({PdfService? pdfService})
      : _pdfService = pdfService ?? PdfService();

  // ── Document State ──

  String? _docId;
  String? get docId => _docId;

  String? _filePath;
  String? get filePath => _filePath;

  int _pageCount = 0;
  int get pageCount => _pageCount;

  // ── Loading State ──

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _loadingStep = '';
  String get loadingStep => _loadingStep;

  String? _loadingError;
  String? get loadingError => _loadingError;

  // ── Page Data Cache ──

  /// Cache for page sizes: pageIndex -> Size(width, height)
  /// Keep all sizes since they're tiny (16 bytes each).
  final Map<int, Size> _pageSizes = {};
  Map<int, Size> get pageSizes => _pageSizes;

  /// Cache for characters with LRU eviction.
  /// Each CharInfo is ~40 bytes, so 10 pages ≈ 100-500 KB depending on content.
  static const int _maxCharCachePages = 10;
  final LruCache<int, List<CharInfo>> _pageCharsLru =
      LruCache<int, List<CharInfo>>(maxSize: _maxCharCachePages);

  /// Expose page chars cache for TextSelectionModel.
  /// Note: Returns a snapshot of cached pages for compatibility.
  /// Use getCachedPageChars() for direct access.
  Map<int, List<CharInfo>> get pageCharsCache {
    // Return empty map - use getCachedPageChars() instead
    // This is kept for API compatibility
    return {};
  }

  // ── Public Interface ──

  /// Loads the PDF document and caches its initial properties.
  /// Each step updates UI so crash point can be identified.
  Future<void> loadDoc(String path) async {
    _filePath = path;
    _isLoading = true;
    _loadingError = null;

    // Step 1: Initialize PDFium engine
    _loadingStep = '步骤1: 初始化PDFium引擎...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      await _pdfService.initialize();
    } catch (e) {
      _loadingError = '步骤1失败: $e';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Step 2: Load document file
    _loadingStep = '步骤2: 加载PDF文件...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      _docId = await _pdfService.loadDocument(path);
    } catch (e) {
      _loadingError = '步骤2失败: $e';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Step 3: Get page count
    _loadingStep = '步骤3: 获取页数...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      _pageCount = await _pdfService.getPageCount(_docId!);
    } catch (e) {
      _loadingError = '步骤3失败: $e';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Step 4a: Prepare to load first page size
    _loadingStep = '步骤4a: 准备获取页面尺寸...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 4b: FFI call to get page size
    _loadingStep = '步骤4b: 调用FFI获取尺寸...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));
    try {
      final sizeTuple = await _pdfService.getPageSize(_docId!, 0);
      _pageSizes[0] = Size(sizeTuple.$1, sizeTuple.$2);
    } catch (e) {
      _loadingError = '步骤4b失败(Dart异常): $e';
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Step 4c: Page size returned successfully
    _loadingStep =
        '步骤4c: 尺寸获取成功 (${_pageSizes[0]?.width.toStringAsFixed(1)}x${_pageSizes[0]?.height.toStringAsFixed(1)})';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 300));

    // Clear caches for new document
    _pageCharsLru.clear();

    // Step 5: About to switch to rendering mode
    _loadingStep = '步骤5: 准备切换到渲染模式...';
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));

    _loadingStep = '加载完成 ✓';
    _isLoading = false;
    notifyListeners();
  }

  /// Closes the document and releases PDFium memory cache.
  Future<void> closeDoc() async {
    if (_docId != null) {
      await _pdfService.closeDocument(_docId!);
      _docId = null;
      _filePath = null;
      _pageCount = 0;
      _loadingStep = '';
      _loadingError = null;
      _isLoading = false;
      _pageSizes.clear();
      _pageCharsLru.clear();
      notifyListeners();
    }
  }

  /// Retrieves the size of a page, reading from cache or FFI.
  Future<Size> getPageSize(int pageIndex) async {
    if (_pageSizes.containsKey(pageIndex)) {
      return _pageSizes[pageIndex]!;
    }
    if (_docId == null) return const Size(0, 0);

    final sizeTuple = await _pdfService.getPageSize(_docId!, pageIndex);
    final size = Size(sizeTuple.$1, sizeTuple.$2);
    _pageSizes[pageIndex] = size;
    return size;
  }

  /// Retrieves page characters, reading from LRU cache or FFI.
  Future<List<CharInfo>> getPageChars(int pageIndex) async {
    // Check LRU cache first
    final cached = _pageCharsLru.get(pageIndex);
    if (cached != null) {
      return cached;
    }
    if (_docId == null) return [];

    final chars = await _pdfService.getPageChars(_docId!, pageIndex);
    _pageCharsLru.put(pageIndex, chars);
    return chars;
  }

  /// Get cached characters for a page (non-blocking, returns cached or empty).
  List<CharInfo> getCachedPageChars(int pageIndex) {
    return _pageCharsLru.get(pageIndex) ?? [];
  }

  /// Clears all cached data (for testing or reset).
  void clearCache() {
    _pageSizes.clear();
    _pageCharsLru.clear();
  }
}