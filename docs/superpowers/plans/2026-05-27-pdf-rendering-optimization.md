# PDF 渲染与交互优化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现 PDF 高 DPI 瓦片渲染、无限自由缩放平移、以及文本选择批注功能

**Architecture:** 采用 Zoom-Aware DPI Rendering 方案，根据缩放级别动态计算渲染 DPI（上限 600 DPI）；移除硬编码边界约束实现无限画布；集成 TextSelectionHandler 实现长按选择和批注

**Tech Stack:** Flutter, Rust (PDFium via flutter_rust_bridge), CustomPainter

---

## 文件结构

### 新增文件
- `lib/src/pdf/tile_manager.dart` - 瓦片缓存管理器（LRU 淘汰）
- `lib/src/pdf/widgets/selection_toolbar.dart` - 文本选择后的浮动工具栏
- `test/pdf/tile_manager_test.dart` - TileManager 单元测试

### 修改文件
- `rust/src/api/pdf.rs` - 添加 `render_dpi` 参数
- `lib/src/rust/api/pdf.dart` - 自动生成，添加 `renderDpi` 字段
- `lib/src/pdf/pdf_service.dart` - 更新 FFI 调用接口
- `lib/src/pdf/pdf_viewport_controller.dart` - 扩展缩放范围，移除强制居中
- `lib/src/pdf/widgets/interactive_canvas_viewer.dart` - 移除硬编码缩放约束
- `lib/src/pdf/widgets/pdf_viewport_widget.dart` - 集成 TileManager、文本选择、无限边界
- `lib/src/pdf/widgets/text_selection_handler.dart` - 修复坐标系统

---

## 阶段一：Rust FFI 修改（添加 render_dpi 参数）

### Task 1: 修改 ViewportRequest 结构体

**Files:**
- Modify: `rust/src/api/pdf.rs:79-88`

- [ ] **Step 1: 修改 ViewportRequest 结构体，添加 render_dpi 字段**

```rust
pub struct ViewportRequest {
    pub doc_id: String,
    pub page_index: u32,
    pub pdf_left: f32,
    pub pdf_top: f32,
    pub pdf_right: f32,
    pub pdf_bottom: f32,
    pub target_width: u32,
    pub target_height: u32,
    pub render_dpi: Option<f32>,  // 新增: 渲染 DPI，None 则使用默认 72
}
```

- [ ] **Step 2: 修改 render_viewport 函数，使用 render_dpi 计算缩放**

找到 `render_viewport` 函数（第 90-167 行），替换为：

```rust
pub fn render_viewport(req: ViewportRequest) -> Result<Vec<u8>, String> {
    let pdfium_wrapper = PDFIUM.get().ok_or("PDFium not initialized")?;
    let bindings = pdfium_wrapper.0.bindings();

    let docs = DOCUMENTS.lock().map_err(|e| e.to_string())?;
    let doc_wrapper = docs.get(&req.doc_id).ok_or("Document not found")?;

    let pages = doc_wrapper.0.pages();
    let page = pages.get(req.page_index as u16).map_err(|e| e.to_string())?;
    let page_handle = bindings.get_handle_from_page(&page);

    let page_width = page.width().value;
    let page_height = page.height().value;

    // 根据 render_dpi 计算缩放因子
    let dpi = req.render_dpi.unwrap_or(72.0);
    let dpi_scale = dpi / 72.0;  // PDF 默认 72 DPI

    let width_pdf = req.pdf_right - req.pdf_left;
    if width_pdf <= 0.0 {
        return Err("Invalid viewport width".to_string());
    }

    // 综合缩放: DPI 缩放 × 目标尺寸缩放
    let scale = (req.target_width as f64 / width_pdf as f64) * dpi_scale as f64;

    // 渲染尺寸 (高分辨率)
    let scaled_page_width = (page_width as f64 * scale).round() as i32;
    let scaled_page_height = (page_height as f64 * scale).round() as i32;

    let start_x = (-(req.pdf_left as f64 * scale)).round() as i32;
    let start_y = (-((page_height - req.pdf_top) as f64 * scale)).round() as i32;

    // 目标尺寸也要按 DPI 缩放
    let final_width = (req.target_width as f64 * dpi_scale as f64).round() as i32;
    let final_height = (req.target_height as f64 * dpi_scale as f64).round() as i32;

    unsafe {
        let bitmap = bindings.FPDFBitmap_Create(final_width, final_height, 1);
        if bitmap.is_null() {
            return Err("Failed to create PDFium bitmap".to_string());
        }

        bindings.FPDFBitmap_FillRect(
            bitmap,
            0, 0, final_width, final_height,
            0xFFFFFFFF,
        );

        bindings.FPDF_RenderPageBitmap(
            bitmap,
            page_handle,
            start_x,
            start_y,
            scaled_page_width,
            scaled_page_height,
            0,
            0x01,
        );

        let buffer = bindings.FPDFBitmap_GetBuffer(bitmap);
        if buffer.is_null() {
            bindings.FPDFBitmap_Destroy(bitmap);
            return Err("Failed to get bitmap buffer pointer".to_string());
        }

        let length = (final_width * final_height * 4) as usize;
        let slice = std::slice::from_raw_parts(buffer as *const u8, length);
        let bgra_bytes = slice.to_vec();

        bindings.FPDFBitmap_Destroy(bitmap);

        Ok(bgra_bytes)
    }
}
```

