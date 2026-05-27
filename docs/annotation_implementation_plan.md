# Starmind PDF 批注系统实现规划

> 基于 grill-with-docs 设计会话结果，本文档规划 PDF 批注功能的完整实现路径。

## 0. PDF 视口交互设计（前置优化）

> 在批注功能之前，先优化 PDF 视口的交互体验。

### 0.1 核心功能

| 功能 | 说明 |
|------|------|
| 双指缩放 | 0.5x ~ 5.0x，以双指中心为锚点 |
| 双指平移 | 两指拖动移动视图 |
| 单指滚动 | 阅读模式下滚动页面 |
| 自由平移模式 | 设置开关，开启后无边界约束 |

### 0.2 模式矩阵

| 模式 | 单指 | 双指 | 手写笔 |
|------|------|------|--------|
| 阅读模式 | 滚动/长按选择 | 缩放/平移 | - |
| 绘制模式（防误触关闭） | 手写绘制 | 缩放/平移 | 手写绘制 |
| 绘制模式（防误触开启） | 滚动/长按选择 | 缩放/平移 | 手写绘制 |

### 0.3 边界行为

- **默认模式（居中模式）**：
  - PDF 居中显示
  - 弹性边界约束
  - 缩放后：PDF 宽度 < 屏幕宽度时自动居中

- **自由平移模式**：
  - 无边界约束
  - 用户可自由移动 PDF 到任意位置

### 0.4 存储策略

| 设置 | 存储位置 | 说明 |
|------|---------|------|
| 自由平移开关 | `PreferencesController` | 全局设置 |
| 防误触开关 | `PreferencesController`（UI 在 PDF 工具栏） | 全局设置 |
| 视口状态 | `documents` 表 | 文档级持久化 |

### 0.5 视口状态数据模型

```sql
-- 在 documents 表添加字段
ALTER TABLE documents ADD COLUMN viewport_zoom REAL DEFAULT 1.0;
ALTER TABLE documents ADD COLUMN viewport_offset_x REAL DEFAULT 0.0;
ALTER TABLE documents ADD COLUMN viewport_offset_y REAL DEFAULT 0.0;
```

> 坐标系：PDF 坐标系（单位：PDF point，原点：PDF 左下角）

### 0.6 实现方案

使用 Flutter `InteractiveViewer` 组件：

```dart
InteractiveViewer(
  minScale: 0.5,
  maxScale: 5.0,
  constrained: false,  // 允许自由移动
  boundaryMargin: EdgeInsets.all(double.infinity),  // 自由平移模式
  onInteractionUpdate: (details) {
    // 更新视口状态
  },
  child: PdfPages(),
)
```

---

## 1. 系统架构总览

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter UI Layer                          │
│  ┌─────────────┐ ┌──────────────┐ ┌────────────────────┐   │
│  │ PdfViewport │ │ Annotation   │ │ AnnotationSidebar  │   │
│  │ Widget      │ │ Overlay      │ │ Panel              │   │
│  └──────┬──────┘ └──────┬───────┘ └──────────┬─────────┘   │
│         │               │                    │              │
│         └───────────────┼────────────────────┘              │
│                         │                                    │
│                         ▼                                    │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              AnnotationController                        ││
│  │  - 管理 PDF 视口上的批注状态                              ││
│  │  - 处理批注 CRUD 操作                                    ││
│  │  - 协调 Undo/Redo 栈                                     ││
│  │  - 监听 StorageRepository 变化                           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Dart Domain Layer                         │
│  ┌────────────────┐  ┌─────────────────────────────────┐   │
│  │ Annotation     │  │ StorageRepository (Seam)         │   │
│  │ Data Model     │  │ - FfiStorageRepository           │   │
│  └────────────────┘  │ - InMemoryStorageRepository      │   │
│                      └─────────────────────────────────┘   │
└─────────────────────────────┬───────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Rust FFI Layer                            │
│  ┌────────────────┐  ┌─────────────────────────────────┐   │
│  │ annotations    │  │ pdf.rs (PDFium Operations)       │   │
│  │ Table (SQLite) │  │ - render_viewport                │   │
│  │                │  │ - get_page_chars                 │   │
│  │                │  │ - export_annotations_to_pdf      │   │
│  └────────────────┘  └─────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

## 2. 数据模型设计

### 2.1 SQLite Schema (Rust 层)

