# Starmind 代码库全景解读

**日期**: 2026-05-30

---

## 一、整体架构

Starmind 是一个 **Flutter 前端 + Rust 后端** 的桌面/移动端知识管理应用。两个语言层通过 **FFI（Foreign Function Interface，外部函数接口）** 连接——Flutter 负责 UI 和交互，Rust 负责 PDF 渲染和数据存储。

```
┌──────────────────────────────────────────────────────────────┐
│                    Flutter (Dart) — lib/                     │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  UI 组件      │  │  状态管理      │  │  领域模型          │  │
│  │  (widgets)    │  │  (controllers)│  │  (domain models)  │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬───────────┘  │
│         └─────────┬───────┴───────────────────┘              │
│                   │  FFI 桥接层 (flutter_rust_bridge)         │
│                   ▼                                           │
├──────────────────────────────────────────────────────────────┤
│                    Rust — rust/src/                           │
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐  │
│  │  PDF 渲染     │  │  SQLite 存储  │  │  文件操作          │  │
│  │  (PDFium)     │  │  (rusqlite)  │  │  (sandbox)        │  │
│  └──────┬───────┘  └──────┬───────┘  └────────┬───────────┘  │
│         └─────────┬───────┴───────────────────┘              │
│                   ▼                                           │
├──────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────────┐  ┌─────────────────┐   │
│  │  PDFium     │  │  SQLite 数据库    │  │  沙盒文件目录    │   │
│  │  (native库)  │  │  (starmind.db)  │  │  (sandbox/)     │   │
│  └─────────────┘  └─────────────────┘  └─────────────────┘   │
└──────────────────────────────────────────────────────────────┘
```

**类比理解**：如果你用 Java 写过后端，Flutter 相当于你的 Spring MVC（视图+控制器），Rust 相当于你的 Service + DAO 层（业务逻辑+数据库操作），PDFium 则是一个 native 的第三方 SDK。

---

## 二、lib/ 目录：Flutter 前端代码

### 2.1 lib/main.dart — 应用入口与根布局

**作用**：整个应用的 `main()` 函数、根组件、以及主页的全部 UI 代码。

**结构一览**：

| 函数/类 | 行数（约） | 作用 |
|--------|-----------|------|
| `main()` | 33-46 | 初始化 Rust → 创建 WorkspaceController → 启动 App |
| `MyApp` | 48-71 | 根组件，配置主题（深色/浅色）和字体 |
| `WorkspacePage` | 73-303 | 主工作区：Tab 栏 + 侧边栏 + 内容区 |
| `OrbBackground` | 444-509 | 深色模式下的发光球背景装饰 |
| `TabBarWidget` | 512-640 | 顶部标签栏（首页、PDF 标签页） |
| `SidebarWidget` | 643-约1050 | 左侧文件夹树 + 标签树导航 |
| `HomeDashboard` | 约2024-2627 | 首页文档卡片网格、搜索、排序、筛选 |
| `PdfTabViewport` | 约2630-3900 | PDF 阅读器视口（缩放、工具栏、批注） |
| `_PdfTabPagesContainer` | 约3950-4150 | PDF 页面虚拟化渲染容器 |
| 各种对话框函数 | 散布各处 | 创建文件夹、重命名、删除确认、导入 PDF、设置面板 |

**关键逻辑**：
- **`main()`**：先调 `WidgetsFlutterBinding.ensureInitialized()` 确保 Flutter 引擎就绪，然后 `RustLib.init()` 初始化 Rust FFI 层，再创建 `WorkspaceController`（注入 `FfiStorageRepository`），最后 `runApp()`。
- **`WorkspacePage`**：是整个应用的主页面，内部通过 `_pdfControllers` 缓存每个打开的 PDF 的控制器（`Map<String, PdfViewportController>`），当标签页关闭时释放对应的控制器。

**当前问题**：此文件约 4000+ 行，包含了太多职责（UI 布局、对话框、PDF 阅读器逻辑、图表渲染等），是未来拆分重构的重点。

---

### 2.2 lib/src/domain/ — 领域模型层

**作用**：定义应用的核心数据结构，是 **UI 与数据层之间的隔离层**。用 Java 类比，这就是你的 POJO / Entity 类。

#### 文件清单：

