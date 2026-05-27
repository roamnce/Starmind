# PDF High DPI Tile Rendering 设计文档

**日期**: 2026-05-27
**版本**: 1.0
**状态**: 待实现

---

## 一、问题背景

### 1.1 核心问题

PDF 放大后文字模糊，无法达到 GoodNotes/MarginNote 那样的矢量级清晰度。

**用户期望**: 无论放大多少倍，文字都应保持清晰锐利，像查看矢量图一样。

### 1.2 技术背景

#### 当前实现

当前使用 PDFium 的 `FPDF_RenderPageBitmap` 进行光栅化渲染：

```rust
// rust/src/api/pdf.rs
bindings.FPDF_RenderPageBitmap(
    bitmap,
    page_handle,
    start_x,
    start_y,
    scaled_page_width,
    scaled_page_height,
    0,
    0x01,  // anti-aliasing
);
```

问题：渲染结果是固定分辨率的位图，放大后像素化严重。

#### 为何不能直接使用矢量渲染

PDFium 提供 `FPDF_RenderPageSkia` API 可以直接渲染到 Skia Canvas，理论上可以实现矢量级清晰度。但该方案不可行：

1. `FPDF_SKIA_CANVAS` 是一个 opaque 指针，指向 Skia 内部的 `SkCanvas` 类型
2. 必须使用与 PDFium 内部 Skia 版本完全匹配的 Skia 库
3. Flutter 的 Skia/Impeller 与 PDFium 内部 Skia 版本不兼容
4. 无法在 Flutter 和 PDFium 之间共享 Canvas

#### GoodNotes/MarginNote 的实现方式

这类应用并非真正的矢量渲染，而是采用 **High DPI Tile Rendering**：

1. 根据当前缩放级别，动态计算渲染 DPI
2. 渲染足够高分辨率的瓦片，确保放大后依然清晰
3. 使用瓦片缓存策略管理内存

**结论**: High DPI Tile Rendering 是在当前架构下最可行的方案。

---

## 二、设计方案

### 2.1 核心策略

**Zoom-Aware DPI Rendering**

根据缩放级别动态计算渲染 DPI：

| 缩放级别 | 渲染 DPI | 说明 |
|----------|----------|------|
| 1x | 72 DPI | 基础分辨率 |
| 2x | 144 DPI | 中等放大 |
| 3x | 216 DPI | 较大放大 |
| 5x | 360 DPI | 大幅放大 |
| 10x | 600 DPI | 最大放大，上限 |

**DPI 计算公式**:

```dart
double calculateRenderDpi(double zoom, double devicePixelRatio) {
  // 基础 DPI (PDF 默认 72 DPI)
  const double baseDpi = 72.0;
  
  // 有效缩放 = 用户缩放 × 设备像素比
  double effectiveZoom = zoom * devicePixelRatio;
  
  // 渲染 DPI = 基础 DPI × 有效缩放
  double renderDpi = baseDpi * effectiveZoom;
  
  // 上限 600 DPI，避免内存爆炸
  return min(renderDpi, 600.0);
}
```

### 2.2 架构设计

