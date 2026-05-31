# Walkthrough: Task 3 - Markdown 编辑器两行式快捷工具栏

本交付文档记录了思维导图模块 **Task 3: Markdown 编辑器两行式快捷工具栏** 的高保真实现。所有功能都已通过系统静态分析与单元测试。

---

## 1. 核心变更概览

我们为右侧侧边栏的 Markdown 笔记编辑器量身打造了高保真、双行式、零焦点抢占的快捷工具栏，完全契合 Space-Dark 空间暗黑美学：

### A. 双行高保真 Markdown 快捷工具栏 (`MarkdownEditorToolbar`)
- **文件路径**: [markdown_editor_toolbar.dart](file:///d:/starmind/lib/src/mindmap/ui/markdown_editor_toolbar.dart)
- **核心逻辑与布局**:
  - 精妙解决焦点被抢占的问题：在 onTap 交互中使用 `GestureDetector` 或 `InkWell` 时，确保不抢夺 `TextField` 焦点，以保持输入法键盘常驻，并无缝恢复选择。
  - **第一行 (Row 1)**:
    - `H` (Heading `### `)
    - `B` (Bold `**`)
    - `I` (Italic `*`)
    - `S` (Strikethrough `~~`，采用 `textDecoration: TextDecoration.lineThrough` 按钮样式)
    - `Link` (插入 `[]()`，图标为 `Icons.link_rounded`)
    - 垂直分割线 (`Color(0x1F2A3547)`)
    - `Unordered List` (插入 `\n- `，图标为 `Icons.format_list_bulleted_rounded`)
    - `Ordered List` (插入 `\n1. `，图标为 `Icons.format_list_numbered_rounded`)
    - `Task List` (插入 `\n- [ ] `，图标为 `Icons.check_box_outlined`)
    - 垂直分割线
    - `Quote` (插入 `\n> `，图标为 `Icons.send_rounded` 逆时针旋转 90 度形成纸飞机向上状态)
    - `Divider line` (插入 `\n---\n`，图标为 `Icons.horizontal_rule_rounded`)
  - **第二行 (Row 2)**:
    - `Code block` (插入 `\n\`\`\`\n\n\`\`\`\n`，图标为 `Icons.code_rounded`)
    - `Inline code` (插入 `` ` ``，图标为 `Icons.terminal_rounded`)
    - 垂直分割线
    - `Cloud upload` (云上传，图标为 `Icons.cloud_upload_outlined`)
    - `Table` (插入表格模板，图标为 `Icons.grid_on_rounded`)
    - 垂直分割线
    - `Undo` / `Redo` (支持回退和撤销操作)
  - **插入与包裹算法** (`insertMarkdown`):
    - 当没有选中文本时（光标 collapsed），智能地在光标处插入 markdown 标签并移动光标到合适位置。
    - 当有选中文本时，智能包裹选中的文本（如 `**SelectedText**`），并保持选中文本的高亮选择状态，保证连续编辑体验。
    - 自动请求 focusNode 并通过 `SchedulerBinding.instance.addPostFrameCallback` 确保在 TextField 内容渲染完成后精准定位光标。

### B. 侧边栏完美集成 (`MindMapSidebar`)
- **文件路径**: [mindmap_sidebar.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_sidebar.dart)
- **核心集成**:
  - 将 `MarkdownEditorToolbar` 深度嵌入到 `_buildNotePanel` 的标题 Text 和 TextField 输入框容器之间。
  - 为整个 Markdown 工具栏和文本区域提供完全一致的暗黑 Space-Dark 设计语言（包含高品质边线、圆角、背景色以及精致的 hover 微光动效）。

### C. 焦点生命周期控制与传递 (`MindMapPage`)
- **文件路径**: [mindmap_page.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_page.dart)
- **核心逻辑**:
  - `_MindMapPageState` 中负责管理 `_noteFocusNode` 的创建与销毁。
  - 将该 `FocusNode` 顺畅向下传递给 `MindMapSidebar`，并最终绑定到 `MarkdownEditorToolbar` 和 `TextField`，实现工具栏点击时无感知的焦点回拨。

---

## 2. 单元与集成测试验证

我们编写了全自动的挂接测试用例，覆盖各种文本包裹和光标定位场景：
- **测试路径**: [markdown_editor_toolbar_test.dart](file:///d:/starmind/test/mindmap/ui/markdown_editor_toolbar_test.dart)
- **验证点**:
  1. 完美渲染出所有 16 个功能按钮与 fine 分割线。
  2. 点击 Heading 按钮，在光标处插入 `### `，且光标向后移动 4 位，并且 `TextField` 保持 Focus 状态。
  3. 选中一段文本后点击 Bold 按钮，智能使用双星号包裹该文本，并且保持该段文本为选中高亮状态。
  4. 选中一段文本后点击 Strikethrough 按钮，包裹双波浪号 `~~` 并准确维持选中状态。
  5. 选中一段文本后点击 Link 按钮，包裹成 `[text]()` 且光标精准。
  6. 点击 Task List 按钮，插入列表模板 `\n- [ ] ` 并且自动缩进定位。

### 运行测试结果
在 TEMP/TMP 环境下运行全量测试套件：
```powershell
$env:TEMP='D:\temp'; $env:TMP='D:\temp'; flutter test test/mindmap/ui/
```
测试全部编译并 100% 成功通过！

```text
00:00 +0: loading D:/starmind/test/mindmap/ui/canvas_painter_test.dart
00:00 +3: D:/starmind/test/mindmap/ui/markdown_editor_toolbar_test.dart: MarkdownEditorToolbar Tests renders all major Markdown shortcut buttons
...
00:06 +51: All tests passed!
```

**总计 51 项测试全部成功通过 (100% Pass Rate)**，且系统无任何 Dart 分析器警告或编译错误！