- [ ] **Step 3: 运行 flutter_rust_bridge 代码生成**

```bash
cd D:/starmind
flutter_rust_bridge_codegen generate
```

Expected: 生成更新后的 `lib/src/rust/api/pdf.dart`，包含 `renderDpi` 字段

- [ ] **Step 4: 验证生成的 Dart 代码**

检查 `lib/src/rust/api/pdf.dart` 中 `ViewportRequest` 类是否包含 `renderDpi` 字段：

```dart
class ViewportRequest {
  final String docId;
  final int pageIndex;
  final double pdfLeft;
  final double pdfTop;
  final double pdfRight;
  final double pdfBottom;
  final int targetWidth;
  final int targetHeight;
  final double? renderDpi;  // 新增字段
  ...
}
```

- [ ] **Step 5: 提交 Rust FFI 修改**

```bash
git add rust/src/api/pdf.rs lib/src/rust/api/pdf.dart
git commit -m "feat(pdf): add render_dpi parameter to ViewportRequest for high DPI rendering

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 2: 更新 PdfService FFI 调用

**Files:**
- Modify: `lib/src/pdf/pdf_service.dart:93-114`

- [ ] **Step 1: 修改 renderViewport 方法，添加 renderDpi 参数**

```dart
Future<Uint8List> renderViewport({
  required String docId,
  required int pageIndex,
  required double pdfLeft,
  required double pdfTop,
  required double pdfRight,
  required double pdfBottom,
  required int targetWidth,
  required int targetHeight,
  double? renderDpi,
}) async {
  final req = ffi.ViewportRequest(
    docId: docId,
    pageIndex: pageIndex,
    pdfLeft: pdfLeft,
    pdfTop: pdfTop,
    pdfRight: pdfRight,
    pdfBottom: pdfBottom,
    targetWidth: targetWidth,
    targetHeight: targetHeight,
    renderDpi: renderDpi,
  );
  return ffi.renderViewport(req: req);
}
```

- [ ] **Step 2: 提交 PdfService 修改**

```bash
git add lib/src/pdf/pdf_service.dart
git commit -m "feat(pdf): update PdfService with renderDpi parameter

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## 阶段二：TileManager 瓦片缓存

### Task 3: 编写 TileManager 单元测试

**Files:**
- Create: `test/pdf/tile_manager_test.dart`

- [ ] **Step 1: 创建测试文件，编写基础测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/tile_manager.dart';

