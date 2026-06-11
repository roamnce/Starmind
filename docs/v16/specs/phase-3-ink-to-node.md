# Phase 3: 手写转节点 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development`（推荐）或 `superpowers:executing-plans` 按 task 推进。所有 Step 用 `- [ ]` checkbox 跟踪。

**Goal:** （1）套索工具自由绘制路径，选中范围内的墨迹笔画，弹菜单做移动/删除；（2）可选开关的手势识别：圆形/矩形 → 创建节点，箭头 → 创建连线。

**Architecture:** 沿用 Phase 1 的 `CanvasInteractMode.lasso`（已存在），新增 `LassoSelector`（射线法判断 stroke 是否在套索内）和 `LassoActionMenu`；扩展 `InkLayerController.moveStrokes` 支持平移选中笔画；手势识别用 \$1 算法（templates: circle / rectangle / arrow），仅在 `InkSettings.gestureRecognitionEnabled=true` 时识别，**阈值 0.9**（避免自然书写中圆/0/反复涂圈被误判）。

**Tech Stack:** Flutter + Phase 1 / Phase 2 的 ink 基础设施；\$1 Gesture Recognizer（自实现或 `dart_ml`/类似包）。

---

## 背景

MarginNote 的差异化体验：用户可用手写方式构建思维导图，而不依赖键盘输入。Phase 3 实现基础能力：套索选择墨迹、手势绘制形状自动创建节点/连线。

OCR 手写转文本暂不实现，后续版本再加入。

---

## 功能规格

### 3.1 套索选择

套索工具用于选择墨迹进行批量操作：

```
[套索工具] → 自由绘制蓝色路径 → 选中路径内墨迹 → 弹出菜单
                                           ↓
                                      [移动] [删除]
```

**视觉设计：**
- 套索路径：蓝色半透明线条显示
- 选中墨迹：高亮显示（加粗/发光效果）

**操作菜单：**
| 选项 | 功能 |
|------|------|
| 移动 | 拖动选中的墨迹到新位置 |
| 删除 | 删除选中的墨迹 |

**技术要点：**
- 自由绘制套索路径（不限于矩形）
- 射线法判断笔画是否在套索区域内
- 支持跨多个手写笔画选择

### 3.2 手势识别（可选功能）

绘制预设形状自动创建节点/连线：

| 手势 | 结果 |
|------|------|
| 圆形 | 创建矩形节点（位置在圆心） |
| 矩形 | 创建矩形节点（位置在矩形中心） |
| 箺头 | 创建普通连线（起点→终点最近的节点） |

**设置开关：**
- 默认关闭，需在设置中手动开启
- 用户可随时开关此功能

**执行方式：**
- 手势结束立即执行，无需确认弹窗

**识别阈值：**
- 相似度 > 0.9 触发对应操作
- 低于阈值则视为普通墨迹

### 3.3 数据模型扩展

无需扩展数据模型，手势创建的节点/连线与普通节点/连线一致。

---

## 技术方案

每个 Plan 都按「写失败测试 → 跑 FAIL → 写最小实现 → 跑 PASS → graphify → commit」的 TDD 节奏。

---

### Plan 3-A：套索选择器（纯函数 + 射线法）

**文件:**
- 创建: `lib/src/mindmap/ui/components/lasso_selector.dart`
- 测试: `test/mindmap/ui/components/lasso_selector_test.dart`

- [ ] **Step 1: 写失败测试**

```dart
test('isInsidePath returns true for point inside closed polygon', () {
  final selector = LassoSelector(path: [Offset(0,0), Offset(100,0), Offset(100,100), Offset(0,100)]);
  expect(selector.isInsidePath(const Offset(50, 50)), isTrue);
  expect(selector.isInsidePath(const Offset(200, 200)), isFalse);
});

test('getSelectedStrokes returns strokes whose any point falls inside', () {
  final stroke = InkStroke(id: 's1', tool: InkTool.pen, color: 0xFF000000, width: 2,
      points: const [InkPoint(50, 50)], createdAt: DateTime(2026, 1, 1));
  final selector = LassoSelector(
    path: const [Offset(0, 0), Offset(100, 0), Offset(100, 100), Offset(0, 100)],
    allStrokes: [stroke],
  );
  expect(selector.getSelectedStrokes().map((s) => s.id), ['s1']);
});
```

