# Starmind Phase 3: 首页仪表盘、多级元数据存储与通用导航分屏引擎 (v9.0)

本计划旨在对已在工作区内实现但尚未提交的 **Starmind Phase 3 核心功能** 进行验证、完善和整合。该阶段的重点是搭建 Space-Dark 磨砂玻璃首页仪表盘，支持无限级文件夹与标签的 Rust SQLite 存储，以及提供支持多 Tab 导航的布局引擎。

---

## 1. 核心架构与模块说明

### 1.1 文件夹与标签多级元数据存储
*   在 Rust 侧设计并实现 SQLite Schema (`folders`, `tags`, `documents`, `document_tags`)，采用 UUID 主键。
*   通过 `flutter_rust_bridge` 提供一次性整树获取（FolderNode, TagNode）和 CRUD/FFI 管理方法。

### 1.2 首页仪表盘与侧边栏导航树
*   首页仪表盘 (`HomeDashboard`) 支持分类视图选择（全部、笔记、PDF）和模糊搜索排序。
*   侧边栏 (`SidebarWidget`) 动态展示文件夹与标签层级树，支持右键/长按调出磨砂玻璃上下文菜单（新建子项、重命名、删除）。
*   删除文件夹时支持二次弹窗选择（级联删除或保留文档至未分类）。

### 1.3 多 Tab 导航
*   `TabNavigationController` 维护一个 `SplitNode` 布局树模型。
*   支持在叶子节点 `LeafNode` 下动态打开、关闭或切换不同类型的标签页（Home, PDF, MindMap）。

---

## 2. 拟验证与提交文件 (Proposed Validation Changes)

目前相关实现已基本存在于工作区未提交的文件中，我们将通过子代理对以下文件进行全面验证和细微优化调整：

*   [main.dart](file:///d:/starmind/lib/main.dart): 包含 `WorkspacePage` 侧栏和 `HomeDashboard` 视觉渲染及交互弹窗。
*   [workspace_controller.dart](file:///d:/starmind/lib/src/home/workspace_controller.dart) 和各子 Controller:
    *   [metadata_controller.dart](file:///d:/starmind/lib/src/home/metadata_controller.dart)
    *   [document_query_controller.dart](file:///d:/starmind/lib/src/home/document_query_controller.dart)
    *   [tab_navigation_controller.dart](file:///d:/starmind/lib/src/home/tab_navigation_controller.dart)
*   [rust/src/api/storage.rs](file:///d:/starmind/rust/src/api/storage.rs) 与底层的 `storage/` 模块: 验证 Rust SQLite Schema 与 FFI 方法。
*   **单元测试文件**:
    *   [workspace_controller_test.dart](file:///d:/starmind/test/domain/workspace_controller_test.dart)
    *   [tab_navigation_controller_test.dart](file:///d:/starmind/test/domain/tab_navigation_controller_test.dart)
    *   [metadata_controller_test.dart](file:///d:/starmind/test/domain/metadata_controller_test.dart)

---

## 3. 验证计划 (Verification Plan)

### 3.1 自动化测试
*   运行 `flutter analyze` 验证零编译警告。
*   运行 `flutter test test/domain/` 验证 99 个领域模型及控制器测试全部通过。
*   运行 `flutter test` 跑通项目全套测试集。

### 3.2 手工交互验证
*   首页仪表盘 Glassmorphism 模糊背景和 Orbs 渐变层渲染正确。
*   导入 PDF 时调起 `FilePicker` 并正确拷贝至沙盒目录中，且生成独一无二的 SQLite 关联记录。
*   侧边栏右键菜单能正常触发文件夹/标签的增删改查。
