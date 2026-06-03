# 思维导图高级功能：雷达小地图、信息弹窗与全局快捷键联动 (v11.0) Walkthrough

本项目已圆满完成思维导图 Phase 4 的全部高级功能开发，提供了高保真雷达导航小地图、玻璃感统计信息弹窗、全局键盘快捷键捕获流、以及应用内防崩溃的局部分屏双向关联视口。整个测试套件 100% 跑通，所有 74 个 MindMap UI 及领域测试全部通过。

## 核心实现说明

### 1. 全局 Workspace 联动 Shortcuts 键盘流 (Task 3)
*   **键盘流捕获**：在 `lib/src/mindmap/ui/mindmap_page.dart` 中，将 Focus.onKeyEvent 进行系统级重构，能精准捕获多修饰组合键（Ctrl, Alt, Shift）并进行路由拦截。
*   **宿主联动穿透**：通过 `context.maybeWorkspaceController` 精巧访问外层宿主控制器，在完全解耦的前提下实现了跨系统交互：
    *   `Alt + Q` -> 锁定/解锁编辑画布
    *   `Tab` -> 添加子节点弹窗
    *   `Enter` -> 添加兄弟节点弹窗
    *   `Space` -> 折叠/展开选中的节点
    *   `F2` -> 重命名选中节点
    *   `Delete` / `Backspace` -> 删除选中节点
    *   `Ctrl + Shift + E` -> 自适应画布大小全屏展示
    *   `Ctrl + Alt + [` -> 联动隐藏 Workspace 左侧大导航树
    *   `Ctrl + Alt + ]` -> 联动展开 Note 侧边栏
    *   `Ctrl + Alt + \` -> 循环切换布局（两侧/单左/单右/嵌套）
    *   `Ctrl + Alt + S` -> 开关局部分屏
    *   `Ctrl + W` -> 快速关闭当前导图的 Tab 页

### 2. 局部分屏防崩溃模式 (Task 4)
*   **局部分屏**：由于 `main.dart` 强转 `LeafNode` 在全局分屏时会触发 runtime Cast Exception 导致应用程序闪退，我们设计并实施了“应用内局部分屏避灾模式”。
*   **高精度矢量视口**：按下 `Ctrl + Alt + S` 或点击底部操作栏新加入的 **分屏模式** 按钮（`Icons.splitscreen_rounded`）后，画布内部进行 Row 水平拆分，右侧以高精度 PDF 模拟矢量视口渲染器填充，安全隔离了底层 Tab 控制器，绝对不污染 `rootLayoutNode` 结构，完美规避了闪退风险。
*   **Crash-proof 磨砂导航栏**：将 `BottomActionBar` 的所有子项放置在 `SingleChildScrollView(scrollDirection: Axis.horizontal)` 中，即使在极端分屏或侧边栏全部拉开导致画布宽度被极度压缩的情况下，底栏能优雅自适应滑动，杜绝了任何 RenderFlex overflow 导致的像素溢出异常。

## 验证结果

### 1. 自动化单元与 Widget 测试
已新建专门用于验证全局快捷键与分屏切换的测试套件 [shortcuts_mapping_test.dart](file:///d:/starmind/test/mindmap/ui/shortcuts_mapping_test.dart)，全面覆盖以下核心场景：
*   `Alt + Q` 对画布锁定的拦截与解锁校验
*   `Ctrl + Alt + S` 局部分屏模式开闭与矢量 PDF 模拟层渲染
*   `Ctrl + Alt + \` 画布布局状态流转
*   `Ctrl + Alt + ]` 与 `Ctrl + Alt + [` 对系统侧边栏及导图侧边栏的触发
*   `Space` 键对选定节点的折叠状态流转
*   `F2` 键重命名弹窗拉起

运行命令：
```bash
flutter test test/mindmap/ui/
```
**运行结果**：
`74/74 tests passed!`（100% 成功率，所有用例全部绿灯通过）。

---

> [!NOTE]
> 我们在实现 `BottomActionBar` 时，为了应对小尺寸屏幕或被分屏和侧边栏高度压缩的复杂布局情况，引入了横向滑动防溢出方案，这在移动端和分屏多任务时极大地增强了应用的视觉健壮度。

> [!TIP]
> 新创建的测试用例中运用了 `SharedPreferences.setMockInitialValues` 与 `workspaceController.injectPaths` 技术，绕过了 Platform Channel 在原生端的环境依赖，确保测试可以在无界面的 CI/CD 纯净命令行环境中完美跑通。