```
┌─────────────────────────────────────────────────────────────────┐
│                      Flutter Layer                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    PdfViewportWidget                      │  │
│  │                                                          │  │
│  │  ┌────────────────┐  ┌────────────────┐                  │  │
│  │  │ ZoomController │  │  TileManager   │                  │  │
│  │  │ - zoom         │  │ - tileCache    │                  │  │
│  │  │ - focalPoint   │  │ - lruEviction  │                  │  │
│  │  └───────┬────────┘  └───────┬────────┘                  │  │
│  │          │                   │                            │  │
│  │          ▼                   ▼                            │  │
│  │  ┌─────────────────────────────────────────────────────┐ │  │
│  │  │              TileRenderScheduler                     │ │  │
│  │  │  - 计算可见区域                                      │ │  │
│  │  │  - 计算渲染 DPI                                     │ │  │
│  │  │  - 调度渲染任务                                     │ │  │
│  │  └─────────────────────┬───────────────────────────────┘ │  │
│  └────────────────────────┼──────────────────────────────────┘  │
│                           │                                     │
├───────────────────────────┼─────────────────────────────────────┤
│                      FFI Layer                                   │
│                           │                                     │
│                           ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    render_viewport()                      │  │
│  │                                                          │  │
│  │  参数:                                                   │  │
│  │  - doc_id: 文档ID                                        │  │
│  │  - page_index: 页码                                      │  │
│  │  - pdf_rect: PDF坐标区域                                 │  │
│  │  - target_width: 目标像素宽度                            │  │
│  │  - target_height: 目标像素高度                           │  │
│  │  - render_dpi: 渲染DPI (新增)                            │  │
│  │                                                          │  │
│  └────────────────────────┬─────────────────────────────────┘  │
│                           │                                     │
├───────────────────────────┼─────────────────────────────────────┤
│                      Rust Layer                                  │
│                           │                                     │
│                           ▼                                     │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    PDFium Rendering                       │  │
│  │                                                          │  │
│  │  1. 根据 render_dpi 计算缩放因子                         │  │
│  │  2. 创建高分辨率 Bitmap                                   │  │
│  │  3. FPDF_RenderPageBitmap 渲染                           │  │
│  │  4. 返回 BGRA 字节数组                                    │  │
│  │                                                          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### 2.3 核心组件

#### 2.3.1 TileManager（瓦片管理器）

**职责**: 管理瓦片的生命周期、缓存和淘汰

```dart
class TileManager {
  // 瓦片缓存: key = "pageIndex_tileX_tileY_zoomBucket"
  final Map<String, TileEntry> _cache = {};
  
  // LRU 队列
  final List<String> _lruOrder = [];
  
  // 最大缓存条目数 (约 100MB 内存)
  static const int maxEntries = 20;
  
  // 缩放分桶量子 (每 0.5x 一个桶)
  static const double zoomQuantum = 0.5;
  
  /// 获取瓦片
  TileEntry? getTile(int pageIndex, int tileX, int tileY, double zoom) {
    final zoomBucket = _bucketizeZoom(zoom);
    final key = '${pageIndex}_${tileX}_${tileY}_$zoomBucket';
    
    if (_cache.containsKey(key)) {
      _updateLru(key);
      return _cache[key];
    }
    return null;
  }
  
  /// 存储瓦片
  void storeTile(int pageIndex, int tileX, int tileY, double zoom, ui.Image image) {
    final zoomBucket = _bucketizeZoom(zoom);
    final key = '${pageIndex}_${tileX}_${tileY}_$zoomBucket';
    
    // LRU 淘汰
    if (_cache.length >= maxEntries && !_cache.containsKey(key)) {
      _evictOldest();
    }
    
    _cache[key] = TileEntry(image: image, lastAccess: DateTime.now());
    _updateLru(key);
  }
  
  int _bucketizeZoom(double zoom) => (zoom / zoomQuantum).round();
  
  void _updateLru(String key) {
    _lruOrder.remove(key);
    _lruOrder.add(key);
  }
  
  void _evictOldest() {
    if (_lruOrder.isEmpty) return;
    final oldest = _lruOrder.removeAt(0);
    _cache.remove(oldest)?.image.dispose();
  }
}

class TileEntry {
  final ui.Image image;
  final DateTime lastAccess;
  
  TileEntry({required this.image, required this.lastAccess});
}
```

#### 2.3.2 TileRenderScheduler（瓦片渲染调度器）

**职责**: 根据可见区域和缩放级别调度瓦片渲染

```dart
class TileRenderScheduler {
  final TileManager _tileManager;
  final PdfViewportController _controller;
  
  // 瓦片大小 (像素)
  static const int tileSize = 512;
  
  // 当前渲染任务
  Future<void>? _currentTask;
  
  /// 调度可见区域的瓦片渲染
  Future<void> scheduleVisibleTiles({
    required Rect visibleRect,
    required double zoom,
    required int pageIndex,
  }) async {
    // 取消之前的任务
    _currentTask?.ignore();
    
    _currentTask = _renderVisibleTiles(
      visibleRect: visibleRect,
      zoom: zoom,
      pageIndex: pageIndex,
    );
    
    await _currentTask;
  }
  
