# Phase 4: PDF 摘录 → 思维导图联动

> **目标：** 从 PDF 高亮摘录的内容可直接成为思维导图节点，实现阅读→结构化的知识闭环

## 背景

MarginNote 的核心工作流：
1. 阅读 PDF，高亮重要段落
2. 摘录自动进入摘录栏
3. 拖拽摘录到思维导图，创建节点
4. 节点保持与 PDF 原位置的链接

**现有基础设施：**
- `PdfViewportWidget` - PDF 渲染组件已实现
- `PdfHighlight` - 高亮模型已实现
- `PdfPosition` - PDF 位置模型已实现
- `AnnotationController` - 注释控制器已实现

---

## 功能规格

### 4.1 分屏布局

PDF 视图 + 思维导图分屏：

```
┌────────────────────┬────────────────────┐
│                    │                    │
│   PDF 视图         │   思维导图         │
│                    │                    │
│   [高亮摘录]       │   [节点]          │
│                    │                    │
├────────────────────┴────────────────────┤
│   摘录栏：[摘录1] [摘录2] [摘录3] ...   │  ← 可折叠
└─────────────────────────────────────────┘
```

**布局特性：**
- 支持：水平分屏 / 垂直分屏（用户可切换）
- 默认比例：1:1 等分
- 分隔线可拖拽调整比例
- 摘录栏固定底部，可折叠展开

### 4.2 摘录数据模型

**复用现有模型：**

| 模型 | 用途 |
|------|------|
| `PdfHighlight` | 高亮区域（文本 + 坐标 + 颜色） |
| `PdfPosition` | PDF 位置锚点（页码 + 坐标） |

**节点扩展：**
```dart
class Note {
  // ... 现有字段
  final String? pdfId;           // 关联 PDF 文档 ID
  final PdfPosition? pdfPosition; // PDF 位置锚点（摘录来源）
}
```

### 4.3 高亮 → 摘录栏

**触发方式（设置可选）：**
- 自动模式：每次 PDF 高亮自动创建摘录
- 手动模式：高亮后点击"添加到摘录栏"按钮

**摘录栏布局：**
- 横向滚动列表
- 每个摘录卡片显示：高亮文本摘要 + 页码
- 卡片可拖拽到思维导图

### 4.4 摘录 → 节点创建

拖拽摘录到思维导图：

```
摘录栏 [摘录卡片] ──拖拽──→ 思维导图画布
                              ↓
                        创建节点
                        - title = 摘录文本
                        - pdfId = PDF 文档 ID
                        - pdfPosition = 摘录位置
```

### 4.5 双向链接

**节点 → PDF：**
- 节点标题显示 PDF 图标（如有 pdfPosition）
- 点击图标 → 平滑动画跳转到 PDF 原位置

**PDF → 节点：**
- 点击 PDF 高亮区域 → 高亮关联的节点（可选）

---

## 技术方案

### Plan 4-A：分屏容器

**目标：** 实现可切换方向的分屏布局

**新建文件：**
- `lib/src/mindmap/ui/panels/split_panel.dart`

**组件结构：**
```dart
class SplitPanel extends StatefulWidget {
  final Widget pdfView;
  final Widget mindmapView;
  final Axis direction;  // horizontal / vertical，可切换
  final double initialRatio;  // 默认 0.5
  final ValueChanged<double>? onRatioChanged;
}
```

**特性：**
- 分隔线可拖拽
- 记住用户调整的比例（可选）
- 支持动态切换 horizontal/vertical

### Plan 4-B：摘录栏

**目标：** 底部可折叠的摘录卡片列表

**新建文件：**
- `lib/src/mindmap/ui/panels/excerpt_bar.dart`

**组件结构：**
```dart
class ExcerptBar extends StatefulWidget {
  final List<PdfHighlight> excerpts;
  final bool isCollapsed;  // 折叠状态
  final VoidCallback? onToggleCollapse;
  final void Function(PdfHighlight excerpt)? onDragToMindMap;
}
```

**交互：**
- 横向滚动列表
- 每个摘录卡片可 Draggable
- 点击折叠按钮展开/收起

### Plan 4-C：摘录服务

**目标：** 管理摘录的创建、存储、删除

**新建文件：**
- `lib/src/mindmap/services/excerpt_service.dart`

