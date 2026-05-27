<!-- 🤖 Generated wholly or partially with Gemini Code; Google Antigravity -->
# Starmind Phase 3 PRD: 首页仪表盘、多级元数据存储与通用导航分屏引擎

## 1. 文档概述

### 1.1 背景
Starmind 在 Phase 2 中实现了高清晰度的 PDF 矢量渲染视口以及划词选择基础。然而，目前的入口极其简陋，且缺乏对大量 PDF 文件的分类与管理能力。
为了提供 MarginNote 级别的完整知识库管理体验，本阶段（Phase 3）将搭建**首页仪表盘（Dashboard）**，支持**多级文件夹（Folders）**、**多级标签（Tags）**、**设置偏好弹窗（Settings）**以及一套高扩展性的**多窗口分屏导航树模型（Workspace Split Tree）**，为未来拖拽任意分屏（PDF、脑图、网页等）奠定底层架构。

### 1.2 目标
*   **精美现代的首页**：完全还原并适配 [index.html](file:///E:/app/starmind/prototype/index.html) 原型图中的 Space-Dark 磨砂玻璃（Glassmorphism）视觉设计。
*   **多级分类管理**：支持无限层级的文件夹与标签树，数据完全持久化到 Rust 侧的 SQLite 中。
*   **高效无感的文件导入**：支持将外部 PDF 文件一键导入，后台自动复制并安全存放到 App 的私有沙盒目录中，且生成独一无二的 SQLite 关联记录。
*   **多 Tab 与导航预留**：实现顶部 Tab 栏的标签页切换，支持首页与 PDF 页面无缝切换，并对后续的多视图（PDF、脑图、网页）任意分屏完成数据模型的设计。

---

## 2. 数据模型设计 (SQLite Schema)

在 Rust 引擎的 SQLite 数据库中，建立以下四张核心元数据表。所有表均使用 UUID 作为主键，以利于未来的云端多端同步与合并。

### 2.1 文件夹表 `folders`
记录多级文件夹的树形结构。
```sql
CREATE TABLE folders (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id TEXT,
    created_at INTEGER NOT NULL,
    FOREIGN KEY(parent_id) REFERENCES folders(id) ON DELETE CASCADE
);
```

### 2.2 标签表 `tags`
记录多级标签的树形结构以及标签的样式颜色。
```sql
CREATE TABLE tags (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    parent_id TEXT,
    color_hex TEXT, -- 存储标签颜色，如 "#5cb8fc"
    created_at INTEGER NOT NULL,
    FOREIGN KEY(parent_id) REFERENCES tags(id) ON DELETE CASCADE
);
```

### 2.3 文档表 `documents`
记录导入的 PDF 文档信息。
```sql
CREATE TABLE documents (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    file_path TEXT NOT NULL, -- 沙盒中的物理绝对路径
    folder_id TEXT, -- 所属文件夹，空表示“未分类”
    created_at INTEGER NOT NULL,
    FOREIGN KEY(folder_id) REFERENCES folders(id) ON DELETE SET NULL
);
```

### 2.4 文档-标签关联表 `document_tags`
实现文档与标签的多对多关联。
```sql
CREATE TABLE document_tags (
    document_id TEXT NOT NULL,
    tag_id TEXT NOT NULL,
    PRIMARY KEY (document_id, tag_id),
    FOREIGN KEY(document_id) REFERENCES documents(id) ON DELETE CASCADE,
    FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
);
```

---

## 3. Rust FFI 接口协议

为了实现一次性整树交换，我们在 Rust api 层需要定义如下嵌套的树形数据结构。

### 3.1 树节点数据结构
```rust
// 文件夹树节点
pub struct FolderNode {
    pub id: String,
    pub name: String,
    pub children: Vec<FolderNode>,
    pub document_count: u32,
}

// 标签树节点
pub struct TagNode {
    pub id: String,
    pub name: String,
    pub children: Vec<TagNode>,
    pub color_hex: Option<String>,
    pub document_count: u32,
}

// 文档基础信息
pub struct DocumentInfo {
    pub id: String,
    pub title: String,
    pub file_path: String,
    pub folder_id: Option<String>,
    pub tag_ids: Vec<String>,
    pub created_at: i64,
}
```

### 3.2 存储与查询接口
```rust
// 1. 初始化数据库与沙盒目录 (在 Flutter 启动时调用)
pub fn init_storage(db_path: String, sandbox_dir: String) -> Result<(), String>;

// 2. 一次性获取整棵文件夹树 (树形结构在 Rust 侧完成构建)
pub fn get_folder_tree() -> Result<FolderNode, String>;

// 3. 一次性获取整棵标签树
pub fn get_tag_tree() -> Result<TagNode, String>;

// 4. 创建文件夹 (返回新增文件夹 ID)
pub fn create_folder(name: String, parent_id: Option<String>) -> Result<String, String>;

// 5. 重命名文件夹
pub fn rename_folder(id: String, new_name: String) -> Result<(), String>;

// 6. 删除文件夹 (delete_documents 如果为 false，则下属文档挪到“未分类”)
pub fn delete_folder(id: String, delete_documents: bool) -> Result<(), String>;

// 7. 创建标签 (返回新增标签 ID)
pub fn create_tag(name: String, parent_id: Option<String>, color_hex: Option<String>) -> Result<String, String>;

// 8. 重命名标签
pub fn rename_tag(id: String, new_name: String) -> Result<(), String>;

// 9. 删除标签
pub fn delete_tag(id: String) -> Result<(), String>;

// 10. 导入 PDF 文件 (将 source_path 复制到 sandbox_dir 并写入 DB，返回 doc_id)
pub fn import_pdf(title: String, source_path: String, folder_id: Option<String>) -> Result<String, String>;

// 11. 获取文档列表 (支持可选的文件夹过滤、标签过滤、关键字模糊搜索、按条件排序)
pub fn get_documents(
    folder_id: Option<String>,
    tag_id: Option<String>,
    search_query: Option<String>,
    sort_by: String, // "modified" | "created" | "name"
) -> Result<Vec<DocumentInfo>, String>;

// 12. 从数据库和磁盘上彻底删除文档
pub fn delete_document(id: String) -> Result<(), String>;

// 13. 为文档绑定/解绑标签
pub fn add_tag_to_document(doc_id: String, tag_id: String) -> Result<(), String>;
pub fn remove_tag_from_document(doc_id: String, tag_id: String) -> Result<(), String>;
```

---

## 4. 前端分屏 Tab 导航与分屏树模型

为支持后续的**任意分屏**（PDF 与 PDF、PDF 与脑图、网页与脑图等），我们在 Dart 端设计以下高灵活性分屏树模型，用以动态布局 UI 面板。

### 4.1 数据模型（Dart）
```dart
abstract class SplitNode {
  String get id;
}

// 包含具体 Tab 列表的叶子面板
class LeafNode extends SplitNode {
  @override
  final String id;
  final List<TabItem> tabs;
  final int activeIndex;

  LeafNode({required this.id, required this.tabs, required this.activeIndex});
}

// 物理分屏的父面板
enum SplitDirection { horizontal, vertical }

class ParentNode extends SplitNode {
  @override
  final String id;
  final SplitDirection direction;
  final SplitNode leftOrTop;
  final SplitNode rightOrBottom;
  final double ratio; // 分屏比例，如 0.5

  ParentNode({
    required this.id,
    required this.direction,
    required this.leftOrTop,
    required this.rightOrBottom,
    this.ratio = 0.5,
  });
}
```

在本阶段（Phase 3）的简单应用场景中，我们的默认分屏状态树极其简单：
1. 只有一个 `LeafNode`，里面包含了 `[TabItem(type: Home)]`，其激活索引为 `0`。
2. 用户点击 PDF 卡片时，向该 `LeafNode` 的 `tabs` 列表中追加 `TabItem(type: Pdf, docId: ...)` 并将 activeIndex 设为新增的索引。
3. 界面显示 Tab 栏，用户在 Tab 间直接进行切换。这就完美满足了 Phase 3 的需求，并且为 Phase 4-5 的无限拖拽分屏提供了全套的架构支撑。

---

## 5. 交互流程细化

### 5.1 PDF 文件导入交互
1.  用户在首页点击“导入 PDF”或“导入文件”虚线卡片，弹出 Glassmorphism 模态框。
2.  点击“选择文件”，调起 Flutter `file_picker`，过滤并仅允许选择 `.pdf`。
3.  用户选定物理文件后，Flutter 弹出局部进度指示器，调用 Rust FFI `import_pdf`。
4.  Rust 在后台线程完成以下操作：
    *   在专属沙盒目录下生成唯一的随机文件名以防冲突。
    *   执行文件复制，将原 PDF 安全保存到沙盒。
    *   在 SQLite 数据库中插入一条 `documents` 记录。
5.  FFI 成功返回，主页面的卡片网格刷新，展示出新导入的 PDF。

### 5.2 侧边栏树形菜单与交互
*   **固定小 `+` 号**：文件夹、标签及各自的分类列表旁边固定显示 `+` 按钮，点击立刻弹出小型对话框供输入名字以创建子项。
*   **磨砂上下文菜单（Context Menu）**：
    *   **触发**：Windows 上点击鼠标右键，平板端长按节点触发。
    *   **选项**：
        *   文件夹：`新建子文件夹`、`重命名`、`删除`。
        *   标签：`新建子标签`、`重命名`、`修改颜色`、`删除`。
*   **删除文件夹弹窗选择**：
    *   当点击“删除文件夹”时，如果该文件夹（或其下属子树）包含 PDF 文件，弹窗提示：
        > 💡 是否保留该文件夹下的所有文档？
        > - [选项 A]：仅删除文件夹层级，所有文档移动到“未分类”中。
        > - [选项 B]：彻底级联删除，将文件夹和所有文档移入回收站。
        > - [取消]：取消操作。

---

## 6. 非功能性需求 (NFR)

*   **UI 零闪烁首帧**：主题（深色模式）、侧栏默认展开状态在 Flutter 侧使用 `SharedPreferences` 同步读取并应用，确保界面在渲染首帧时绝无白光闪烁或折叠抖动。
*   **FFI 整树传输延迟**：由于采用一次性整树序列化传输（选项 A），Rust 拼装与 JSON/FFI 的总耗时在 1000 个节点下必须小于 **15ms**，避免阻塞 Flutter UI 主线程。
*   **删除保护**：所有文档及文件夹的物理删除，必须移动到回收站或进行确认弹窗二次警告，绝不允许在没有用户二次确认的情况下直接物理抹除用户数据。