```sql
CREATE TABLE annotations (
    id TEXT PRIMARY KEY,
    document_id TEXT NOT NULL,
    page_index INTEGER NOT NULL,
    annotation_type TEXT NOT NULL,  -- 'highlight', 'underline', 'wave', 'ink', 'note'
    is_standard BOOLEAN NOT NULL,   -- 是否可导出为 PDF 原生注释
    color_hex TEXT DEFAULT '#FFFF00',
    created_at INTEGER NOT NULL,
    modified_at INTEGER NOT NULL,

    -- 文本类批注字段
    start_char_index INTEGER,
    end_char_index INTEGER,
    selected_text TEXT,
    rects_json TEXT,  -- JSON array of {left, top, right, bottom}

    -- 手写批注字段
    strokes_json TEXT,  -- JSON array of Stroke objects

    -- 文本笔记字段
    note_content TEXT,

    FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE
);

CREATE INDEX idx_annotations_document ON annotations(document_id);
CREATE INDEX idx_annotations_page ON annotations(document_id, page_index);
```

### 2.2 Dart Domain Model

```dart
// lib/src/domain/annotation.dart

enum AnnotationType {
  highlight,
  underline,
  wave,
  ink,
  note,
}

class Annotation {
  final String id;
  final String documentId;
  final int pageIndex;
  final AnnotationType type;
  final bool isStandard;
  final String colorHex;
  final DateTime createdAt;
  final DateTime modifiedAt;

  // 文本类批注
  final int? startCharIndex;
  final int? endCharIndex;
  final String? selectedText;
  final List<AnnotationRect>? rects;

  // 手写批注
  final List<Stroke>? strokes;

  // 文本笔记
  final String? noteContent;

  Annotation({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.type,
    required this.isStandard,
    this.colorHex = '#FFFF00',
    required this.createdAt,
    required this.modifiedAt,
    this.startCharIndex,
    this.endCharIndex,
    this.selectedText,
    this.rects,
    this.strokes,
    this.noteContent,
  });

  factory Annotation.fromJson(Map<String, dynamic> json);
  Map<String, dynamic> toJson();
  Annotation deepCopy();
}

class AnnotationRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const AnnotationRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });
}
```

## 3. 实现分阶段规划

### Phase 1: 基础设施层 (Rust + Dart Domain)

#### 1.1 Rust 层实现

**文件**: `rust/src/storage/annotations.rs`

```rust
pub struct AnnotationRecord {
    pub id: String,
    pub document_id: String,
    pub page_index: i32,
    pub annotation_type: String,
    pub is_standard: bool,
    pub color_hex: String,
    pub created_at: i64,
    pub modified_at: i64,
    pub start_char_index: Option<i32>,
    pub end_char_index: Option<i32>,
    pub selected_text: Option<String>,
    pub rects_json: Option<String>,
    pub strokes_json: Option<String>,
    pub note_content: Option<String>,
}

// CRUD operations
pub fn create_annotation(db: &Connection, annotation: AnnotationRecord) -> Result<String>;
pub fn get_annotations_for_document(db: &Connection, document_id: &str) -> Result<Vec<AnnotationRecord>>;
pub fn get_annotations_for_page(db: &Connection, document_id: &str, page_index: i32) -> Result<Vec<AnnotationRecord>>;
pub fn update_annotation(db: &Connection, id: &str, updates: HashMap<&str, Value>) -> Result<()>;
pub fn delete_annotation(db: &Connection, id: &str) -> Result<()>;
```

**文件**: `rust/src/api/storage.rs` (FFI 接口扩展)

```rust
// 新增批注相关 FFI 函数
pub fn create_annotation(annotation: AnnotationRecord) -> Result<String>;
pub fn get_annotations(document_id: String) -> Result<Vec<AnnotationRecord>>;
pub fn update_annotation(id: String, updates: HashMap<String, Value>) -> Result<()>;
pub fn delete_annotation(id: String) -> Result<()>;
```

#### 1.2 Dart Domain 层实现

**文件**: `lib/src/domain/annotation.dart`
- 定义 `Annotation` 类和 `AnnotationType` 枚举

**文件**: `lib/src/domain/storage_repository.dart` (接口扩展)

```dart
abstract class StorageRepository {
  // ... 现有方法

  // Annotation CRUD
  Future<String> createAnnotation(Annotation annotation);
  Future<List<Annotation>> getAnnotations(String documentId);
  Future<List<Annotation>> getAnnotationsForPage(String documentId, int pageIndex);
  Future<void> updateAnnotation(String id, Map<String, dynamic> updates);
  Future<void> deleteAnnotation(String id);
}
```

**文件**: `lib/src/domain/ffi_storage_repository.dart` (实现)

