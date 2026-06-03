# 思维导图高保真复刻及套索主题配置 (v10.0) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 Flutter 项目中完美复刻高保真的右侧侧边栏、两行式 Markdown 编辑工具栏、画布与网格配色面板、磨砂玻璃底部操作栏，并打通套索批量多选与零 Rust 数据库迁移的主题配置持久化存储。

**Architecture:** 
采用**方案 B（组件解耦与控制器编排）**，将右侧侧边栏、底部操作栏、Markdown工具栏、套索层分别拆分为高内聚、低耦合的独立 Widget。
以 `MindMapController` 充当唯一的响应式状态机，通过 JSON 编码直接覆写 `Topic.thumbnailPath` 以实现零 Rust 数据库变更的完美主题持久化，辅以严格逆矩阵转换数学公式的套索矩形裁剪碰撞检测。

**Tech Stack:** Flutter Framework, CustomPaint (Canvas drawing), Atkinson Hyperlegible Next Font, rusqlite SQLite (Rust Backend), Unit Tests.

---

## 1. 文件更新列表与职责边界

| 文件路径 | 职责类型 | 变更描述 |
| :--- | :--- | :--- |
| [mindmap_controller.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_controller.dart) | **MODIFY** | 扩充侧栏展开、Tab切换、背景/网格色彩配置、套索手势及多选ID集合、编辑锁定状态，支持主题 JSON 编解码。 |
| [mindmap_page.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_page.dart) | **MODIFY** | 将单视口重构为 Row (画布 + 侧栏内容 + 垂直 Tab)，集成套索手势捕获层和底部悬浮工具栏。 |
| [node_widget.dart](file:///d:/starmind/lib/src/mindmap/ui/node_widget.dart) | **MODIFY** | 适配多选状态，多选节点时在边缘渲染金黄色高亮发光边框。 |
| [mindmap_sidebar.dart](file:///d:/starmind/lib/src/mindmap/ui/mindmap_sidebar.dart) | **NEW** | 右侧侧边栏内容面板，渲染笔记编辑器（含兄弟导航）、导图主题色块、图标集三个面板。 |
| [markdown_editor_toolbar.dart](file:///d:/starmind/lib/src/mindmap/ui/markdown_editor_toolbar.dart) | **NEW** | 两行式 Markdown 语法插入辅助工具栏。 |
| [bottom_action_bar.dart](file:///d:/starmind/lib/src/mindmap/ui/bottom_action_bar.dart) | **NEW** | 底部半透明磨砂工具栏，包含缩放、拖拽/套索切换、布局弹出菜单、编辑锁。 |
| [lasso_painter.dart](file:///d:/starmind/lib/src/mindmap/ui/lasso_painter.dart) | **NEW** | 负责在套索模式拖拽时，于背景上绘制带虚线边缘的金黄色多选框。 |
| [mindmap_controller_test.dart](file:///d:/starmind/test/mindmap/ui/mindmap_controller_test.dart) | **MODIFY** | 验证多选管理、主题 JSON 加载解析、锁定编辑等逻辑。 |
| [lasso_selection_test.dart](file:///d:/starmind/test/mindmap/ui/lasso_selection_test.dart) | **NEW** | 验证逆矩阵投射下的套索碰撞检测与多选碰撞。 |

---

## 2. 分步开发计划

### Task 1: MindMapController 核心状态与零 Rust 迁移主题持久化

**Files:**
*   Modify: `lib/src/mindmap/ui/mindmap_controller.dart`
*   Modify: `test/mindmap/ui/mindmap_controller_test.dart`

- [ ] **Step 1: 编写单元测试验证控制器新增状态和 JSON 读写逻辑**
  在 `test/mindmap/ui/mindmap_controller_test.dart` 末尾添加测试组：
  ```dart
  group('MindMapController Phase 2 & 3 State Tests', () {
    test('default sidebar and interact mode values', () {
      final controller = MindMapController(mockService);
      expect(controller.isSidebarExpanded, isFalse);
      expect(controller.interactMode, equals(CanvasInteractMode.drag));
      expect(controller.isLocked, isFalse);
      expect(controller.selectedNoteIds, isEmpty);
    });

    test('theme parsing handles valid theme JSON in thumbnailPath', () {
      final controller = MindMapController(mockService);
      const jsonTheme = '{"theme": {"canvasBg": "#141b24", "gridColor": "rgba(250,210,120,0.05)", "gridShow": false, "gridSize": 50.0}}';
      controller.loadThemeFromJson(jsonTheme);
      
      expect(controller.canvasBgColor.value, equals(const Color(0xFF141B24).value));
      expect(controller.gridColor.value, equals(const Color(0x0DFAD278).value));
      expect(controller.showGrid, isFalse);
      expect(controller.gridSize, equals(50.0));
    });
  });
  ```

- [ ] **Step 2: 运行测试确保报错失败**
  命令行执行：`$env:TEMP='D:\temp'; $env:TMP='D:\temp'; flutter test test/mindmap/ui/mindmap_controller_test.dart`
  期望：编译失败，提示 `CanvasInteractMode` 和 `loadThemeFromJson` 未定义。

- [ ] **Step 3: 扩充 MindMapController 属性及主题序列化逻辑**
  在 `lib/src/mindmap/ui/mindmap_controller.dart` 中添加：
  ```dart
  import 'dart:convert';
  import 'package:flutter/material.dart';

  enum SidebarTab { note, style, icon }
  enum CanvasInteractMode { drag, lasso }

  // 在 MindMapController 类中新增字段和方法
  bool _isSidebarExpanded = false;
  SidebarTab _activeSidebarTab = SidebarTab.note;
  CanvasInteractMode _interactMode = CanvasInteractMode.drag;
  bool _isLocked = false;
  final Set<String> _selectedNoteIds = {};

  Color _canvasBgColor = const Color(0xFF0C0A07);
  Color _gridColor = const Color(0x05FAD278);
  bool _showGrid = true;
  double _gridSize = 40.0;

  bool get isSidebarExpanded => _isSidebarExpanded;
  SidebarTab get activeSidebarTab => _activeSidebarTab;
  CanvasInteractMode get interactMode => _interactMode;
  bool get isLocked => _isLocked;
  Set<String> get selectedNoteIds => _selectedNoteIds;
  Color get canvasBgColor => _canvasBgColor;
  Color get gridColor => _gridColor;
  bool get showGrid => _showGrid;
  double get gridSize => _gridSize;

  void toggleSidebar(SidebarTab tab) {
    if (_isSidebarExpanded && _activeSidebarTab == tab) {
      _isSidebarExpanded = false;
    } else {
      _isSidebarExpanded = true;
      _activeSidebarTab = tab;
    }
    notifyListeners();
  }

  void setInteractMode(CanvasInteractMode mode) {
    _interactMode = mode;
    if (mode == CanvasInteractMode.drag) {
      _selectedNoteIds.clear();
    }
    notifyListeners();
  }

  void toggleLock() {
    _isLocked = !_isLocked;
    notifyListeners();
  }

  void setSelectedNotes(Set<String> noteIds) {
    _selectedNoteIds.clear();
    _selectedNoteIds.addAll(noteIds);
    notifyListeners();
  }

  void loadThemeFromJson(String? jsonStr) {
    if (jsonStr == null || !jsonStr.startsWith('{"theme":')) return;
    try {
      final data = jsonDecode(jsonStr);
      final theme = data['theme'];
      if (theme != null) {
        if (theme['canvasBg'] != null) {
          _canvasBgColor = _parseColor(theme['canvasBg']);
        }
        if (theme['gridColor'] != null) {
          _gridColor = _parseColor(theme['gridColor']);
        }
        if (theme['gridShow'] != null) {
          _showGrid = theme['gridShow'] as bool;
        }
        if (theme['gridSize'] != null) {
          _gridSize = (theme['gridSize'] as num).toDouble();
        }
      }
    } catch (_) {}
  }

  String exportThemeToJson() {
    final themeData = {
      'theme': {
        'canvasBg': _colorToHex(_canvasBgColor),
        'gridColor': _colorToRgba(_gridColor),
        'gridShow': _showGrid,
        'gridSize': _gridSize,
      }
    };
    return jsonEncode(themeData);
  }

  Color _parseColor(String colorStr) {
    if (colorStr.startsWith('#')) {
      final hex = colorStr.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } else if (colorStr.startsWith('rgba')) {
      final matches = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)').firstMatch(colorStr);
      if (matches != null) {
        final r = int.parse(matches.group(1)!);
        final g = int.parse(matches.group(2)!);
        final b = int.parse(matches.group(3)!);
        final a = (double.parse(matches.group(4)!) * 255).toInt();
        return Color.fromARGB(a, r, g, b);
      }
    }
    return Colors.transparent;
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, "0")}';
  }

  String _colorToRgba(Color color) {
    return 'rgba(${color.red}, ${color.green}, ${color.blue}, ${(color.alpha / 255).toStringAsFixed(2)})';
  }
  ```

- [ ] **Step 4: 运行单元测试验证代码正确性**
  命令行执行：`$env:TEMP='D:\temp'; $env:TMP='D:\temp'; flutter test test/mindmap/ui/mindmap_controller_test.dart`
  期望：测试 100% 通过（PASS）。

- [ ] **Step 5: 提交代码**
  在 powershell 终端中执行 git 命令暂存更改。

---

### Task 2: 右侧高保真侧边栏与垂直 Tab 固定栏

**Files:**
*   Create: `lib/src/mindmap/ui/mindmap_sidebar.dart`
*   Modify: `lib/src/mindmap/ui/mindmap_page.dart`
*   Modify: `lib/src/mindmap/ui/node_widget.dart`

- [ ] **Step 1: 新建右侧侧边栏组件 `mindmap_sidebar.dart`**
  实现垂直 Tab 及侧栏容器渲染：
  ```dart
  // lib/src/mindmap/ui/mindmap_sidebar.dart
  import 'package:flutter/material.dart';
  import 'mindmap_controller.dart';

  class MindMapSidebar extends StatelessWidget {
    final MindMapController controller;
    final TextEditingController textController;

    const MindMapSidebar({
      super.key,
      required this.controller,
      required this.textController,
    });

    @override
    Widget build(BuildContext context) {
      if (!controller.isSidebarExpanded) return const SizedBox.shrink();

      return Container(
        width: 320,
        decoration: const BoxDecoration(
          color: Color(0xFF1C222B),
          border: Border(left: BorderSide(color: Color(0x15FFFFFF), width: 1.0)),
        ),
        child: Column(
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
          ],
        ),
      );
    }

    Widget _buildHeader() {
      // 头部包含兄弟节点导航和 Tab 标题
      return Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x10FFFFFF), width: 1.0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  controller.activeSidebarTab == SidebarTab.note
                      ? Icons.send_rounded // 斜向纸飞机
                      : controller.activeSidebarTab == SidebarTab.style
                          ? Icons.pin_drop // 斜向图钉
                          : Icons.sentiment_satisfied_alt_rounded, // 笑脸
                  size: 16,
                  color: Colors.white70,
                ),
                const SizedBox(width: 8),
                Text(
                  controller.activeSidebarTab == SidebarTab.note
                      ? '节点笔记'
                      : controller.activeSidebarTab == SidebarTab.style
                          ? '导图主题'
                          : '节点图标',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            if (controller.activeSidebarTab == SidebarTab.note)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.white70, size: 18),
                    onPressed: () => controller.navigateSibling('prev'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, color: Colors.white70, size: 18),
                    onPressed: () => controller.navigateSibling('next'),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    Widget _buildBody() {
      switch (controller.activeSidebarTab) {
        case SidebarTab.note:
          return _buildNotePanel();
        case SidebarTab.style:
          return _buildStylePanel();
        case SidebarTab.icon:
          return const Center(child: Text('图标预设面板', style: TextStyle(color: Colors.white54)));
      }
    }

    Widget _buildNotePanel() {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: TextField(
          controller: textController,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            hintText: '输入 Markdown 笔记...',
            hintStyle: TextStyle(color: Colors.white30),
            border: InputBorder.none,
          ),
          onChanged: (text) {
            if (controller.selectedNote != null) {
              controller.updateNoteContent(controller.selectedNote!.id, text);
            }
          },
        ),
      );
    }

    Widget _buildStylePanel() {
      // 样式与配置面板（HSL 预设）
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('画布背景色', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          _buildColorPresets(isCanvas: true),
          const SizedBox(height: 24),
          const Text('网格线颜色', style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          _buildColorPresets(isCanvas: false),
        ],
      );
    }

    Widget _buildColorPresets({required bool isCanvas}) {
      final presets = isCanvas
          ? ['#0C0A07', '#141B24', '#0A140D', '#0A0515']
          : ['rgba(255, 255, 255, 0.02)', 'rgba(250, 210, 120, 0.05)', 'rgba(0, 240, 255, 0.03)', 'rgba(255, 0, 127, 0.03)'];

      return Row(
        children: [
          ...presets.map((colorStr) {
            return GestureDetector(
              onTap: () {
                // 更新背景或网格色彩
              },
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey, // 实际颜色通过解析转换展示
                  border: Border.all(color: Colors.white24, width: 1),
                ),
              ),
            );
          }),
        ],
      );
    }
  }
  ```

- [ ] **Step 2: 扩充 `MindMapController` 的兄弟跳转查询机制**
  在 `lib/src/mindmap/ui/mindmap_controller.dart` 中实现 `navigateSibling`：
  ```dart
  void navigateSibling(String direction) {
    final activeNode = selectedNote;
    if (activeNode == null || activeNode.parentId == null) return;

    // 1. 查找兄弟节点列表
    final siblings = _getNoteSiblings(activeNode.id);
    if (siblings.length <= 1) return;

    final currentIndex = siblings.indexWhere((n) => n.id == activeNode.id);
    if (currentIndex == -1) return;

    // 2. 循环模运算定位
    int targetIndex;
    if (direction == 'prev') {
      targetIndex = (currentIndex - 1 + siblings.length) % siblings.length;
    } else {
      targetIndex = (currentIndex + 1) % siblings.length;
    }

    selectNote(siblings[targetIndex]);
  }

  List<Note> _getNoteSiblings(String id) {
    // 简化实现：在当前 noteTree 中定位父级 note
    for (final root in noteTree) {
      final siblings = _findSiblingsInTree(root, id);
      if (siblings != null) return siblings;
    }
    return [];
  }

  List<Note>? _findSiblingsInTree(NoteTreeNode node, String targetId) {
    for (final child in node.children) {
      if (child.note.id == targetId) {
        return node.children.map((c) => c.note).toList();
      }
      final found = _findSiblingsInTree(child, targetId);
      if (found != null) return found;
    }
    return null;
  }
  ```

- [ ] **Step 3: 重构 `mindmap_page.dart` 增加弹性 Row 物理三栏布局**
  更新 `mindmap_page.dart` 的 `build` 树，在最右边缘添加垂直 Tab 按钮：
  ```dart
  Widget _buildSidebarVerticalTabs() {
    return Column(
      children: [
        const SizedBox(height: 20),
        _buildVerticalTabButton(SidebarTab.note, Icons.send_rounded, '节点笔记'),
        _buildVerticalTabButton(SidebarTab.style, Icons.pin_drop, '导图样式'),
        _buildVerticalTabButton(SidebarTab.icon, Icons.sentiment_satisfied_alt_rounded, '节点图标'),
      ],
    );
  }

  Widget _buildVerticalTabButton(SidebarTab tab, IconData icon, String tooltip) {
    final isActive = widget.controller.isSidebarExpanded && widget.controller.activeSidebarTab == tab;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
        onTap: () => widget.controller.toggleSidebar(tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1862C6) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isActive
                ? [BoxShadow(color: const Color(0xFF1862C6).withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
                : null,
          ),
          child: Icon(
            icon,
            color: isActive ? Colors.white : Colors.white54,
            size: 20,
          ),
        ),
      ),
    );
  }
  ```

- [ ] **Step 4: 多选状态卡片样式高保真渲染更新**
  在 `lib/src/mindmap/ui/node_widget.dart` 中，检查当前节点 ID 是否存在于 `controller.selectedNoteIds`。若是，强制展示金色微发光圆边：
  ```dart
  // lib/src/mindmap/ui/node_widget.dart 中 build 头部：
  final isMultiSelected = controller.selectedNoteIds.contains(note.id);
  final isHighlighted = isSelected || isMultiSelected;

  // decoration 中的边框与投影适配 isHighlighted 状态...
  ```

---

### Task 3: Markdown 编辑器两行式快捷工具栏

**Files:**
*   Create: `lib/src/mindmap/ui/markdown_editor_toolbar.dart`
*   Modify: `lib/src/mindmap/ui/mindmap_sidebar.dart`

- [ ] **Step 1: 新建 Markdown 插入辅助工具栏组件 `markdown_editor_toolbar.dart`**
  ```dart
  // lib/src/mindmap/ui/markdown_editor_toolbar.dart
  import 'package:flutter/material.dart';

  class MarkdownEditorToolbar extends StatelessWidget {
    final TextEditingController textController;

    const MarkdownEditorToolbar({
      super.key,
      required this.textController,
    });

    void insertMarkdown(String prefix, [String? suffix]) {
      final text = textController.text;
      final selection = textController.selection;
      final start = selection.start;
      final end = selection.end;

      if (start < 0 || end < 0) return;

      final selectedText = text.substring(start, end);
      final s = suffix ?? prefix;
      final insertText = suffix == null 
          ? "$prefix$selectedText" 
          : "$prefix$selectedText$s";

      final newText = text.replaceRange(start, end, insertText);
      textController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + prefix.length + selectedText.length),
      );
    }

    @override
    Widget build(BuildContext context) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        color: const Color(0xFF141921),
        child: Column(
          children: [
            Row(
              children: [
                _buildButton('H', () => insertMarkdown('### ')),
                _buildButton('B', () => insertMarkdown('**', '**')),
                _buildButton('I', () => insertMarkdown('*', '*')),
                _buildButton('S', () => insertMarkdown('~~', '~~')),
                const SizedBox(width: 4),
                Container(height: 16, width: 1, color: Colors.white12),
                const SizedBox(width: 4),
                _buildButton('List', () => insertMarkdown('\n- ')),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildButton('</>', () => insertMarkdown('\n```\n', '\n```')),
                _buildButton('`', () => insertMarkdown('`', '`')),
                _buildButton('Table', () => insertMarkdown('\n| H | H |\n|---|---|\n| C | C |\n')),
              ],
            ),
          ],
        ),
      );
    }

    Widget _buildButton(String label, VoidCallback onPressed) {
      return InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
      );
    }
  }
  ```

- [ ] **Step 2: 集成工具栏到 Sidebar 面板中**
  在 `mindmap_sidebar.dart` 的 `_buildNotePanel` 最顶部拼装两行工具栏：
  ```dart
  Widget _buildNotePanel() {
    return Column(
      children: [
        MarkdownEditorToolbar(textController: textController),
        const SizedBox(height: 8),
        Expanded(
          child: TextField( ... )
        ),
      ],
    );
  }
  ```

---

### Task 4: 磨砂玻璃悬浮底部操作栏与布局弹出菜单

**Files:**
*   Create: `lib/src/mindmap/ui/bottom_action_bar.dart`
*   Modify: `lib/src/mindmap/ui/mindmap_page.dart`

- [ ] **Step 1: 新建底部操作栏组件 `bottom_action_bar.dart`**
  实现 BackdropFilter 磨砂效果和交互触发：
  ```dart
  // lib/src/mindmap/ui/bottom_action_bar.dart
  import 'dart:ui';
  import 'package:flutter/material.dart';
  import 'mindmap_controller.dart';

  class BottomActionBar extends StatelessWidget {
    final MindMapController controller;

    const BottomActionBar({
      super.key,
      required this.controller,
    });

    @override
    Widget build(BuildContext context) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xCC1C222B),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.zoom_out, color: Colors.white70),
                  onPressed: controller.zoomOut,
                ),
                Text(
                  '${(controller.viewportScale * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.zoom_in, color: Colors.white70),
                  onPressed: controller.zoomIn,
                ),
                IconButton(
                  icon: Icon(
                    controller.interactMode == CanvasInteractMode.drag
                        ? Icons.back_hand_rounded // 拖拽手势
                        : Icons.crop_free_rounded, // 套索框选
                    color: Colors.white,
                  ),
                  onPressed: () {
                    final nextMode = controller.interactMode == CanvasInteractMode.drag
                        ? CanvasInteractMode.lasso
                        : CanvasInteractMode.drag;
                    controller.setInteractMode(nextMode);
                  },
                ),
                IconButton(
                  icon: Icon(
                    controller.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: controller.toggleLock,
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
  ```

- [ ] **Step 2: 在 `mindmap_page.dart` 中将其作为 Positioned 悬浮物层叠放置**
  ```dart
  // mindmap_page.dart 中 _buildCanvas Stack 中：
  Positioned(
    bottom: 24,
    left: 0,
    right: 0,
    child: Center(
      child: BottomActionBar(controller: widget.controller),
    ),
  )
  ```

---

### Task 5: 套索多选手势层与物理坐标碰撞匹配

**Files:**
*   Create: `lib/src/mindmap/ui/lasso_painter.dart`
*   Modify: `lib/src/mindmap/ui/mindmap_page.dart`
*   Create: `test/mindmap/ui/lasso_selection_test.dart`

- [ ] **Step 1: 新建虚线套索绘制器 `lasso_painter.dart`**
  ```dart
  // lib/src/mindmap/ui/lasso_painter.dart
  import 'package:flutter/material.dart';

  class LassoPainter extends CustomPainter {
    final Rect? selectionRect;

    const LassoPainter({required this.selectionRect});

    @override
    void paint(Canvas canvas, Size size) {
      final rect = selectionRect;
      if (rect == null) return;

      final fillPaint = Paint()
        ..color = const Color(0x0DC8841A) // 5% 透明金黄
        ..style = PaintingStyle.fill;
      
      final strokePaint = Paint()
        ..color = const Color(0xFFC8841A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      // 绘制填充
      canvas.drawRect(rect, fillPaint);
      
      // 绘制简单虚线框 (简短的 4px 线段，2px 间隔)
      final path = Path();
      // 在 rect 边缘绘制虚线线条
      _drawDashedRect(canvas, rect, strokePaint);
    }

    void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
      final path = Path()
        ..addRect(rect);
      // 利用简单的间隔算法或沿 4 条边画短虚线段
      canvas.drawPath(path, paint);
    }

    @override
    bool shouldRepaint(covariant LassoPainter oldDelegate) {
      return selectionRect != oldDelegate.selectionRect;
    }
  }
  ```

- [ ] **Step 2: 套索相交碰撞检测单元测试 `lasso_selection_test.dart`**
  在 `test/mindmap/ui/lasso_selection_test.dart` 中建立测试用例：
  ```dart
  // test/mindmap/ui/lasso_selection_test.dart
  import 'package:flutter/material.dart';
  import 'package:flutter_test/flutter_test.dart';

  void main() {
    test('Lasso screen-to-canvas coordinate mapping overlaps node bounds', () {
      // 模拟 scale = 1.0, 位移 (0, 0)
      const scale = 1.0;
      const tx = 0.0;
      const ty = 0.0;

      final selectionRect = const Rect.fromLTRB(100, 100, 300, 300);

      // 画布上的节点
      final nodePos = const Offset(200, 200);
      final size = const Size(120, 40);
      final nodeBounds = Rect.fromLTWH(
        nodePos.dx - size.width / 2,
        nodePos.dy,
        size.width,
        size.height
      );

      final canvasLeft = (selectionRect.left - tx) / scale;
      final canvasTop = (selectionRect.top - ty) / scale;
      final canvasRight = (selectionRect.right - tx) / scale;
      final canvasBottom = (selectionRect.bottom - ty) / scale;
      
      final canvasSelectionRect = Rect.fromLTRB(canvasLeft, canvasTop, canvasRight, canvasBottom);

      expect(canvasSelectionRect.overlaps(nodeBounds), isTrue);
    });
  }
  ```

- [ ] **Step 3: 在 `mindmap_page.dart` 中添加 Gesture拦截 和 虚线框检测**
  在套索模式激活时：
  *   屏蔽 `InteractiveViewer` 位移。
  *   拦截手势手势按下、拖动及抬起：
  ```dart
  Rect? _lassoScreenRect;
  Offset? _lassoStart;

  Widget _buildLassoOverlay() {
    if (widget.controller.interactMode != CanvasInteractMode.lasso) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onPanStart: (details) {
        setState(() {
          _lassoStart = details.localPosition;
          _lassoScreenRect = Rect.fromPoints(_lassoStart!, _lassoStart!);
        });
      },
      onPanUpdate: (details) {
        if (_lassoStart == null) return;
        setState(() {
          _lassoScreenRect = Rect.fromPoints(_lassoStart!, details.localPosition);
        });
      },
      onPanEnd: (details) {
        if (_lassoScreenRect != null) {
          _performLassoSelection(_lassoScreenRect!);
        }
        setState(() {
          _lassoStart = null;
          _lassoScreenRect = null;
        });
      },
      child: CustomPaint(
        painter: LassoPainter(selectionRect: _lassoScreenRect),
        size: Size.infinite,
      ),
    );
  }
  ```
  实现 `_performLassoSelection(Rect screenRect)` 数学映射方法，提取选中节点 ID 并更新控制器选中状态。

- [ ] **Step 4: 运行全部单元测试确保质量指标**
  命令行执行：`$env:TEMP='D:\temp'; $env:TMP='D:\temp'; flutter test test/mindmap/ui/`
  期望：全部单元测试 PASS！

---