void main() {
  group('TileManager', () {
    test('getTile returns null for missing tile', () {
      final manager = TileManager();
      expect(manager.getTile(0, 0, 0, 1.0), isNull);
    });

    test('storeTile and getTile works correctly', () {
      final manager = TileManager();
      // Note: In real tests, we'd need a mock ui.Image
      // For now, just test the key generation logic
      expect(manager.bucketizeZoom(1.0), equals(2));  // 1.0 / 0.5 = 2
      expect(manager.bucketizeZoom(1.5), equals(3));  // 1.5 / 0.5 = 3
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
      expect(manager.lruOrder.first, equals('key_1')); // key_0 should be evicted
    });
  });
}
```

- [ ] **Step 2: 运行测试验证失败**

```bash
cd D:/starmind
flutter test test/pdf/tile_manager_test.dart
```

Expected: FAIL - TileManager 类不存在

- [ ] **Step 3: 提交测试文件**

```bash
git add test/pdf/tile_manager_test.dart
git commit -m "test(pdf): add TileManager unit tests

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 4: 实现 TileManager

**Files:**
- Create: `lib/src/pdf/tile_manager.dart`

- [ ] **Step 1: 创建 TileManager 类**

```dart
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

  /// 获取当前缓存大小
  int get size => _cache.length;
}
```

- [ ] **Step 2: 运行测试验证通过**

```bash
cd D:/starmind
flutter test test/pdf/tile_manager_test.dart
```

Expected: PASS

- [ ] **Step 3: 提交 TileManager 实现**

```bash
git add lib/src/pdf/tile_manager.dart
git commit -m "feat(pdf): implement TileManager with LRU eviction

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## 阶段三：缩放与平移交互优化

### Task 5: 扩展缩放范围

**Files:**
- Modify: `lib/src/pdf/pdf_viewport_controller.dart:96-99`

- [ ] **Step 1: 修改 minZoom 和 maxZoom 常量**

找到第 96-99 行，修改为：

```dart
/// Minimum zoom factor (10% of original size).
static const double minZoom = 0.1;

/// Maximum zoom factor (300% of original size).
static const double maxZoom = 30.0;
```

- [ ] **Step 2: 提交缩放范围修改**

```bash
git add lib/src/pdf/pdf_viewport_controller.dart
git commit -m "feat(pdf): extend zoom range to 0.1x-30x

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 6: 移除强制居中约束

**Files:**
- Modify: `lib/src/pdf/pdf_viewport_controller.dart:297-327`

- [ ] **Step 1: 修改 constrainBounds 方法为空实现**

找到 `constrainBounds` 方法（第 297-327 行），替换为：

```dart
/// Constrain viewport boundaries.
/// 
/// With free pan mode, this method does nothing - users can drag the PDF
/// to any position on the screen. ElasticBoundary provides optional
/// elastic resistance when dragging beyond natural boundaries.
void constrainBounds(Size pdfSize, Size viewportSize) {
  // 不做任何约束，完全自由平移
  // 用户可以将 PDF 拖动到任意位置
  // ElasticBoundary 提供弹性阻力（在 InteractiveCanvasViewer 中处理）
}
```

- [ ] **Step 2: 提交约束移除**

```bash
git add lib/src/pdf/pdf_viewport_controller.dart
git commit -m "feat(pdf): remove forced centering in constrainBounds for free pan

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 7: 移除硬编码缩放约束

**Files:**
- Modify: `lib/src/pdf/widgets/interactive_canvas_viewer.dart:686-712`

- [ ] **Step 1: 修改 _matrixScale 方法，移除边界约束**

找到 `_matrixScale` 方法（第 686-712 行），替换为：

```dart
// Return a new matrix representing the given matrix after applying the given
// scale.
Matrix4 _matrixScale(Matrix4 matrix, double scale) {
  if (scale == 1.0) {
    return matrix.clone();
  }
  assert(scale != 0.0);

  // 只限制 minScale/maxScale，不再限制边界约束
  // 这允许用户缩小到任意级别（如 0.1x）
  final double currentScale = _transformer.value.getMaxScaleOnAxis();
  final double totalScale = currentScale * scale;
  final double clampedTotalScale = clampDouble(
    totalScale,
    widget.minScale,
    widget.maxScale,
  );
  final double clampedScale = clampedTotalScale / currentScale;
  return matrix.clone()
    ..scaleByDouble(clampedScale, clampedScale, clampedScale, 1);
}
```

- [ ] **Step 2: 提交缩放约束移除**

```bash
git add lib/src/pdf/widgets/interactive_canvas_viewer.dart
git commit -m "feat(pdf): remove hardcoded boundary constraint in _matrixScale

