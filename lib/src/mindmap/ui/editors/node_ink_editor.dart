// lib/src/mindmap/ui/editors/node_ink_editor.dart
//
// 节点手写层编辑器：Markdown 底层 + 墨迹层上层。
//
// 架构：
// - Stack 布局：Markdown widget 在底层，墨迹层在上层
// - 墨迹层：Listener + CustomPaint（复用 CanvasInkLayer）
// - 穿透控制：IgnorePointer(ignoring: !isInkActive) 控制事件穿透
// - ownerType = InkLayerOwnerType.node，ownerId = note.id
// - 撤销/重做：环形 buffer 保留最近 20 步（通过 InkLayerController）

import 'package:flutter/material.dart';

import '../../ink/ink_layer.dart';
import '../../ink/ink_layer_controller.dart';
import '../../ink/canvas_ink_layer.dart';

/// 节点手写层编辑器。
///
/// 使用 Stack 布局，Markdown 内容在底层，墨迹层在上层。
/// 通过 [isInkActive] 控制事件穿透：
/// - `false`：事件穿透到 Markdown widget
/// - `true`：事件由墨迹层捕获，绘制笔画
///
/// 撤销/重做通过 [InkLayerController] 的环形 buffer 实现（保留最近 20 步）。
///
/// @param noteId 关联的节点 ID。
/// @param inkController 墨迹层控制器。
/// @param isInkActive 是否激活墨迹模式。
/// @param markdownWidget Markdown 编辑器 widget（底层）。
class NodeInkEditor extends StatelessWidget {
  const NodeInkEditor({
    super.key,
    required this.noteId,
    required this.inkController,
    required this.isInkActive,
    required this.markdownWidget,
  });

  /// 关联的节点 ID（ownerId）
  final String noteId;

  /// 墨迹层控制器
  final InkLayerController inkController;

  /// 是否激活墨迹模式
  final bool isInkActive;

  /// Markdown 编辑器 widget（底层）
  final Widget markdownWidget;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 底层：Markdown 编辑器
        markdownWidget,

        // 上层：墨迹层
        // 使用 IgnorePointer 控制事件穿透
        IgnorePointer(
          ignoring: !isInkActive,
          child: _InkLayerWithListener(
            controller: inkController,
            ownerType: InkLayerOwnerType.node,
            ownerId: noteId,
            enabled: isInkActive,
          ),
        ),
      ],
    );
  }
}

/// 带手势监听的墨迹层。
///
/// 在墨迹模式下通过 [Listener] 捕获触摸事件并驱动 [InkLayerController]。
/// 使用 [CanvasInkLayer] 渲染笔画。
class _InkLayerWithListener extends StatelessWidget {
  const _InkLayerWithListener({
    required this.controller,
    required this.ownerType,
    required this.ownerId,
    required this.enabled,
  });

  final InkLayerController controller;
  final InkLayerOwnerType ownerType;
  final String ownerId;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      // 非墨迹模式：只渲染，不监听手势
      return CanvasInkLayer(
        controller: controller,
        ownerType: ownerType,
        ownerId: ownerId,
        enabled: false,
      );
    }

    // 墨迹模式：使用 Listener 捕获触摸事件
    return Listener(
      onPointerDown: (event) {
        controller.beginStroke(
          ownerType,
          ownerId,
          event.localPosition,
          pressure: event.pressure,
        );
      },
      onPointerMove: (event) {
        controller.appendPoint(
          event.localPosition,
          pressure: event.pressure,
        );
      },
      onPointerUp: (event) {
        controller.endStroke(ownerType, ownerId);
      },
      onPointerCancel: (event) {
        // 取消时丢弃当前笔画
        controller.endStroke(ownerType, ownerId);
      },
      child: CanvasInkLayer(
        controller: controller,
        ownerType: ownerType,
        ownerId: ownerId,
        enabled: true,
      ),
    );
  }
}