```dart
class FfiStorageRepository implements StorageRepository {
  // ... 现有实现

  @override
  Future<String> createAnnotation(Annotation annotation) async {
    return rustApi.createAnnotation(annotation: annotation.toRustRecord());
  }

  // ... 其他批注方法
}
```

#### 1.3 验证

- `flutter analyze` 无错误
- Rust 编译通过
- 单元测试：Annotation CRUD 操作

---

### Phase 2: 批注控制器层

#### 2.1 AnnotationController

**文件**: `lib/src/pdf/annotation_controller.dart`

```dart
class AnnotationController extends ChangeNotifier {
  final StorageRepository _repository;
  final String documentId;

  List<Annotation> _annotations = [];
  Map<int, List<Annotation>> _pageAnnotations = {};  // 按页码索引
  UndoRedoStack _undoStack = UndoRedoStack();

  AnnotationController(this._repository, this.documentId);

  Future<void> loadAnnotations();
  List<Annotation> getAnnotationsForPage(int pageIndex);

  // 创建批注
  Future<void> createHighlight(int pageIndex, int startChar, int endChar, String text, List<AnnotationRect> rects, String colorHex);
  Future<void> createUnderline(...);
  Future<void> createWave(...);
  Future<void> createInk(int pageIndex, List<Stroke> strokes, String colorHex);
  Future<void> createNote(int pageIndex, String content, AnnotationRect rect, String colorHex);

  // 编辑批注
  Future<void> updateColor(String annotationId, String newColorHex);
  Future<void> updateNoteContent(String annotationId, String newContent);

  // 删除批注
  Future<void> deleteAnnotation(String annotationId);

  // Undo/Redo
  void undo();
  void redo();
  bool canUndo();
  bool canRedo();
}
```

#### 2.2 UndoRedoStack

**文件**: `lib/src/pdf/undo_redo_stack.dart`

```dart
abstract class AnnotationAction {
  void undo(AnnotationController controller);
  void redo(AnnotationController controller);
}

class CreateAnnotationAction implements AnnotationAction {
  final Annotation annotation;
  // ...
}

class DeleteAnnotationAction implements AnnotationAction {
  final Annotation annotation;
  // ...
}

class UpdateAnnotationAction implements AnnotationAction {
  final String annotationId;
  final Map<String, dynamic> oldValues;
  final Map<String, dynamic> newValues;
  // ...
}

class UndoRedoStack {
  final List<AnnotationAction> _undoStack = [];
  final List<AnnotationAction> _redoStack = [];

  void push(AnnotationAction action);
  AnnotationAction? popUndo();
  AnnotationAction? popRedo();
  void clear();
}
```

---

### Phase 3: 文本选择 UI 层

#### 3.1 文本选择手势处理器

**文件**: `lib/src/pdf/widgets/text_selection_handler.dart`

```dart
class TextSelectionHandler {
  final List<CharInfo> _chars;  // 从 PdfService.getPageChars 获取
  final Function(TextSelection) onSelectionComplete;

  int? _startCharIndex;
  int? _endCharIndex;
  List<AnnotationRect> _selectionRects = [];

  void onLongPressStart(Offset touchPosition, double zoom, Offset scrollOffset, double pageHeight);
  void onLongPressUpdate(Offset touchPosition, ...);
  void onLongPressEnd();

  TextSelection? get currentSelection;
}
```

#### 3.2 选择手柄 Overlay

**文件**: `lib/src/pdf/widgets/selection_handles_overlay.dart`

```dart
class SelectionHandlesOverlay extends StatelessWidget {
  final TextSelection selection;
  final double zoom;
  final Offset scrollOffset;
  final void Function(SelectionHandle handle, Offset newPosition) onHandleDrag;

  // 渲染左右两个选择手柄
  // 手柄位置基于选中文本的 rects 计算
}
```

#### 3.3 浮动工具栏

**文件**: `lib/src/pdf/widgets/annotation_toolbar.dart`

```dart
class AnnotationToolbar extends StatelessWidget {
  final Offset position;  // 屏幕位置
  final VoidCallback onClose;
  final Function(String colorHex) onHighlight;
  final Function(String colorHex) onUnderline;
  final Function(String colorHex) onWave;
  final VoidCallback onNote;

  // 预设颜色按钮 + 自定义颜色入口
  // 高亮、下划线、波浪线、笔记按钮
}
```

**文件**: `lib/src/pdf/widgets/color_picker_popup.dart`

