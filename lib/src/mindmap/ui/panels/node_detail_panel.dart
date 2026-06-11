// lib/src/mindmap/ui/panels/node_detail_panel.dart
//
// 底部弹出的节点详情面板。
//
// 使用 DraggableScrollableSheet 实现可拖拽高度的底部面板，
// 包含标题栏、Markdown 内容区、手写笔记区、工具栏四个 slot。

import 'dart:ui';
import 'package:flutter/material.dart';
import '../../domain/note.dart';

/// 底部弹出的节点详情面板。
///
/// 使用 [DraggableScrollableSheet] 实现可拖拽高度的底部面板。
/// 布局结构：
/// ```
/// ┌─────────────────────────────────────────┐
/// │ ───────                              [×] │  ← 拖拽条 + 关闭按钮
/// ├─────────────────────────────────────────┤
/// │ [节点标题 - 可编辑]                     │  ← 标题栏
/// ├─────────────────────────────────────────┤
/// │   Markdown 内容区（slot）               │  ← 占位
/// ├─────────────────────────────────────────┤
/// │   手写笔记区（slot）                    │  ← 占位
/// ├─────────────────────────────────────────┤
/// │   工具栏（slot）                        │  ← 占位
/// └─────────────────────────────────────────┘
/// ```
///
/// @param note 要显示的节点。
/// @param onClose 关闭回调。
/// @param markdownSlot Markdown 编辑器插槽（可选）。
/// @param inkSlot 手写编辑器插槽（可选）。
/// @param toolbarSlot 工具栏插槽（可选）。
class NodeDetailPanel extends StatelessWidget {
  /// 要显示的节点
  final Note note;

  /// 关闭回调
  final VoidCallback onClose;

  /// Markdown 编辑器插槽
  final Widget? markdownSlot;

  /// 手写编辑器插槽
  final Widget? inkSlot;

  /// 工具栏插槽
  final Widget? toolbarSlot;

  const NodeDetailPanel({
    super.key,
    required this.note,
    required this.onClose,
    this.markdownSlot,
    this.inkSlot,
    this.toolbarSlot,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xB814100C),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                border: Border.all(
                  color: const Color(0x14FFDC8C),
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  // 拖拽条 + 关闭按钮
                  _buildHeader(),
                  // 标题栏
                  _buildTitleBar(),
                  // 内容区（Markdown + Ink）
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Markdown slot
                          if (markdownSlot != null)
                            markdownSlot!
                          else
                            _buildPlaceholder('Markdown 内容区'),

                          const SizedBox(height: 16),

                          // Ink slot
                          if (inkSlot != null)
                            inkSlot!
                          else
                            _buildPlaceholder('手写笔记区'),
                        ],
                      ),
                    ),
                  ),
                  // 工具栏 slot
                  if (toolbarSlot != null) toolbarSlot!,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 构建顶部拖拽条和关闭按钮
  Widget _buildHeader() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // 拖拽条
          Expanded(
            child: Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x33FFF8E6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          // 关闭按钮
          InkWell(
            onTap: onClose,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close,
                size: 20,
                color: Color(0xB3FFF8E6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标题栏
  Widget _buildTitleBar() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0x14FFDC8C),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              note.title,
              style: const TextStyle(
                color: Color(0xB3FFF8E6),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // TODO: 编辑按钮（后续 Plan 实现）
        ],
      ),
    );
  }

  /// 构建占位 widget
  Widget _buildPlaceholder(String label) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0x0DFFF8E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0x14FFDC8C),
          width: 1,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0x40FFF8E6),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}