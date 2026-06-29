// lib/src/mindmap/ui/cards/live_preview/live_preview_toolbar.dart
//
// 浮在卡片顶部的 markdown 格式化工具栏。
//
// 按钮按下时不依赖任何状态树，只是把 [TextEditingController.selection]
// 包裹（已有选区）或在光标处插入占位符（无选区）。借鉴 marktext-plus 的
// _wrapSelection / _insertLinePrefix / _insertBlock 命令式做法。

import 'package:flutter/material.dart';

/// 工具栏按钮可以发起的命令。
enum MdToolbarAction {
  bold,
  italic,
  strikethrough,
  inlineCode,
  heading1,
  heading2,
  heading3,
  bulletList,
  orderedList,
  taskList,
  blockquote,
  codeBlock,
  link,
  image,
  horizontalRule,
}

/// 简单的工具栏 widget。
///
/// 把按钮按下事件路由回 [onAction]，由 [LivePreviewCardBody] 在 controller
/// 上执行实际的文本操作。
class LivePreviewToolbar extends StatelessWidget {
  /// 用户点击按钮的回调。
  final void Function(MdToolbarAction) onAction;

  /// 工具栏前景色。
  final Color iconColor;

  /// 工具栏背景色。
  final Color background;

  const LivePreviewToolbar({
    super.key,
    required this.onAction,
    this.iconColor = const Color(0xFFE6EDF3),
    this.background = const Color(0x14FFFFFF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.format_bold, '加粗 (Ctrl+B)', MdToolbarAction.bold),
            _btn(Icons.format_italic, '斜体 (Ctrl+I)', MdToolbarAction.italic),
            _btn(Icons.format_strikethrough, '删除线', MdToolbarAction.strikethrough),
            _btn(Icons.code, '行内代码', MdToolbarAction.inlineCode),
            _divider(),
            _btn(Icons.title, 'H1', MdToolbarAction.heading1),
            _btn(Icons.title, 'H2', MdToolbarAction.heading2, size: 18),
            _btn(Icons.title, 'H3', MdToolbarAction.heading3, size: 16),
            _divider(),
            _btn(Icons.format_list_bulleted, '无序列表', MdToolbarAction.bulletList),
            _btn(Icons.format_list_numbered, '有序列表', MdToolbarAction.orderedList),
            _btn(Icons.check_box_outlined, '任务列表', MdToolbarAction.taskList),
            _btn(Icons.format_quote, '引用', MdToolbarAction.blockquote),
            _btn(Icons.code_outlined, '代码块', MdToolbarAction.codeBlock),
            _divider(),
            _btn(Icons.link, '链接', MdToolbarAction.link),
            _btn(Icons.image_outlined, '图片', MdToolbarAction.image),
            _btn(Icons.horizontal_rule, '分割线', MdToolbarAction.horizontalRule),
          ],
        ),
      ),
    );
  }

  Widget _btn(IconData icon, String tooltip, MdToolbarAction action, {double size = 18}) {
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => onAction(action),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Icon(icon, size: size, color: iconColor),
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: const Color(0x33FFFFFF),
      );
}