```dart
class ColorPickerPopup extends StatelessWidget {
  final List<String> presetColors = [
    '#FFFF00',  // 黄色
    '#FF9800',  // 橙色
    '#4CAF50',  // 绿色
    '#2196F3',  // 蓝色
    '#9C27B0',  // 紫色
    '#F44336',  // 红色
  ];
  final Function(String colorHex) onColorSelected;

  // 预设色板 + 自定义颜色选择器
}
```

---

### Phase 4: 手写批注绘制层

#### 4.1 画笔工具栏

**文件**: `lib/src/pdf/widgets/ink_toolbar.dart`

```dart
enum InkTool { pen, highlighter, eraser }

class InkToolbar extends StatelessWidget {
  final InkTool currentTool;
  final String currentColor;
  final double strokeWidth;
  final Function(InkTool) onToolChanged;
  final Function(String) onColorChanged;
  final Function(double) onStrokeWidthChanged;

  // 画笔、荧光笔、橡皮擦切换
  // 颜色选择
  // 笔触粗细滑块
}
```

#### 4.2 手写绘制层

**文件**: `lib/src/pdf/widgets/ink_canvas_layer.dart`

```dart
class InkCanvasLayer extends StatefulWidget {
  final AnnotationController annotationController;
  final int pageIndex;
  final bool isInkMode;  // 是否处于绘制模式
  final double zoom;
  final Offset scrollOffset;

  // 使用 GestureDetector 捕获绘制手势
  // 实时渲染笔画
  // 笔画完成后调用 annotationController.createInk
}
```

---

### Phase 5: 批注渲染层

#### 5.1 批注渲染器

**文件**: `lib/src/pdf/widgets/annotation_renderer.dart`

```dart
class AnnotationRenderer extends CustomPainter {
  final List<Annotation> annotations;
  final double zoom;
  final Offset scrollOffset;
  final double pageHeight;

  @override
  void paint(Canvas canvas, Size size) {
    for (final annotation in annotations) {
      switch (annotation.type) {
        case AnnotationType.highlight:
          _paintHighlight(canvas, annotation);
        case AnnotationType.underline:
          _paintUnderline(canvas, annotation);
        case AnnotationType.wave:
          _paintWave(canvas, annotation);
        case AnnotationType.ink:
          _paintInk(canvas, annotation);
        case AnnotationType.note:
          _paintNote(canvas, annotation);
      }
    }
  }

  void _paintHighlight(Canvas canvas, Annotation annotation);
  void _paintUnderline(Canvas canvas, Annotation annotation);
  void _paintWave(Canvas canvas, Annotation annotation);
  void _paintInk(Canvas canvas, Annotation annotation);
  void _paintNote(Canvas canvas, Annotation annotation);
}
```

---

### Phase 6: 批注编辑交互层

#### 6.1 批注点击检测

**文件**: `lib/src/pdf/widgets/annotation_hit_detector.dart`

```dart
class AnnotationHitDetector {
  final List<Annotation> annotations;
  final double zoom;
  final Offset scrollOffset;
  final double pageHeight;

  Annotation? hitTest(Offset touchPosition);

  // 基于触摸位置检测批注碰撞
  // 文本类批注：检测 rects 区域
  // 手写批注：检测笔画路径
}
```

#### 6.2 批注编辑浮动菜单

**文件**: `lib/src/pdf/widgets/annotation_edit_toolbar.dart`

```dart
class AnnotationEditToolbar extends StatelessWidget {
  final Annotation annotation;
  final Offset position;
  final VoidCallback onDelete;
  final Function(String) onColorChange;
  final VoidCallback? onEditContent;  // 仅笔记类批注有

  // 根据批注类型显示不同选项
}
```

---

### Phase 7: 侧边栏批注面板

#### 7.1 批注列表面板

**文件**: `lib/src/pdf/widgets/annotation_sidebar_panel.dart`

```dart
class AnnotationSidebarPanel extends StatefulWidget {
  final AnnotationController annotationController;
  final Function(int pageIndex, Annotation annotation) onNavigate;

  // 按页码分组显示批注
  // 筛选（按类型、颜色）
  // 点击跳转到对应位置
}
```

---

### Phase 8: PDF 导出功能

#### 8.1 Rust 层导出实现

**文件**: `rust/src/api/pdf.rs` (扩展)

```rust
pub fn export_pdf_with_annotations(
    source_path: String,
    output_path: String,
    annotations: Vec<AnnotationRecord>,
) -> Result<()> {
    // 1. 加载源 PDF
    // 2. 遍历每个批注
    // 3. 标准批注：创建 PDF 原生注释对象（FPDFPage_CreateAnnot）
    // 4. 私有批注：在页面上绘制内容
    // 5. 保存到 output_path
}
```

