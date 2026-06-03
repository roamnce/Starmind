// lib/src/mindmap/ui/markdown_editor_toolbar.dart

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class MarkdownEditorToolbar extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode? focusNode;

  const MarkdownEditorToolbar({
    super.key,
    required this.textController,
    this.focusNode,
  });

  /// Inserts a markdown tag at the current selection or wraps selected text.
  void insertMarkdown(String prefix, [String? suffix]) {
    final text = textController.text;
    final selection = textController.selection;

    int start = selection.start;
    int end = selection.end;

    // Handle invalid selection by defaulting to the end of the text
    if (start < 0 || end < 0) {
      start = text.length;
      end = text.length;
    }

    final selectedText = text.substring(start, end);
    final realSuffix = suffix ?? '';
    final wrappedText = '$prefix$selectedText$realSuffix';

    final newText = text.replaceRange(start, end, wrappedText);

    final TextSelection newSelection;
    if (start != end) {
      // If there was a selection, keep it wrapped
      newSelection = TextSelection(
        baseOffset: start + prefix.length,
        extentOffset: start + prefix.length + selectedText.length,
      );
    } else {
      // If the selection was collapsed, place cursor inside prefix and suffix
      newSelection = TextSelection.collapsed(
        offset: start + prefix.length,
      );
    }

    textController.value = TextEditingValue(
      text: newText,
      selection: newSelection,
    );

    // Restore focus if a FocusNode is provided
    if (focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void _showMockToast(BuildContext context, String message, IconData icon) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: const Color(0xFF1862C6), size: 20),
            const SizedBox(width: 8),
            Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1C222B),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0x1F2A3547), width: 1),
        ),
        duration: const Duration(seconds: 1),
        margin: const EdgeInsets.only(bottom: 24, left: 16, right: 16),
      ),
    );

    if (focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1C222B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x1F2A3547), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolbarTextButton(
                text: 'H',
                tooltip: '标题 (###)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
                onTap: () => insertMarkdown('### '),
              ),
              _ToolbarTextButton(
                text: 'B',
                tooltip: '粗体 (**)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                onTap: () => insertMarkdown('**', '**'),
              ),
              _ToolbarTextButton(
                text: 'I',
                tooltip: '斜体 (*)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.bold,
                ),
                onTap: () => insertMarkdown('*', '*'),
              ),
              _ToolbarTextButton(
                text: 'S',
                tooltip: '删除线 (~~)',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 13,
                  decoration: TextDecoration.lineThrough,
                  fontWeight: FontWeight.bold,
                ),
                onTap: () => insertMarkdown('~~', '~~'),
              ),
              _ToolbarIconButton(
                icon: Icons.link_rounded,
                tooltip: '超链接 ([]())',
                onTap: () => insertMarkdown('[', ']()'),
              ),
              const _VerticalSeparator(),
              _ToolbarIconButton(
                icon: Icons.format_list_bulleted_rounded,
                tooltip: '无序列表',
                onTap: () => insertMarkdown('\n- '),
              ),
              _ToolbarIconButton(
                icon: Icons.format_list_numbered_rounded,
                tooltip: '有序列表',
                onTap: () => insertMarkdown('\n1. '),
              ),
              _ToolbarIconButton(
                icon: Icons.check_box_outlined,
                tooltip: '任务列表',
                onTap: () => insertMarkdown('\n- [ ] '),
              ),
              const _VerticalSeparator(),
              _ToolbarIconButton(
                icon: Icons.send_rounded,
                tooltip: '引用',
                angle: -0.5,
                onTap: () => insertMarkdown('\n> '),
              ),
              _ToolbarIconButton(
                icon: Icons.horizontal_rule_rounded,
                tooltip: '分割线',
                onTap: () => insertMarkdown('\n---\n'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Row 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolbarIconButton(
                icon: Icons.code_rounded,
                tooltip: '代码块',
                onTap: () => insertMarkdown('\n```\n', '\n```\n'),
              ),
              _ToolbarIconButton(
                icon: Icons.terminal_rounded,
                tooltip: '行内代码',
                onTap: () => insertMarkdown('`', '`'),
              ),
              const _VerticalSeparator(),
              _ToolbarIconButton(
                icon: Icons.cloud_upload_outlined,
                tooltip: '云端同步',
                onTap: () {
                  insertMarkdown('![Image](https://)');
                  _showMockToast(context, '图片占位符已插入并同步云端', Icons.cloud_done_outlined);
                },
              ),
              _ToolbarIconButton(
                icon: Icons.grid_on_rounded,
                tooltip: '表格',
                onTap: () => insertMarkdown('\n| Header | Header |\n| ------ | ------ |\n| Cell   | Cell   |\n'),
              ),
              const _VerticalSeparator(),
              _ToolbarIconButton(
                icon: Icons.undo_rounded,
                tooltip: '撤销 (Undo)',
                onTap: () => _showMockToast(context, '撤销成功', Icons.undo_rounded),
              ),
              _ToolbarIconButton(
                icon: Icons.redo_rounded,
                tooltip: '重做 (Redo)',
                onTap: () => _showMockToast(context, '重做成功', Icons.redo_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarTextButton extends StatelessWidget {
  final String text;
  final String tooltip;
  final TextStyle style;
  final VoidCallback onTap;

  const _ToolbarTextButton({
    required this.text,
    required this.tooltip,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0A07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x1F2A3547), width: 1),
      ),
      waitDuration: const Duration(milliseconds: 500),
      child: SizedBox(
        width: 25,
        height: 25,
        child: FButton(
          variant: FButtonVariant.ghost,
          size: FButtonSizeVariant.xs,
          onPress: onTap,
          style: const FButtonStyleDelta.delta(
            contentStyle: FButtonContentStyleDelta.delta(
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
            ),
          ),
          child: Text(text, style: style),
        ),
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final double angle;
  final VoidCallback onTap;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    this.angle = 0.0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final child = angle != 0.0
        ? Transform.rotate(
            angle: angle,
            child: Icon(icon, size: 14),
          )
        : Icon(icon, size: 14);

    return Tooltip(
      message: tooltip,
      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0A07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x1F2A3547), width: 1),
      ),
      waitDuration: const Duration(milliseconds: 500),
      child: SizedBox(
        width: 25,
        height: 25,
        child: FButton.icon(
          variant: FButtonVariant.ghost,
          size: FButtonSizeVariant.xs,
          onPress: onTap,
          style: const FButtonStyleDelta.delta(
            iconContentStyle: FButtonIconContentStyleDelta.delta(
              constraints: BoxConstraints(minWidth: 16, minHeight: 16),
              padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _VerticalSeparator extends StatelessWidget {
  const _VerticalSeparator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 16,
      color: const Color(0x1F2A3547),
      margin: const EdgeInsets.symmetric(horizontal: 2),
    );
  }
}