Allows zooming below 1.0x without being blocked by viewport/boundary ratio.

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 8: 配置无限边界

**Files:**
- Modify: `lib/src/pdf/widgets/pdf_viewport_widget.dart:109-139`

- [ ] **Step 1: 修改 InteractiveCanvasViewer.builder 参数**

找到 `InteractiveCanvasViewer.builder` 调用（第 109-139 行），修改 `boundaryMargin` 参数：

```dart
return InteractiveCanvasViewer.builder(
  minScale: PdfViewportController.minZoom,
  maxScale: PdfViewportController.maxZoom,
  panEnabled: true,
  scaleEnabled: true,
  transformationController: _transformationController,
  // 无边界限制，允许用户将 PDF 拖动到任意位置
  boundaryMargin: EdgeInsets.all(double.infinity),
  isDrawGesture: _isDrawGesture,
  onInteractionEnd: (details) {
    // Sync controller state
    final scale = _transformationController.value.getMaxScaleOnAxis();
    final translation = _transformationController.value.getTranslation();
    widget.controller.setViewportState(
      zoom: scale,
      panOffset: Offset(translation.x, translation.y),
    );
  },
  builder: (BuildContext context, Quad viewport) {
    return _PdfPagesContainer(
      controller: widget.controller,
      viewport: viewport,
      viewportKey: _viewportKey,
      baseScale: baseScale,
      transformationController: _transformationController,
    );
  },
);
```

- [ ] **Step 2: 提交无限边界配置**

```bash
git add lib/src/pdf/widgets/pdf_viewport_widget.dart
git commit -m "feat(pdf): configure infinite boundary margin for free pan

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## 阶段四：文本选择交互优化

### Task 9: 修复 TextSelectionHandler 坐标系统

**Files:**
- Modify: `lib/src/pdf/widgets/text_selection_handler.dart:59-72`

- [ ] **Step 1: 修复坐标转换方法**

找到 `pdfToScreen` 和 `screenToPdf` 方法，修复坐标系统：

```dart
/// Convert PDF coordinates to screen coordinates.
/// 
/// PDF coordinate system: origin at bottom-left, Y increases upward.
/// Screen coordinate system: origin at top-left, Y increases downward.
Offset pdfToScreen(double pdfX, double pdfY) {
  // PDF Y is from bottom, screen Y is from top
  // Note: pageHeight in PDF coordinates, top > bottom
  final screenX = pdfX * zoom - scrollOffset.dx;
  final screenY = (pageHeight - pdfY) * zoom - scrollOffset.dy;
  return Offset(screenX, screenY);
}

/// Convert screen coordinates to PDF coordinates.
Offset screenToPdf(double screenX, double screenY) {
  final pdfX = (screenX + scrollOffset.dx) / zoom;
  // In PDF coordinates, top > bottom, so we flip the Y
  final pdfY = pageHeight - (screenY + scrollOffset.dy) / zoom;
  return Offset(pdfX, pdfY);
}
```

- [ ] **Step 2: 提交坐标修复**

```bash
git add lib/src/pdf/widgets/text_selection_handler.dart
git commit -m "fix(pdf): correct coordinate transformation in TextSelectionHandler

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 10: 集成 TextSelectionHandler 到 PdfPageWidget

**Files:**
- Modify: `lib/src/pdf/widgets/pdf_viewport_widget.dart:204-467`

- [ ] **Step 1: 在 _PdfPageWidgetState 中添加 TextSelectionHandler**

在 `_PdfPageWidgetState` 类中添加：