  Future<void> _renderVisibleTiles({
    required Rect visibleRect,
    required double zoom,
    required int pageIndex,
  }) async {
    // 1. 计算可见区域需要哪些瓦片
    final tileCoords = _calculateTileCoords(visibleRect);
    
    // 2. 计算渲染 DPI
    final dpr = WidgetsBinding.instance.window.devicePixelRatio;
    final renderDpi = _calculateRenderDpi(zoom, dpr);
    
    // 3. 对每个瓦片进行检查和渲染
    for (final coord in tileCoords) {
      // 检查缓存
      final cached = _tileManager.getTile(
        pageIndex, coord.x, coord.y, zoom,
      );
      
      if (cached != null) continue; // 已缓存，跳过
      
      // 计算瓦片对应的 PDF 区域
      final pdfRect = _tileToPdfRect(coord, zoom);
      
      // 计算目标像素尺寸
      final targetSize = _calculateTargetSize(renderDpi);
      
      // 调用 Rust 渲染
      final bytes = await PdfService().renderViewport(
        docId: _controller.docId!,
        pageIndex: pageIndex,
        pdfLeft: pdfRect.left,
        pdfTop: pdfRect.top,
        pdfRight: pdfRect.right,
        pdfBottom: pdfRect.bottom,
        targetWidth: targetSize.width,
        targetHeight: targetSize.height,
        renderDpi: renderDpi, // 新增参数
      );
      
      // 转换为 Image
      final image = await _bytesToImage(bytes, targetSize.width, targetSize.height);
      
      // 存入缓存
      _tileManager.storeTile(pageIndex, coord.x, coord.y, zoom, image);
    }
  }
  
  double _calculateRenderDpi(double zoom, double dpr) {
    const double baseDpi = 72.0;
    double effectiveZoom = zoom * dpr;
    double renderDpi = baseDpi * effectiveZoom;
    return min(renderDpi, 600.0); // 上限 600 DPI
  }
}
```

#### 2.3.3 Rust FFI 修改

**修改 `render_viewport` 函数**:

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
    pub render_dpi: Option<f32>,  // 新增: 渲染DPI
}

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

    // 综合缩放: DPI缩放 × 目标尺寸缩放
    let scale = (req.target_width as f64 / width_pdf as f64) * dpi_scale;

    // 渲染尺寸 (高分辨率)
    let scaled_page_width = (page_width as f64 * scale).round() as i32;
    let scaled_page_height = (page_height as f64 * scale).round() as i32;

    let start_x = (-(req.pdf_left as f64 * scale)).round() as i32;
    let start_y = (-((page_height - req.pdf_top) as f64 * scale)).round() as i32;

    // 目标尺寸也要按 DPI 缩放
    let final_width = (req.target_width as f64 * dpi_scale).round() as i32;
    let final_height = (req.target_height as f64 * dpi_scale).round() as i32;

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

### 2.4 渲染流程

```
用户缩放 (zoom: 5x)
       │
       ▼
┌─────────────────────────────────────┐
│ 1. 计算渲染 DPI                      │
│    dpr = 3.0 (Retina)               │
│    effectiveZoom = 5 * 3 = 15       │
│    renderDpi = 72 * 15 = 1080       │
│    cappedDpi = min(1080, 600) = 600 │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 2. 计算可见区域瓦片坐标              │
│    visibleRect → tileCoords         │
│    [(0,0), (0,1), (1,0), (1,1)]     │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 3. 检查缓存                         │
│    已缓存 → 直接使用                │
│    未缓存 → 加入渲染队列            │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 4. 渲染瓦片                         │
│    调用 Rust FFI render_viewport()  │
│    render_dpi = 600                 │
│    返回 BGRA 字节数组               │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 5. 转换并缓存                       │
│    bytes → ui.Image                 │
│    存入 TileManager                 │
└─────────────────────────────────────┘
       │
       ▼
