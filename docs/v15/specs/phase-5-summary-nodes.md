# Phase 5 Spec：概要节点

## 背景

概要节点用于把一组兄弟节点归纳为一个说明。可参考 `E:/app/wanglin-mindmap/simple-mind-map/src/core/render/Render.js` 的 `ADD_GENERALIZATION` 流程、`nodeGeneralization.js` 的概要节点生命周期，以及各布局中的 `renderGeneralization` 对布局边界、概要线和概要节点的处理方式；也可参考 `D:/package/mind_map_flutter` 的 `SummaryData(parentNodeId, startIndex, endIndex)` 区间模型。本项目应结合 Flutter 布局结果实现。

## 用户故事

- 作为用户，我框选或多选一组节点后点击“创建概要”，可以生成一个概要节点。
- 作为用户，我可以编辑概要节点文字，默认文字为“概要”。
- 作为用户，我切换布局或折叠节点后，概要线和概要节点位置仍合理。

## 数据模型建议

新增 Dart domain：`lib/src/mindmap/domain/mindmap_summary.dart`。

字段建议：

- `id`：概要 ID。
- `topicId`：所属导图。
- `parentId`：概要所属父节点。概要覆盖的是该父节点下的一段连续子节点。
- `startIndex`：覆盖范围在父节点子节点列表中的起始索引。
- `endIndex`：覆盖范围在父节点子节点列表中的结束索引。
- `text`：默认“概要”。
- `createdAt`、`updatedAt`。

不建议长期使用 `coveredNoteIds` 保存任意节点集合；参考实现均以父节点下的连续索引区间表达概要，布局和导入导出也更稳定。

## 项目落点

- `lib/src/mindmap/domain/mindmap_summary.dart`：新增概要模型。
- `lib/src/mindmap/layout/layout_result.dart`：扩展可选概要布局结果，例如概要线 Path、概要节点 Rect。
- `lib/src/mindmap/layout/tree_layout_engine.dart`：计算概要节点需要占用的额外边界，避免概要与普通节点重叠。
- `lib/src/mindmap/ui/canvas_painter.dart`：绘制概要括线或曲线。
- `lib/src/mindmap/ui/node_widget.dart` 或新增 `summary_node_widget.dart`：展示并编辑概要文本。
- `lib/src/mindmap/ui/mindmap_controller.dart`：基于多选集合创建概要。

## 选择规则

1. v15 支持同一父节点下的一段连续兄弟节点创建概要。
2. 如果多选节点属于同一父节点但不连续，按最小连续区间创建概要，即覆盖从最小索引到最大索引之间的全部兄弟节点。
3. 如果选择跨父节点节点，按参考实现先按父节点拆分为多个概要区间，并一次创建多个概要。
3. 单选节点创建概要时，可覆盖该节点自身，便于快速记录。
4. 概要节点不是普通子节点，不参与父子树结构递归；它附着在一组节点范围上。
5. 框架内部概要作为后续增强，在 Phase 7 已知限制文档中记录。
6. 重复创建相同 `parentId + startIndex + endIndex` 的概要时，不新增重复概要。
7. 父节点折叠时，隐藏该父节点下的概要线和概要节点。
8. 删除或移动节点后，如果概要区间索引越界，则删除该概要；如果区间仍有效，则按当前索引区间重新渲染。

## 布局规则

- 右侧布局：概要节点放在被覆盖节点右侧。
- 左侧布局：概要节点放在被覆盖节点左侧。
- 两侧布局：根据被覆盖节点所在侧决定概要方向。
- 框架式布局：先支持框架外层普通概要；框架内部概要可作为后续增强。

## 样式规则

- 概要线使用直角折线。

## 验收标准

- 多选连续兄弟节点后可创建概要。
- 概要线覆盖范围与真实节点边界一致。
- 概要文本可原地编辑。
- 切换左右布局后，概要节点方向同步变化。