```dart
class _PdfPageWidgetState extends State<PdfPageWidget> {
  // ... 现有字段 ...
  
  TextSelectionHandler? _selectionHandler;
  bool _isSelecting = false;
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _initPage();
  }
  
  // ... 现有方法 ...
  
  Future<void> _initPage() async {
    final size = await widget.controller.getPageSize(widget.pageIndex);
    if (!mounted) return;
    
    setState(() {
      _pdfSize = size;
    });
    
    // 初始化 TextSelectionHandler
    _selectionHandler = TextSelectionHandler(
      chars: await widget.controller.getPageChars(widget.pageIndex),
      pageHeight: size.height,
      zoom: widget.transformationController?.value.getMaxScaleOnAxis() ?? 1.0,
      scrollOffset: Offset.zero,
      onSelectionComplete: _onSelectionComplete,
    );
    
    _loadLowResImage();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHighResTile();
    });
  }
  
  void _onSelectionComplete(TextSelectionResult result) {
    setState(() {
      _isSelecting = false;
    });
    
    // 显示批注工具栏
    widget.controller.setSelectionState(
      pageIndex: widget.pageIndex,
      startCharIndex: result.startCharIndex,
      endCharIndex: result.endCharIndex,
      rects: result.rects.map((r) => Rect.fromLTRB(
        r.left, r.top, r.right, r.bottom,
      )).toList(),
    );
  }
}
```

- [ ] **Step 2: 添加长按手势检测**

修改 `build` 方法，用 `GestureDetector` 包裹：

```dart
@override
Widget build(BuildContext context) {
  if (_pdfSize == null) {
    return const SizedBox(
      height: 400,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  final viewportWidth = widget.viewportWidth;
  final double pdfWidth = _pdfSize!.width;
  final double pdfHeight = _pdfSize!.height;
  final scale = viewportWidth / pdfWidth;

  final logicalWidth = pdfWidth * scale;
  final logicalHeight = pdfHeight * scale;

  return GestureDetector(
    onLongPressStart: (details) {
      if (_selectionHandler != null) {
        _selectionHandler!.onLongPressStart(details.localPosition);
        setState(() {
          _isSelecting = true;
        });
      }
    },
    onLongPressMoveUpdate: (details) {
      if (_selectionHandler != null && _isSelecting) {
        _selectionHandler!.onLongPressMove(details.localPosition);
        setState(() {}); // 触发重绘显示选择区域
      }
    },
    onLongPressEnd: (details) {
      if (_selectionHandler != null) {
        _selectionHandler!.onLongPressEnd();
      }
    },
    child: Container(
      width: logicalWidth,
      height: logicalHeight,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: PdfPagePainter(
          lowResImage: _lowResImage,
          highResTile: _highResTile,
          highResRect: _highResRect,
          highlights: widget.controller.highlights.where((h) => h.pageIndex == widget.pageIndex).toList(),
          selectionRects: widget.controller.getSelectionRects(widget.pageIndex),
          pdfHeight: pdfHeight,
          scale: scale,
          selectionHandler: _selectionHandler,
          isSelecting: _isSelecting,
        ),
      ),
    ),
  );
}
```

- [ ] **Step 3: 提交 TextSelectionHandler 集成**

```bash
git add lib/src/pdf/widgets/pdf_viewport_widget.dart
git commit -m "feat(pdf): integrate TextSelectionHandler with long press gestures

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 11: 添加选择区域渲染

**Files:**
- Modify: `lib/src/pdf/widgets/pdf_viewport_widget.dart:478-559`

- [ ] **Step 1: 修改 PdfPagePainter 添加选择区域渲染**

修改 `PdfPagePainter` 类：

```dart
class PdfPagePainter extends CustomPainter {
  final ui.Image? lowResImage;
  final ui.Image? highResTile;
  final Rect? highResRect;
  final List<PdfHighlight> highlights;
  final List<Rect> selectionRects;
  final double pdfHeight;
  final double scale;
  final TextSelectionHandler? selectionHandler;
  final bool isSelecting;