**功能：**
```dart
class ExcerptService {
  // 获取当前 PDF 的所有摘录
  List<PdfHighlight> getExcerpts(String pdfId);
  
  // 从高亮创建摘录（根据设置自动或手动）
  Future<void> createExcerptFromHighlight(PdfHighlight highlight);
  
  // 删除摘录
  Future<void> deleteExcerpt(String excerptId);
}
```

### Plan 4-D：思维导图接收区

**目标：** 思维导图画布接收拖拽的摘录

**修改文件：**
- `lib/src/mindmap/ui/mindmap_page.dart`

**变更：**
```dart
// 添加 DragTarget 包装
DragTarget<PdfHighlight>(
  onWillAccept: (excerpt) => excerpt != null,
  onAccept: (excerpt) {
    controller.createNodeFromExcerpt(excerpt);
  },
  builder: (context, candidateData, rejectedData) {
    return MindMapCanvas(...);
  },
)
```

### Plan 4-E：节点 PDF 图标

**目标：** 节点显示 PDF 来源图标，点击跳转

**修改文件：**
- `lib/src/mindmap/ui/node_widget.dart`

**变更：**
1. 检查 `note.pdfPosition` 是否存在
2. 若存在，标题旁显示 PDF 图标
3. 点击图标 → 调用 `pdfNavigator.jumpToPosition(note.pdfPosition)`

### Plan 4-F：PDF 跳转服务

**目标：** 平滑动画跳转到 PDF 位置

**新建文件：**
- `lib/src/mindmap/services/pdf_navigation_service.dart`

**功能：**
```dart
class PdfNavigationService {
  void jumpToPosition(PdfPosition position, PdfViewportController controller) {
    // 平滑动画滚动到目标页
    // 高亮目标区域（短暂闪烁）
  }
}
```

### Plan 4-G：摘录设置

**目标：** 用户可选择摘录创建模式

**新建文件：**
- `lib/src/settings/excerpt_settings.dart`

**设置项：**
```dart
class ExcerptSettings {
  bool autoCreateExcerpt = true;  // 默认自动创建
}
```

---

## 交付物清单

| 文件路径 | 说明 |
|----------|------|
| `lib/src/mindmap/ui/panels/split_panel.dart` | 分屏容器（可切换方向） |
| `lib/src/mindmap/ui/panels/excerpt_bar.dart` | 摘录栏（可折叠、横向滚动） |
| `lib/src/mindmap/services/excerpt_service.dart` | 摘录管理服务 |
| `lib/src/mindmap/services/pdf_navigation_service.dart` | PDF 跳转服务（平滑动画） |
| `lib/src/mindmap/ui/node_widget.dart` | 节点 PDF 图标 |
| `lib/src/mindmap/ui/mindmap_page.dart` | 拖拽接收区 |
| `lib/src/settings/excerpt_settings.dart` | 摘录设置（自动/手动） |

---

## 验收标准

- [ ] PDF + 思维导图可分屏显示（水平/垂直可切换）
- [ ] 分屏比例默认 1:1，可拖拽调整
- [ ] 底部摘录栏可折叠展开
- [ ] 摘录卡片横向滚动排列
- [ ] PDF 高亮可创建摘录（自动/手动可设置）
- [ ] 拖拽摘录到思维导图创建节点
- [ ] 节点标题显示 PDF 图标（如有来源）
- [ ] 点击图标平滑跳转到 PDF 原位置
- [ ] 设置可选择摘录创建模式

---

## 依赖

- **Phase 1**（手写画布层）
- **Phase 2**（节点手写笔记）
- **现有 PDF 基础设施**：
  - `PdfViewportWidget`
  - `PdfHighlight`
  - `PdfPosition`
  - `AnnotationController`

---

## 设计决策（已锁定）

| 决策项 | 选择 | 说明 |
|--------|------|------|
| PDF 渲染 | 复用现有 | PdfViewportWidget 已实现 |
| 摘录模型 | 复用现有 | PdfHighlight + PdfPosition |
| 高亮→摘录 | 设置可选 | 自动或手动，用户可配置 |
| 分屏方向 | 可切换 | 水平/垂直，用户可切换 |
| 分屏比例 | 1:1 默认 | 可拖拽调整 |
| 摘录栏位置 | 底部可折叠 | 横向滚动列表 |
| 节点链接 | PDF 图标 | 点击跳转到原位置 |
| 跳转动画 | 平滑动画 | 滚动 + 高亮闪烁 |

---

## 待澄清问题

无