- [ ] **Step 2: 跑测试 → FAIL**（class 不存在）
- [ ] **Step 3: 实现 `LassoSelector`**（射线法 even-odd 判断；自动闭合 path 末尾到首尾的线段）
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(ink): add LassoSelector with ray-casting hit test`

---

### Plan 3-B：套索操作菜单

**文件:**
- 创建: `lib/src/mindmap/ui/dialogs/lasso_action_menu.dart`
- 测试: `test/mindmap/ui/dialogs/lasso_action_menu_test.dart`

- [ ] **Step 1: 写 widget 测试** — 渲染 `LassoActionMenu(onMove: ..., onDelete: ...)`，断言两个按钮存在，点击触发对应回调
- [ ] **Step 2: 跑测试 → FAIL**
- [ ] **Step 3: 实现** — forui `FCard` + 两个 `FButton.icon`（移动 / 删除），定位在套索区域上方居中
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(ink): add LassoActionMenu`

---

### Plan 3-C：墨迹移动（按 stroke id 平移）

**文件:**
- 修改: `lib/src/mindmap/ink/ink_layer_controller.dart`
- 修改: `lib/src/mindmap/ink/ink_layer.dart`（如果 `InkLayer` 没有按 id 替换 stroke 的能力）
- 测试: `test/mindmap/ink/ink_layer_controller_test.dart`（追加）

- [ ] **Step 1: 写测试**

```dart
test('moveStrokes shifts only matching strokes by delta', () {
  final controller = InkLayerController();
  // 注入两个 stroke，s1 / s2
  controller.beginStroke(InkLayerOwnerType.canvas, 't1', const Offset(0, 0));
  controller.appendPoint(const Offset(10, 10));
  final s1 = controller.endStroke(InkLayerOwnerType.canvas, 't1')!;

  controller.moveStrokes(InkLayerOwnerType.canvas, 't1', [s1.id], const Offset(5, 5));
  final layer = controller.getLayer(InkLayerOwnerType.canvas, 't1')!;
  expect(layer.strokes.first.points.first.offset, const Offset(5, 5));
});
```

- [ ] **Step 2: 跑测试 → FAIL**
- [ ] **Step 3: 在 `InkLayerController` 加 `void moveStrokes(ownerType, ownerId, List<String> ids, Offset delta)`，内部 `layer.copyWith(strokes: strokes.map((s) => ids.contains(s.id) ? s.translate(delta) : s).toList())` + `notifyListeners`**
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(ink): add moveStrokes for lasso translation`

---

### Plan 3-D：\$1 手势识别器

**文件:**
- 创建: `lib/src/mindmap/services/gesture_recognizer.dart`
- 创建: `lib/src/mindmap/services/gesture_templates.dart`（圆 / 矩形 / 箭头三套模板点）
- 测试: `test/mindmap/services/gesture_recognizer_test.dart`

**算法：** \$1 Unistroke Recognizer — 采样 64 点 → 旋转到 indicative angle → 缩放到 250×250 box → 平移到原点 → 与模板比较 path distance → 转换为 score `1 - d / (0.5 * sqrt(250^2 * 2))`，最高 score 模板若 > 0.9 即返回，否则返回 null。

- [ ] **Step 1: 写测试** — 给一个标准 36 点圆形 path，断言 `recognize` 返回 `'circle'` 且 score > 0.9；给随机折线 path，断言返回 null
- [ ] **Step 2: 跑测试 → FAIL**
- [ ] **Step 3: 实现** — `resample / rotateToZero / scaleTo / translateTo / pathDistance` 五个 helper 函数 + `recognize` 主流程；模板用 32 个采样点定义在 `gesture_templates.dart`
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(ink): add $1 unistroke recognizer with circle/rectangle/arrow templates`

---

### Plan 3-E：手势执行接入 MindMapPage