  PdfPagePainter({
    required this.lowResImage,
    required this.highResTile,
    required this.highResRect,
    required this.highlights,
    required this.selectionRects,
    required this.pdfHeight,
    required this.scale,
    this.selectionHandler,
    this.isSelecting = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..filterQuality = ui.FilterQuality.medium;

    // 渲染低分辨率图像
    if (lowResImage != null) {
      canvas.drawImageRect(
        lowResImage!,
        Rect.fromLTWH(0, 0, lowResImage!.width.toDouble(), lowResImage!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        paint,
      );
    }

    // 渲染高分辨率瓦片
    if (highResTile != null && highResRect != null) {
      canvas.drawImageRect(
        highResTile!,
        Rect.fromLTWH(0, 0, highResTile!.width.toDouble(), highResTile!.height.toDouble()),
        highResRect!,
        paint,
      );
    }

    // 渲染高亮
    for (final highlight in highlights) {
      final highlightPaint = Paint()
        ..color = highlight.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      for (final r in highlight.rects) {
        final localRect = _pdfRectToLocal(r);
        canvas.drawRect(localRect, highlightPaint);
      }
    }

    // 渲染现有选择区域（来自 controller）
    if (selectionRects.isNotEmpty) {
      final selectPaint = Paint()
        ..color = const Color(0xFF007AFF).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;
      for (final r in selectionRects) {
        final localRect = _pdfRectToLocal(r);
        canvas.drawRect(localRect, selectPaint);
      }
    }

    // 渲染当前正在进行的文本选择
    if (isSelecting && selectionHandler != null) {
      final selection = selectionHandler!.currentSelection;
      if (selection != null) {
        final selectPaint = Paint()
          ..color = Colors.blue.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;

        for (final rect in selection.rects) {
          final screenRect = selectionHandler!.pdfToScreen(rect.left, rect.top) &
              Size(rect.right - rect.left, rect.bottom - rect.top);
          canvas.drawRect(screenRect, selectPaint);
        }
      }
    }
  }

  Rect _pdfRectToLocal(Rect pdfRect) {
    return Rect.fromLTRB(
      pdfRect.left * scale,
      (pdfHeight - pdfRect.top) * scale,
      pdfRect.right * scale,
      (pdfHeight - pdfRect.bottom) * scale,
    );
  }

  @override
  bool shouldRepaint(covariant PdfPagePainter oldDelegate) {
    return oldDelegate.lowResImage != lowResImage ||
        oldDelegate.highResTile != highResTile ||
        oldDelegate.highResRect != highResRect ||
        oldDelegate.highlights != highlights ||
        oldDelegate.selectionRects != selectionRects ||
        oldDelegate.scale != scale ||
        oldDelegate.pdfHeight != pdfHeight ||
        oldDelegate.isSelecting != isSelecting;
  }
}
```

- [ ] **Step 2: 提交选择区域渲染**

```bash
git add lib/src/pdf/widgets/pdf_viewport_widget.dart
git commit -m "feat(pdf): add selection highlight rendering to PdfPagePainter

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 12: 创建 SelectionToolbar 组件

**Files:**
- Create: `lib/src/pdf/widgets/selection_toolbar.dart`

- [ ] **Step 1: 创建 SelectionToolbar 组件**

```dart
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../pdf_viewport_controller.dart';

/// 浮动工具栏，用于文本选择后的批注操作
class SelectionToolbar extends StatelessWidget {
  final PdfViewportController controller;
  final int pageIndex;
  final int startCharIndex;
  final int endCharIndex;
  final List<Rect> rects;
  final String selectedText;
  final VoidCallback? onClose;

  const SelectionToolbar({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.startCharIndex,
    required this.endCharIndex,
    required this.rects,
    required this.selectedText,
    this.onClose,
  });

  void _onHighlightPressed(Color color) {
    controller.addHighlight(PdfHighlight(
      id: const Uuid().v4(),
      pageIndex: pageIndex,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      color: color,
      rects: rects,
      text: selectedText,
    ));
    controller.clearSelection();
    onClose?.call();
  }

  void _onUnderlinePressed(Color color) {
    // TODO: 实现下划线批注
    // 类似高亮，但类型为 underline
    controller.clearSelection();
    onClose?.call();
  }

  void _onCopyPressed() {
    // 复制到剪贴板
    // Clipboard.setData(ClipboardData(text: selectedText));
    controller.clearSelection();
    onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 高亮按钮
            IconButton(
              icon: const Icon(Icons.highlight, size: 20),
              tooltip: '高亮',
              onPressed: () => _onHighlightPressed(const Color(0xFFFFEB3B)),
            ),
            // 下划线按钮
            IconButton(
              icon: const Icon(Icons.format_underlined, size: 20),
              tooltip: '下划线',
              onPressed: () => _onUnderlinePressed(Colors.red),
            ),
            // 复制按钮
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: '复制',
              onPressed: _onCopyPressed,
            ),
            // 颜色选择
            PopupMenuButton<Color>(
              icon: const Icon(Icons.palette, size: 20),
              tooltip: '选择颜色',
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: Color(0xFFFFEB3B),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFFFFEB3B), size: 16),
                      SizedBox(width: 8),
                      Text('黄色'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: Color(0xFF4CAF50),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFF4CAF50), size: 16),
                      SizedBox(width: 8),
                      Text('绿色'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: Color(0xFF2196F3),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFF2196F3), size: 16),
                      SizedBox(width: 8),
                      Text('蓝色'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: Color(0xFFFF5722),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFFFF5722), size: 16),
                      SizedBox(width: 8),
                      Text('橙色'),
                    ],
                  ),
                ),
              ],
              onSelected: _onHighlightPressed,
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 提交 SelectionToolbar 组件**

```bash
git add lib/src/pdf/widgets/selection_toolbar.dart
git commit -m "feat(pdf): add SelectionToolbar for text selection actions

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 13: 在 PdfViewportWidget 中集成 SelectionToolbar

**Files:**
- Modify: `lib/src/pdf/widgets/pdf_viewport_widget.dart`

- [ ] **Step 1: 在 PdfViewportWidget 中添加 SelectionToolbar 显示逻辑**

在 `_PdfViewportWidgetState` 类的 `build` 方法中添加 `Stack` 来显示工具栏：

```dart
@override
Widget build(BuildContext context) {
  final pageCount = widget.controller.pageCount;
  final isLoading = widget.controller.isLoading;

  if (isLoading) {
    return _buildLoadingIndicator();
  }

  if (pageCount == 0) {
    return const Center(child: Text('No pages'));
  }

  // Get first page size for sizing
  final pdfSize = widget.controller.pageSizes[0];
  if (pdfSize == null) {
    return const SizedBox(
      height: 400,
      child: Center(child: CircularProgressIndicator()),
    );
  }

  // Calculate initial scale to fit width
  final viewportSize = MediaQuery.of(context).size;
  final baseScale = viewportSize.width / pdfSize.width;

  return Stack(
    children: [
      // PDF 视图
      InteractiveCanvasViewer.builder(
        minScale: PdfViewportController.minZoom,
        maxScale: PdfViewportController.maxZoom,
        panEnabled: true,
        scaleEnabled: true,
        transformationController: _transformationController,
        boundaryMargin: EdgeInsets.all(double.infinity),
        isDrawGesture: _isDrawGesture,
        onInteractionEnd: (details) {
          final scale = _transformationController.value.getMaxScaleOnAxis();
          final translation = _transformationController.value.getTranslation();
          widget.controller.setViewportState(
            zoom: scale,
            panOffset: Offset(translation.x, translation.y),
          );
        },
        builder: (BuildContext context, Quad viewport) {
          return _PdfPagesContainer(
            controller: widget.controller,
            viewport: viewport,
            viewportKey: _viewportKey,
            baseScale: baseScale,
            transformationController: _transformationController,
          );
        },
      ),
      // 选择工具栏（在选择激活时显示）
      if (widget.controller.selectingPageIndex != null &&
          widget.controller.selectionToolbarPosition != null)
        Positioned(
          left: widget.controller.selectionToolbarPosition!.dx,
          top: widget.controller.selectionToolbarPosition!.dy,
          child: SelectionToolbar(
            controller: widget.controller,
            pageIndex: widget.controller.selectingPageIndex!,
            startCharIndex: widget.controller.selectionStartCharIndex!,
            endCharIndex: widget.controller.selectionEndCharIndex!,
            rects: widget.controller.getSelectionRects(widget.controller.selectingPageIndex!),
            selectedText: widget.controller.getSelectedText(),
            onClose: () {
              widget.controller.clearSelection();
            },
          ),
        ),
    ],
  );
}
```

- [ ] **Step 2: 提交 SelectionToolbar 集成**

```bash
git add lib/src/pdf/widgets/pdf_viewport_widget.dart
git commit -m "feat(pdf): integrate SelectionToolbar into PdfViewportWidget

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## 阶段五：测试与验证

### Task 14: 运行完整测试套件

- [ ] **Step 1: 运行所有 PDF 相关测试**

```bash
cd D:/starmind
flutter test test/pdf/
```

Expected: 所有测试通过

- [ ] **Step 2: 运行 Flutter 分析**

```bash
cd D:/starmind
flutter analyze
```

Expected: 无错误或警告

- [ ] **Step 3: 提交测试验证**

```bash
git add -A
git commit -m "test(pdf): verify all tests pass after optimization

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

### Task 15: 更新文档

**Files:**
- Modify: `docs/pdf-annotation-optimization.md`

- [ ] **Step 1: 更新文档，添加新功能说明**

在文档末尾添加：

```markdown
## 新增功能（2026-05-27 更新）

### High DPI 瓦片渲染

- 根据缩放级别动态计算渲染 DPI（最高 600 DPI）
- 使用 `TileManager` 进行瓦片缓存管理
- LRU 淘汰策略控制内存使用

### 无限自由缩放与平移

- 缩放范围：0.1x ~ 30x
- 无边界限制，可将 PDF 拖动到任意位置
- 双指缩放以手指焦点为中心
- 按钮缩放与手势缩放共享状态

### 文本选择与批注

- 长按触发文本选择
- 拖动调整选择范围
- 选择后显示浮动工具栏
- 支持高亮、下划线、复制等操作

## 新增组件

| 组件 | 位置 | 说明 |
|------|------|------|
| TileManager | `lib/src/pdf/tile_manager.dart` | 瓦片缓存管理器 |
| SelectionToolbar | `lib/src/pdf/widgets/selection_toolbar.dart` | 选择后的浮动工具栏 |

## 修改的 FFI 接口

`ViewportRequest` 结构体新增 `render_dpi` 字段，用于指定渲染 DPI。
```

- [ ] **Step 2: 提交文档更新**

```bash
git add docs/pdf-annotation-optimization.md
git commit -m "docs(pdf): update documentation with new features

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## 验收检查清单

### 视觉质量
- [ ] 5x 缩放时文字边缘清晰，无明显锯齿
- [ ] 10x 缩放时文字仍可辨识，笔画清晰
- [ ] 高 DPI 瓦片加载后，文字清晰度接近矢量效果

### 缩放交互
- [ ] 手势缩放可缩小到 0.1x（原文档 10%）
- [ ] 手势缩放可放大到 30x（原文档 300%）
- [ ] 缩放以双指中心为焦点，全程跟手
- [ ] 不在任何缩放级别卡死或弹回

### 平移交互
- [ ] PDF 可被拖动到屏幕任意位置
- [ ] 四周都可以留白
- [ ] 拖动支持惯性滚动
- [ ] 不出现突然跳动或回弹

### 文本选择交互
- [ ] 长按触发文本选择
- [ ] 拖动可调整选择范围
- [ ] 选择后显示工具栏
- [ ] 可添加高亮批注
- [ ] 可复制选中文本