#### 8.2 Dart 导出服务

**文件**: `lib/src/pdf/pdf_export_service.dart`

```dart
class PdfExportService {
  final StorageRepository _repository;

  Future<String> exportPdfWithAnnotations(String documentId, String outputPath) async {
    final annotations = await _repository.getAnnotations(documentId);
    await rustApi.exportPdfWithAnnotations(
      sourcePath: document.sourcePath,
      outputPath: outputPath,
      annotations: annotations.map((a) => a.toRustRecord()).toList(),
    );
    return outputPath;
  }
}
```

---

## 4. 文件变更清单

| 文件 | 操作 | Phase |
|------|------|-------|
| `rust/src/storage/annotations.rs` | 新建 | 1 |
| `rust/src/storage/mod.rs` | 添加 mod annotations | 1 |
| `rust/src/api/storage.rs` | 批注 FFI 接口 | 1 |
| `rust/src/api/pdf.rs` | 导出 FFI 接口 | 8 |
| `lib/src/domain/annotation.dart` | 新建 | 1 |
| `lib/src/domain/storage_repository.dart` | 添加批注接口 | 1 |
| `lib/src/domain/ffi_storage_repository.dart` | 批注实现 | 1 |
| `lib/src/domain/in_memory_storage_repository.dart` | 批注实现 | 1 |
| `lib/src/pdf/annotation_controller.dart` | 新建 | 2 |
| `lib/src/pdf/undo_redo_stack.dart` | 新建 | 2 |
| `lib/src/pdf/widgets/text_selection_handler.dart` | 新建 | 3 |
| `lib/src/pdf/widgets/selection_handles_overlay.dart` | 新建 | 3 |
| `lib/src/pdf/widgets/annotation_toolbar.dart` | 新建 | 3 |
| `lib/src/pdf/widgets/color_picker_popup.dart` | 新建 | 3 |
| `lib/src/pdf/widgets/ink_toolbar.dart` | 新建 | 4 |
| `lib/src/pdf/widgets/ink_canvas_layer.dart` | 新建 | 4 |
| `lib/src/pdf/widgets/annotation_renderer.dart` | 新建 | 5 |
| `lib/src/pdf/widgets/annotation_hit_detector.dart` | 新建 | 6 |
| `lib/src/pdf/widgets/annotation_edit_toolbar.dart` | 新建 | 6 |
| `lib/src/pdf/widgets/annotation_sidebar_panel.dart` | 新建 | 7 |
| `lib/src/pdf/pdf_export_service.dart` | 新建 | 8 |
| `test/domain/annotation_test.dart` | 新建 | 1 |
| `test/pdf/annotation_controller_test.dart` | 新建 | 2 |

---

## 5. 实现顺序建议

建议按 Phase 顺序逐步实现，每个 Phase 完成后验证：

1. **Phase 1** → 数据层完成，可进行 CRUD 单元测试
2. **Phase 2** → 控制器完成，可测试业务逻辑
3. **Phase 3-6** → UI 层逐步完善，可手动测试交互
4. **Phase 7** → 导航功能
5. **Phase 8** → 导出功能（依赖所有批注类型完成）

---

## 6. 设计决策记录

| 问题 | 决策 | 理由 |
|------|------|------|
| 批注存储 | SQLite 主存储 | 编辑性能最优，PDF 写入延迟 |
| 文本定位 | 字符索引 | 精确定位，不受缩放影响 |
| 标准批注 | 导出为 PDF 原生注释 | 其他阅读器可编辑 |
| 私有批注 | 导出为渲染图形 | Starmind 特有功能，兼容性优先 |
| 导出时机 | 分享/导出副本时 | 原始 PDF 不变，用户可控 |
| 颜色方案 | 预设色板 + 自定义 | 快速访问 + 个性化 |
| 文本选择 | 长按 + 弹出菜单 | 标准交互，用户熟悉 |
| 手写模式 | 工具栏切换 | 清晰模式分离，避免手势冲突 |
| 批注编辑 | 浮动工具栏 | 就近反馈，符合 MarginNote 风格 |
| 批注导航 | 侧边栏面板 | 紧密结合阅读场景 |
| Undo/Redo | 文档级统一栈 | 自然体验，一个按钮处理所有 |

---

## 7. 后续迭代规划

完成基础批注功能后，可考虑：

1. **图片批注**：截图摘录、图片标注
2. **批注搜索**：全局搜索批注内容
3. **批注统计**：文档批注数量、类型分布
4. **批注导出格式**：Markdown、HTML 等格式导出
5. **云同步**：批注数据云端备份