**文件:**
- 修改: `lib/src/mindmap/ui/mindmap_page.dart`
- 测试: `test/mindmap/ui/mindmap_page_gesture_test.dart`

- [ ] **Step 1: 写 widget 测试** — 启用 `InkSettings.gestureRecognitionEnabled=true`，模拟画一个圆 stroke，断言 `controller.notes.length` 增加 1，新节点 center ≈ 圆心
- [ ] **Step 2: 跑测试 → FAIL**
- [ ] **Step 3: 实现** — `onPointerUp` 拿到 stroke 后，若手势识别开关打开，调用 `GestureRecognizer.recognize(stroke.points.map(...).toList())`；命中 `'circle' / 'rectangle'` → `controller.addNodeAtPosition(center)` 且丢弃 stroke；命中 `'arrow'` → `controller.addConnection(startNode.id, endNode.id)` 且丢弃 stroke；未命中保留为普通墨迹
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(ink): wire gesture recognizer to node/connection creation`

---

### Plan 3-F：设置开关

**文件:**
- 创建: `lib/src/settings/ink_settings.dart`
- 修改: `lib/src/mindmap/ui/mindmap_page.dart`（读取设置）
- 测试: `test/settings/ink_settings_test.dart`

- [ ] **Step 1: 写测试** — `InkSettings` 默认 `gestureRecognitionEnabled = false`，调用 `setGestureRecognition(true)` 后值变更，监听器收到通知
- [ ] **Step 2: 跑测试 → FAIL**
- [ ] **Step 3: 实现 `InkSettings extends ChangeNotifier`**，持久化到 `SharedPreferences`；在 `WorkspacePage` 注入并传给 `MindMapPage`
- [ ] **Step 4: 跑测试 → PASS**
- [ ] **Step 5:** `/graphify` + commit `feat(settings): add InkSettings with gesture recognition toggle`

---

## 交付物清单

| 文件路径 | 说明 |
|----------|------|
| `lib/src/mindmap/ui/components/lasso_selector.dart` | 套索选择器（蓝色线条） |
| `lib/src/mindmap/ui/dialogs/lasso_action_menu.dart` | 套索操作菜单（移动/删除） |
| `lib/src/mindmap/services/gesture_recognizer.dart` | 手势识别器（$1 算法） |
| `lib/src/settings/ink_settings.dart` | 手写设置（手势开关） |
| `lib/src/mindmap/ink/ink_layer_controller.dart` | 墨迹移动方法 |

---

## 验收标准

- [ ] 套索工具可自由绘制蓝色路径
- [ ] 套索路径内的墨迹被选中并高亮
- [ ] 圈选后弹出菜单（移动/删除）
- [ ] 移动操作可将选中墨迹拖到新位置
- [ ] 删除操作可删除选中墨迹
- [ ] 设置中可开关手势识别功能
- [ ] 开启手势识别后，绘制圆形/矩形创建节点
- [ ] 开启手势识别后，绘制箭头创建连线
- [ ] 手势识别阈值合理，不易误触发

---

## 依赖

- Phase 1（手写画布层 - 墨迹基础设施）
- Phase 2（节点手写笔记 - 墨迹层存储）

---

## 设计决策（已锁定）

| 决策项 | 选择 | 说明 |
|--------|------|------|
| OCR 识别 | 暂不实现 | 后续版本再加入 |
| 套索菜单 | 移动 + 删除 | 无"创建节点"选项 |
| 墨迹处理 | 仅操作墨迹 | 不创建墨迹节点 |
| 套索样式 | 蓝色线条 | 半透明蓝色路径 |
| 手势识别 | 可选开关 | 默认关闭 |
| 手势类型 | 圆形、矩形、箭头 | 分隔线不实现 |
| 节点样式 | 矩形节点 | 与普通节点一致 |
| 箭头连线 | 普通连线 | 不创建关联线 |
| 执行方式 | 立即执行 | 无确认弹窗 |
| 识别阈值 | 0.9 | 相似度 > 90% 触发；0.8 在自然书写中误触率过高（圆/0/反复涂圈），提到 0.9 平衡可用性与误触 |

---

## 待澄清问题

无