┌─────────────────────────────────────┐
│ 6. 显示                             │
│    CustomPainter 绘制瓦片           │
└─────────────────────────────────────┘
```

---

## 三、实施计划

### 3.1 任务分解

| 阶段 | 任务 | 预估时间 |
|------|------|----------|
| 1 | 修改 Rust FFI，添加 `render_dpi` 参数 | 0.5 天 |
| 2 | 实现 TileManager 瓦片缓存 | 1 天 |
| 3 | 实现 TileRenderScheduler 调度器 | 1 天 |
| 4 | 修改 PdfPageWidget 集成新渲染 | 1 天 |
| 5 | 单元测试 + 集成测试 | 1 天 |

### 3.2 文件修改清单

| 文件 | 修改内容 |
|------|----------|
| `rust/src/api/pdf.rs` | 添加 `render_dpi` 参数，修改渲染逻辑 |
| `lib/src/pdf/pdf_service.dart` | 更新 FFI 调用接口 |
| `lib/src/pdf/widgets/pdf_viewport_widget.dart` | 集成 TileManager 和 TileRenderScheduler |
| **新增** `lib/src/pdf/tile_manager.dart` | 瓦片缓存管理 |
| **新增** `lib/src/pdf/tile_render_scheduler.dart` | 瓦片渲染调度 |

---

## 四、与现有优化设计的关系

本设计是 [PDF 批注系统优化设计](./2026-05-27-pdf-annotation-optimization-design.md) 的补充。

**关系说明**:

| 设计文档 | 解决的问题 | 核心组件 |
|----------|-----------|----------|
| 批注系统优化设计 | 拖动、缩放卡顿、手势冲突 | ElasticBoundary, ViewportRepaintNotifier, StaticPictureCache |
| High DPI Tile Rendering | 放大后模糊 | TileManager, TileRenderScheduler, render_dpi |

**实施顺序**:
1. 先实施批注系统优化设计（解决基础交互问题）
2. 再实施 High DPI Tile Rendering（解决渲染清晰度问题）

**组件协同**:
- `StaticPictureCache` 可以复用 `TileManager` 的缓存机制
- `ViewportRepaintNotifier` 的直绘机制同样适用于高 DPI 瓦片
- 两个设计共享相同的瓦片渲染策略

### 4.1 内存管理

| 瓦片尺寸 | DPI | 单瓦片内存 | 20 瓦片总内存 |
|----------|-----|-----------|---------------|
| 512×512 | 72 | 1 MB | 20 MB |
| 512×512 | 300 | 4 MB | 80 MB |
| 512×512 | 600 | 16 MB | 320 MB |

**策略**: 限制高 DPI 瓦片数量，使用 LRU 淘汰

### 4.2 渲染延迟

- 首次渲染: 需要等待 Rust 渲染完成
- 缓存命中: 直接显示，延迟 < 16ms
- 动态优先级: 中心区域优先渲染

### 4.3 渲染策略

1. **低分辨率预览**: 先显示低 DPI 版本，再异步加载高 DPI
2. **渐进式渲染**: 从中心向边缘渲染
3. **取消机制**: 缩放/平移时取消旧的渲染任务

---

## 五、验收标准

### 5.1 视觉质量

- [ ] 5x 缩放时文字边缘清晰，无明显锯齿
- [ ] 10x 缩放时文字仍可辨识，笔画清晰
- [ ] 高 DPI 瓦片加载后，文字清晰度接近矢量效果

### 5.2 性能指标

- [ ] 瓦片渲染延迟 < 200ms (在标准设备上)
- [ ] 缓存命中率 > 70% (正常浏览场景)
- [ ] 内存使用可控 (< 300MB，包括文档和渲染缓存)

### 5.3 用户体验

- [ ] 缩放时无明显卡顿
- [ ] 先显示低分辨率，再渐进增强
- [ ] 平移时瓦片无缝衔接

---

## 六、风险与应对

| 风险 | 概率 | 影响 | 应对措施 |
|------|------|------|----------|
| 高 DPI 渲染内存爆炸 | 高 | 高 | 限制最大 DPI 为 600，严格 LRU 淘汰 |
| 渲染延迟导致闪烁 | 中 | 中 | 低分辨率预览 + 渐进式加载 |
| 瓦片边界拼接问题 | 低 | 中 | 瓦片边缘预留 1-2 像素重叠 |
| 缩放动画卡顿 | 中 | 低 | 渲染异步化，不阻塞 UI 线程 |

---

**设计完成，待用户批准后进入实现阶段。**