| 文件 | 核心类 | 作用 |
|------|--------|------|
| [document.dart](file:///d:/starmind/lib/src/domain/document.dart) | `Document` | PDF 文档实体（id、title、filePath、folderId、tagIds、createdAt） |
| [folder.dart](file:///d:/starmind/lib/src/domain/folder.dart) | `Folder` | 文件夹实体，实现 `TreeNode` 接口，支持无限嵌套 |
| [tag.dart](file:///d:/starmind/lib/src/domain/tag.dart) | `Tag` | 标签实体，支持颜色、树形嵌套、`TreeNode` 接口 |
| [tree_node.dart](file:///d:/starmind/lib/src/domain/tree_node.dart) | `TreeNode` | 通用树节点接口 + 扩展方法（查找、遍历、路径计算） |
| [annotation.dart](file:///d:/starmind/lib/src/domain/annotation.dart) | `Annotation`, `AnnotationRect` | PDF 批注实体，支持高亮、下划线、波浪线、墨迹、笔记五种类型 |
| [ink_stroke.dart](file:///d:/starmind/lib/src/domain/ink_stroke.dart) | `InkStroke`, `InkPoint` | 手写笔迹模型，包含点集、颜色、笔宽 |
| [storage_repository.dart](file:///d:/starmind/lib/src/domain/storage_repository.dart) | `StorageRepository` | 数据访问的抽象接口（类似 Java 的 DAO 接口） |
| [ffi_storage_repository.dart](file:///d:/starmind/lib/src/domain/ffi_storage_repository.dart) | `FfiStorageRepository` | 生产环境实现——调用 Rust FFI 读写 SQLite |
| [in_memory_storage_repository.dart](file:///d:/starmind/lib/src/domain/in_memory_storage_repository.dart) | `InMemoryStorageRepository` | 测试用实现——纯内存存储，不需要 Rust/SQLite |

**设计亮点**：
- **Repository 模式**：`StorageRepository` 是抽象接口，有两套实现——生产用 FFI（真实数据库），测试用内存（无需运行 Rust）。这使得 UI 代码完全不依赖具体存储实现。
- **TreeNode 接口 + 扩展方法**：`Folder` 和 `Tag` 都实现了 `TreeNode`，扩展方法提供了 `findNode()`、`flatten()`、`traverse()`、`pathTo()` 等通用树操作，不需要重复写递归逻辑。
- **FFI 类型转换**：`FfiStorageRepository` 内部将 Rust 生成的 FFI 类型（如 `FolderNode`、`DocumentInfo`）转换为 Dart 领域模型（`Folder`、`Document`），隔离了 FFI 实现细节。

---

### 2.3 lib/src/home/ — 工作区状态管理层

**作用**：管理工作区的全局状态——设置、文件夹/标签元数据、文档查询、标签页导航。用 Java 类比，这就是你的 Service 层。

#### 文件清单：

| 文件 | 核心类 | 作用 |
|------|--------|------|
| [workspace_controller.dart](file:///d:/starmind/lib/src/home/workspace_controller.dart) | `WorkspaceController` | 顶层协调器，聚合四个子控制器，对外暴露统一接口 |
| [workspace_controller_provider.dart](file:///d:/starmind/lib/src/home/workspace_controller_provider.dart) | `WorkspaceControllerProvider` | Flutter 的 `InheritedWidget`，实现依赖注入（子组件通过 `context.workspaceController` 访问） |
| [tab_layout.dart](file:///d:/starmind/lib/src/home/tab_layout.dart) | `SplitNode`, `LeafNode`, `ParentNode`, `TabItem` | 分屏面板的树形数据结构 |
| [tab_navigation_controller.dart](file:///d:/starmind/lib/src/home/tab_navigation_controller.dart) | `TabNavigationController` | 标签页打开/关闭/切换逻辑 |
| [metadata_controller.dart](file:///d:/starmind/lib/src/home/metadata_controller.dart) | `MetadataController` | 文件夹和标签树的 CRUD + 刷新 |
| [document_query_controller.dart](file:///d:/starmind/lib/src/home/document_query_controller.dart) | `DocumentQueryController` | 文档查询、筛选（文件夹/标签）、搜索、排序、导入 |
| [preferences_controller.dart](file:///d:/starmind/lib/src/home/preferences_controller.dart) | `PreferencesController` | 用户偏好设置（深色模式、自动保存、侧边栏等），持久化到 SharedPreferences |

**架构亮点**：
- **子控制器分离**：`WorkspaceController` 不直接实现任何逻辑，而是委托给四个专职子控制器。这就像 Java 里的 Facade 模式——对外提供统一入口，对内各司其职。
- **通知传播**：子控制器都是 `ChangeNotifier`，当它们的状态变化时，通过 `addListener(notifyListeners)` 把变更通知传播到 `WorkspaceController`，最终触发 UI 刷新。

---

### 2.4 lib/src/pdf/ — PDF 渲染与批注层

**作用**：所有与 PDF 相关的逻辑——文档加载、页面渲染、缩放平移、文字选择、墨迹绘制、批注管理。

#### 核心控制类：

| 文件 | 核心类 | 作用 |
|------|--------|------|
| [pdf_viewport_controller.dart](file:///d:/starmind/lib/src/pdf/pdf_viewport_controller.dart) | `PdfViewportController` | PDF 视口的顶层协调器，聚合三个子模块 |
| [pdf_doc_session.dart](file:///d:/starmind/lib/src/pdf/pdf_doc_session.dart) | `PdfDocSession` | 文档生命周期管理（加载/关闭）+ 页面数据缓存（LRU 缓存字符信息） |
| [viewport_transform.dart](file:///d:/starmind/lib/src/pdf/viewport_transform.dart) | `ViewportTransform` | 缩放/平移状态管理，焦点缩放计算，边界约束 |
| [text_selection_model.dart](file:///d:/starmind/lib/src/pdf/text_selection_model.dart) | `TextSelectionModel` | 文字选择状态（选中区间、选中文字、工具栏位置） |
| [annotation_controller.dart](file:///d:/starmind/lib/src/pdf/annotation_controller.dart) | `AnnotationController` | 批注 CRUD + 按页索引查询 + Undo/Redo |
| [undo_redo_stack.dart](file:///d:/starmind/lib/src/pdf/undo_redo_stack.dart) | `UndoRedoStack` | 撤销/重做栈，支持任意操作类型 |
| [pdf_service.dart](file:///d:/starmind/lib/src/pdf/pdf_service.dart) | `PdfService` | 单例，封装 Rust FFI 调用（初始化 PDFium、加载文档、渲染视口、获取字符位置） |
| [pdf_highlight.dart](file:///d:/starmind/lib/src/pdf/pdf_highlight.dart) | `PdfHighlight` | 临时高亮数据（渲染用，持久化由 AnnotationController 负责） |
| [pdf_coordinates.dart](file:///d:/starmind/lib/src/pdf/pdf_coordinates.dart) | `PdfCoordinates` | PDF 坐标 ↔ Flutter 屏幕坐标的转换工具 |

#### 性能优化类：

| 文件 | 核心类 | 作用 |
|------|--------|------|
| [tile_manager.dart](file:///d:/starmind/lib/src/pdf/tile_manager.dart) | `TileManager` | 瓦片缓存管理器（LRU 淘汰策略，最多 20 个瓦片） |
| [static_picture_cache.dart](file:///d:/starmind/lib/src/pdf/static_picture_cache.dart) | `StaticPictureCache` | 静态 PDF 页面的 `ui.Picture` 缓存 |
| [render_scheduler.dart](file:///d:/starmind/lib/src/pdf/render_scheduler.dart) | `RenderScheduler` | 渲染调度器，控制高分辨率瓦片的异步渲染时机 |
| [stroke_cache_manager.dart](file:///d:/starmind/lib/src/pdf/stroke_cache_manager.dart) | `StrokeCacheManager` | 墨迹笔画的缓存管理 |
| [viewport_repaint_notifier.dart](file:///d:/starmind/lib/src/pdf/viewport_repaint_notifier.dart) | `ViewportRepaintNotifier` | 视口重绘通知器，直接触发 `CustomPainter` 重绘而不走 Widget 重建 |

#### 交互控制类：

| 文件 | 核心类 | 作用 |
|------|--------|------|
| [gesture_dispatcher.dart](file:///d:/starmind/lib/src/pdf/gesture_dispatcher.dart) | `GestureDispatcher` | 手势路由：区分绘制手势（单指/触控笔）与导航手势（双指缩放平移） |
| [elastic_boundary.dart](file:///d:/starmind/lib/src/pdf/elastic_boundary.dart) | `ElasticBoundary` | 弹性边界——PDF 拖到边界外时有弹性回弹效果 |
| [stroke_stabilizer.dart](file:///d:/starmind/lib/src/pdf/stroke_stabilizer.dart) | `StrokeStabilizer` | 笔迹稳定器，平滑手写输入的抖动 |
| [pressure_curve.dart](file:///d:/starmind/lib/src/pdf/pressure_curve.dart) | `PressureCurve` | 压力曲线——根据触控笔压力调整笔画粗细 |
| [pen_config.dart](file:///d:/starmind/lib/src/pdf/pen_config.dart) | `PenConfig` | 画笔配置（颜色、粗细、类型） |
| [pen_config_service.dart](file:///d:/starmind/lib/src/pdf/pen_config_service.dart) | `PenConfigService` | 画笔配置的持久化服务 |
| [pdf_export_service.dart](file:///d:/starmind/lib/src/pdf/pdf_export_service.dart) | `PdfExportService` | PDF 导出服务——将批注渲染到 PDF 副本中 |

#### Widget 类（lib/src/pdf/widgets/）：

| 文件 | 作用 |
|------|------|
| [pdf_viewport_widget.dart](file:///d:/starmind/lib/src/pdf/widgets/pdf_viewport_widget.dart) | PDF 单页渲染 Widget，包含高清瓦片渲染逻辑 |
| [ink_canvas_layer.dart](file:///d:/starmind/lib/src/pdf/widgets/ink_canvas_layer.dart) | 墨迹绘制层（覆盖在 PDF 页面上） |
| [ink_toolbar.dart](file:///d:/starmind/lib/src/pdf/widgets/ink_toolbar.dart) | 画笔工具栏 |
| [annotation_renderer.dart](file:///d:/starmind/lib/src/pdf/widgets/annotation_renderer.dart) | 批注渲染器（高亮、下划线等叠加层） |
| [annotation_edit_toolbar.dart](file:///d:/starmind/lib/src/pdf/widgets/annotation_edit_toolbar.dart) | 批注编辑工具栏（选中批注后弹出） |
| [annotation_sidebar_panel.dart](file:///d:/starmind/lib/src/pdf/widgets/annotation_sidebar_panel.dart) | 批注列表侧栏面板 |
| [text_selection_overlay.dart](file:///d:/starmind/lib/src/pdf/widgets/text_selection_overlay.dart) | 文字选择的高亮覆盖层 |
| [selection_handles_overlay.dart](file:///d:/starmind/lib/src/pdf/widgets/selection_handles_overlay.dart) | 文字选择手柄（拖拽调整选区） |
| [interactive_canvas_viewer.dart](file:///d:/starmind/lib/src/pdf/widgets/interactive_canvas_viewer.dart) | 自定义的可交互画布查看器（缩放/平移手势，支持绘制模式） |
| [annotation_hit_detector.dart](file:///d:/starmind/lib/src/pdf/widgets/annotation_hit_detector.dart) | 批注命中检测（判断点击是否在某个批注上） |
| [color_picker_popup.dart](file:///d:/starmind/lib/src/pdf/widgets/color_picker_popup.dart) | 颜色选择弹窗 |
| [pen_config_panel.dart](file:///d:/starmind/lib/src/pdf/widgets/pen_config_panel.dart) | 画笔配置面板 |
| [strike_out_renderer.dart](file:///d:/starmind/lib/src/pdf/widgets/strike_out_renderer.dart) | 删除线渲染器 |
| [annotation_toolbar.dart](file:///d:/starmind/lib/src/pdf/widgets/annotation_toolbar.dart) | 批注操作工具栏（高亮、下划线等选择） |

**`PdfViewportController` 的设计**：它聚合了三个子模块——`session`（文档数据）、`transform`（缩放平移）、`selection`（文字选择），各自独立变化但通过 `addListener(notifyListeners)` 传播通知。对外暴露便捷 getter（如 `pageCount`、`isLoading`），对内协调跨模块操作（如加载新文档时清除选区）。

---

### 2.5 lib/src/rust/ — FFI 桥接层

**作用**：Dart 调用 Rust 函数的桥梁，由 `flutter_rust_bridge` 工具自动生成。

| 文件 | 作用 |
|------|------|
| [frb_generated.dart](file:///d:/starmind/lib/src/rust/frb_generated.dart) | 自动生成的 FFI 绑定代码（不要手动修改） |
| [frb_generated.io.dart](file:///d:/starmind/lib/src/rust/frb_generated.io.dart) | 平台相关的 FFI 实现 |
| [frb_generated.web.dart](file:///d:/starmind/lib/src/rust/frb_generated.web.dart) | Web 平台的 FFI 实现 |
| [lib.dart](file:///d:/starmind/lib/src/rust/lib.dart) | 库入口 |
| [api/pdf.dart](file:///d:/starmind/lib/src/rust/api/pdf.dart) | PDF 相关 FFI 接口（initPdfium、loadDocument、renderViewport、getPageChars 等） |
| [api/storage.dart](file:///d:/starmind/lib/src/rust/api/storage.dart) | 存储相关 FFI 接口（initStorage、文件夹/标签/文档/批注的 CRUD） |
| [api/simple.dart](file:///d:/starmind/lib/src/rust/api/simple.dart) | 示例 FFI 函数 |
| [storage/*.dart](file:///d:/starmind/lib/src/rust/storage/) | FFI 传输用的数据结构（FolderNode、DocumentInfo、AnnotationRecord 等） |

---

## 三、rust/src/ 目录：Rust 后端代码

### 3.1 架构概览

Rust 代码分为两层：

```
rust/src/
├── lib.rs                  ← 模块声明入口
├── frb_generated.rs        ← flutter_rust_bridge 自动生成
├── api/                    ← FFI 公开接口层（Dart 调用的入口）
│   ├── mod.rs
│   ├── pdf.rs              ← PDF 渲染 API
│   ├── storage.rs          ← 数据存储 API（门面层）
│   └── simple.rs           ← 测试函数
└── storage/                ← 数据存储实现层（实际业务逻辑）
    ├── mod.rs
    ├── db.rs               ← SQLite 数据库初始化 + schema
    ├── folders.rs          ← 文件夹 CRUD
    ├── tags.rs             ← 标签 CRUD
    ├── documents.rs        ← 文档 CRUD + 查询
    ├── annotations.rs      ← 批注 CRUD
    └── mindmap.rs          ← 思维导图 Topic/Note CRUD
```

---

### 3.2 api/ — FFI 公开接口层

**作用**：定义 Dart 可以调用的 Rust 函数。这些函数是 "薄壳"，主要负责参数处理然后委托给 `storage/` 层的实际实现。

#### [api/pdf.rs](file:///d:/starmind/rust/src/api/pdf.rs) — PDF 渲染引擎

这是最核心的 Rust 模块，封装了 **PDFium**（Google 开源的 PDF 渲染库）。

| 函数 | 作用 |
|------|------|
| `init_pdfium()` | 初始化 PDFium 绑定（从指定路径或系统搜索加载 pdfium.dll/libpdfium.so） |
| `load_document()` | 加载 PDF 文件，返回 UUID 标识符（文档句柄存在全局 `DOCUMENTS` HashMap 中） |
| `close_document()` | 关闭文档，释放内存 |
| `get_page_count()` | 获取文档总页数 |
| `get_page_size()` | 获取指定页面的宽度和高度（PDF 点单位） |
| `render_viewport()` | **核心渲染函数**——根据视口范围（pdfLeft/top/right/bottom）+ 目标尺寸 + DPI 渲染 BGRA 位图 |
| `get_page_chars()` | 获取页面所有字符的位置信息（用于文字选择） |
| `export_pdf_with_annotations()` | 将批注渲染导出为新的 PDF 文件副本 |

**关键技术细节**：
- **全局文档管理**：使用 `static Lazy<Mutex<HashMap<String, PdfDocumentWrapper>>>` 存储所有打开的文档，通过 UUID 标识。
- **unsafe 代码**：`render_viewport()` 中使用 `unsafe` 直接调用 PDFium C API（`FPDFBitmap_Create`、`FPDF_RenderPageBitmap` 等），这是 FFI 的本质——跨语言调用不可避免要处理指针。
- **DPI 渲染**：`render_viewport()` 接受可选的 `render_dpi` 参数，根据 DPI 计算缩放因子（`dpi_scale = dpi / 72.0`），实现高清切片渲染。
- **坐标系转换**：PDF 坐标系的原点在左下角，Flutter 坐标系在左上角。`get_page_chars()` 返回的 `CharInfo` 中 `top/bottom` 是 PDF 坐标，Dart 层做转换。

**用 408 类比**：`render_viewport()` 的调用流程就像操作系统里的"系统调用"——从用户态（Flutter）通过 FFI 陷入内核态（Rust），操作 PDFium 这个 native 库，拿到渲染结果后返回用户态。

#### [api/storage.rs](file:///d:/starmind/rust/src/api/storage.rs) — 数据存储门面

**作用**：所有数据库操作的统一入口。是 `storage/` 目录下各模块函数的 **门面（Facade）**。

分类如下：

| 类别 | 函数 | 作用 |
|------|------|------|
| 初始化 | `init_storage()` | 初始化 SQLite 数据库 + 记录沙盒路径 |
| 文件夹 | `get_folder_tree()`, `create_folder()`, `rename_folder()`, `delete_folder()` | 文件夹树 CRUD |
| 标签 | `get_tag_tree()`, `create_tag()`, `rename_tag()`, `delete_tag()` | 标签树 CRUD |
| 文档 | `import_pdf()`, `delete_document()`, `get_documents()`, `add_tag_to_document()`, `remove_tag_from_document()` | 文档导入/删除/查询/标签绑定 |
| 批注 | `create_annotation()`, `get_annotations()`, `get_annotations_for_page()`, `update_annotation()`, `delete_annotation()` | 批注 CRUD |
| 思维导图 | `mindmap_create_topic()`, `mindmap_get_topic()`, `mindmap_create_note()`, `mindmap_get_children()`, `mindmap_get_notes_by_pdf()` 等 | 思维导图 Topic/Note 管理 |

**`init_storage()` 函数**：接受 `db_path`（数据库文件路径）和 `sandbox_dir`（PDF 文件存储目录），全局保存沙盒路径（用 `OnceCell`），然后调用 `db::init_db()` 创建表。

---

### 3.3 storage/ — 数据存储实现层

**作用**：实际的业务逻辑和 SQL 操作。用 Java 类比，这就是你的 DAO/Repository 实现类。

#### [storage/db.rs](file:///d:/starmind/rust/src/storage/db.rs) — 数据库初始化

**作用**：管理全局 SQLite 连接，执行 schema 迁移（建表语句）。

**关键设计**：
- 使用 `static Lazy<Mutex<Option<Connection>>>` 管理全局数据库连接（类似 Java 的单例数据源）。
- `with_db()` 辅助函数：获取锁 → 执行闭包 → 释放锁，所有数据库操作都通过它执行。
- **建表 SQL** 在 `init_db()` 中执行，包括 9 张表：
  - `folders`：文件夹表
  - `tags`：标签表
  - `documents`：文档表
  - `document_tags`：文档-标签多对多关系表
  - `annotations`：批注表
  - `mindmap_topics`：思维导图笔记本表
  - `mindmap_notes`：思维导图节点表
  - `media_assets`：媒体资源表（图片等 BLOB 存储）
  - `pdf_configs`：PDF 配置表

#### [storage/folders.rs](file:///d:/starmind/rust/src/storage/folders.rs) — 文件夹操作

| 函数 | 作用 |
|------|------|
| `create_folder()` | 插入新文件夹，返回 UUID |
| `rename_folder()` | 更新文件夹名称 |
| `delete_folder()` | 删除文件夹。如果 `cascade_delete=true`，使用递归 CTE 查找所有子文件夹，删除其中的文档和物理文件；否则仅删除文件夹，文档的 `folder_id` 置 NULL（变成"未分类"） |
| `get_folder_tree()` | 从数据库查询所有文件夹，在内存中构建树形结构返回。先查所有文件夹 + 文档计数，然后递归组装 `FolderNode` 树 |

**SQL 亮点**：`delete_folder()` 使用了递归 CTE（Common Table Expression）来查找所有子文件夹：
```sql
WITH RECURSIVE subfolders(id) AS (
    SELECT ? 
    UNION ALL 
    SELECT f.id FROM folders f INNER JOIN subfolders s ON f.parent_id = s.id
)
SELECT id FROM subfolders;
```
这就像 Java 里递归删除目录树，但用一条 SQL 搞定。

#### [storage/tags.rs](file:///d:/starmind/rust/src/storage/tags.rs) — 标签操作

与 `folders.rs` 结构类似，实现标签的 CRUD 和树形构建。每个标签支持 `color_hex` 自定义颜色。

#### [storage/documents.rs](file:///d:/starmind/rust/src/storage/documents.rs) — 文档操作

| 函数 | 作用 |
|------|------|
| `import_pdf()` | 生成 UUID → 将 PDF 文件物理拷贝到沙盒目录 → 插入数据库记录 |
| `delete_document()` | 查找文件路径 → 删除物理文件 → 删除数据库记录（级联删除标签关联和批注） |
| `add_tag_to_document()` | 绑定标签（INSERT INTO document_tags） |
| `remove_tag_from_document()` | 解绑标签 |
| `get_documents()` | **核心查询函数**——支持文件夹筛选、标签筛选、标题搜索、排序（按修改时间/创建时间/名称）。动态拼接 SQL WHERE 子句，参数化查询防止 SQL 注入 |

**安全设计**：`get_documents()` 使用参数化查询（`rusqlite::params!`），不直接拼接字符串，避免了 SQL 注入风险。

#### [storage/annotations.rs](file:///d:/starmind/rust/src/storage/annotations.rs) — 批注操作

| 函数 | 作用 |
|------|------|
| `create_annotation()` | 插入批注记录 |
| `create_annotation_auto_id()` | 自动生成 UUID 后插入 |
| `get_annotations()` | 获取文档的所有批注（按页码+创建时间排序） |
| `get_annotations_for_page()` | 获取指定页面的批注 |
| `update_annotation()` | 动态更新批注字段（接受 `HashMap<String, String>` 作为更新映射） |
| `delete_annotation()` | 删除单个批注 |
| `delete_annotations_for_document()` | 删除文档的所有批注 |

**数据结构设计**：`AnnotationRecord` 将所有批注类型（高亮、下划线、墨迹、笔记）统一为一个结构体，不同类型使用不同的可选字段。`rects_json` 和 `strokes_json` 以 JSON 字符串存储在 SQLite 的 TEXT 字段中。

#### [storage/mindmap.rs](file:///d:/starmind/rust/src/storage/mindmap.rs) — 思维导图操作

**两个核心实体**：

1. **`Topic`（笔记本/思维导图）**：
   - 字段：id（格式 `0-{UUID}`）、title、author、pdf_ids（管道分隔）、root_note_ids、created_at、updated_at、is_trashed
   - 支持软删除（标记 `is_trashed=1`）

2. **`Note`（节点）**：
   - 字段：id（格式 `1-{UUID}`）、topic_id、parent_id、title、content_json、child_ids（管道分隔）、pdf_id、start_page/end_page、highlight_text、position_x/y、is_collapsed
   - **子节点关系**：`child_ids` 用管道符 `|` 分隔存储（如 `"1-abc|1-def|1-ghi"`）

| 函数 | 作用 |
|------|------|
| `create_topic()` | 创建笔记本 |
| `get_topic_by_id()` | 按 ID 获取笔记本 |
| `update_topic()` | 更新笔记本，自动递增 `sync_version` |
| `trash_topic()` | 软删除笔记本 |
| `get_all_topics()` | 获取所有未删除的笔记本 |
| `create_note()` | 创建节点 |
| `add_child_to_note()` | 添加子节点（追加到 `child_ids` 管道分隔字符串，同时更新子节点的 `parent_id`） |
| `get_note_children()` | 解析 `child_ids` 并批量查询子节点 |
| `get_notes_by_pdf()` | 按 PDF ID 查询关联的节点（用于"查看此 PDF 的所有摘录"） |
| `get_notes_by_topic()` | 按笔记本 ID 查询所有节点 |

**设计特点**：`child_ids` 用管道分隔字符串存储而非独立关联表，这是一种**反范式化**设计——写入时需要字符串拼接，但读取时只需一次查询+字符串分割，适合子节点数量有限的场景（思维导图节点的子节点通常不会太多）。

---

### 3.4 lib.rs 与 frb_generated.rs

| 文件 | 作用 |
|------|------|
| [lib.rs](file:///d:/starmind/rust/src/lib.rs) | 模块声明入口，只有 3 行：声明 `frb_generated`、`api`、`storage` 三个模块 |
| [frb_generated.rs](file:///d:/starmind/rust/src/frb_generated.rs) | `flutter_rust_bridge` 自动生成的绑定代码，不要手动修改 |

---

## 四、数据流全景

### 4.1 应用启动流程

```
main()
  ├─ WidgetsFlutterBinding.ensureInitialized()     // Flutter 引擎初始化
  ├─ RustLib.init()                                // 加载 Rust 动态库
  ├─ WorkspaceController(FfiStorageRepository())   // 创建控制器，注入 FFI 存储
  ├─ workspaceController.init()                    // 初始化子控制器
  │    ├─ PreferencesController.init()             // 从 SharedPreferences 加载设置
  │    ├─ FfiStorageRepository.initialize()         // → Rust: init_storage()
  │    │    └─ db::init_db()                       // 创建 SQLite 表
  │    ├─ MetadataController.refresh()             // → Rust: get_folder_tree(), get_tag_tree()
  │    └─ DocumentQueryController.refresh()        // → Rust: get_documents()
  └─ runApp(WorkspaceControllerProvider(...))       // 启动 UI
```

### 4.2 PDF 打开流程

```
用户双击文档卡片
  ├─ WorkspaceController.openDocument(doc)
  │    └─ TabNavigationController.openDocument(doc)  // 创建 PDF 标签页
  ├─ _getOrBuildController(docId, filePath)          // 懒创建 PdfViewportController
  │    └─ PdfViewportController.loadDoc(filePath)
  │         └─ PdfDocSession.loadDoc(path)
  │              ├─ PdfService.initialize()           // → Rust: init_pdfium()
  │              ├─ PdfService.loadDocument(path)     // → Rust: load_document()
  │              ├─ PdfService.getPageCount()         // → Rust: get_page_count()
  │              └─ PdfService.getPageSize(0)         // → Rust: get_page_size()
  └─ PdfTabViewport build()                          // 渲染 PDF 页面
       └─ InteractiveCanvasViewer.builder()
            └─ _PdfTabPagesContainer                  // 虚拟化渲染可见页
                 └─ PdfPageWidget
                      └─ PdfService.renderViewport()  // → Rust: render_viewport()
```

### 4.3 批注创建流程

```
用户长按选中 PDF 文字
  ├─ GestureDetector.onLongPressStart
  │    └─ TextSelectionModel.startSelection()         // 开始文字选择
  ├─ 拖动选择
  │    └─ TextSelectionModel.updateSelection()         // 更新选区
  ├─ 松手后弹出工具栏
  │    └─ PdfSelectionToolbar（高亮/下划线等选项）
  ├─ 点击"高亮"
  │    └─ AnnotationController.createHighlight()
  │         ├─ 创建 Annotation.highlight(...)
  │         └─ StorageRepository.createAnnotation()
  │              └─ FfiStorageRepository → Rust FFI
  │                   └─ annotations::create_annotation()
  │                        └─ INSERT INTO annotations ...
  └─ UndoRedoStack.push(...)                           // 记录撤销操作
```

### 4.4 存储层调用链（以获取文件夹树为例）

```
Flutter: WorkspaceController.folderTree
  → MetadataController.folderTree (getter)
  → MetadataController.refresh()
    → StorageRepository.getFolderTree()
      → FfiStorageRepository.getFolderTree()
        → Rust FFI: ffi.getFolderTree()
          → storage.rs: get_folder_tree()
            → folders.rs: get_folder_tree()
              → with_db(|conn| { ... })
                → SELECT id, name, parent_id FROM folders
                → SELECT folder_id, COUNT(*) FROM documents GROUP BY folder_id
                → 递归构建 FolderNode 树
              → 返回 FolderNode
        → Dart: _convertFolderNode(ffiTree)
          → 转换为 Folder 领域模型
      → 返回 Folder
```

---

## 五、关键技术概念速查

| 概念 | 含义 | 在代码中的位置 |
|------|------|--------------|
| **FFI** | Foreign Function Interface，Dart 调用 Rust 函数的桥梁 | `lib/src/rust/` (Dart 侧) + `rust/src/api/` (Rust 侧) |
| **PDFium** | Google 开源的 PDF 渲染库，以 C/C++ 动态库形式存在 | `rust/src/api/pdf.rs` |
| **InheritedWidget** | Flutter 的依赖注入机制，子组件通过 `context` 获取祖先提供的数据 | `workspace_controller_provider.dart` |
| **ChangeNotifier** | Flutter 的观察者模式，状态变化时通知监听者刷新 UI | 所有 Controller 类 |
| **LRU Cache** | Least Recently Used 缓存淘汰策略 | `pdf_doc_session.dart`、`tile_manager.dart` |
| **Repository 模式** | 数据访问抽象，隔离存储实现细节 | `storage_repository.dart`（接口）→ `ffi_storage_repository.dart` / `in_memory_storage_repository.dart` |
| **Mutex** | Rust 中的互斥锁，保护全局共享数据的线程安全 | `db.rs`、`pdf.rs` 中的 `static Lazy<Mutex<...>>` |
| **OnceCell / Lazy** | Rust 中的延迟初始化单例 | `pdf.rs` 的 `PDFIUM`、`db.rs` 的 `DB` |
| **TransformationController** | Flutter 的矩阵变换控制器，实现缩放/平移 | `PdfTabViewport` 中的 `_transformController` |
| **CustomPaint** | Flutter 自定义绘制 API，用于渲染批注和墨迹 | 各种 Renderer Widget |
| **管道分隔字符串** | 用 `\|` 分隔的 ID 列表（如 `"id1\|id2\|id3"`），存储在 SQLite TEXT 字段 | `mindmap.rs` 的 `child_ids`、`pdf_ids` |

---

## 六、文件统计

| 目录 | 文件数（约） | 总行数（约） | 主要语言 |
|------|------------|------------|---------|
| `lib/main.dart` | 1 | ~4100 | Dart |
| `lib/src/domain/` | 9 | ~700 | Dart |
| `lib/src/home/` | 7 | ~600 | Dart |
| `lib/src/pdf/` | ~25 | ~4500 | Dart |
| `lib/src/rust/` | ~8 | ~500（手写部分） | Dart |
| `rust/src/api/` | 4 | ~550 | Rust |
| `rust/src/storage/` | 7 | ~900 | Rust |
| **合计** | **~62** | **~11900** | — |
