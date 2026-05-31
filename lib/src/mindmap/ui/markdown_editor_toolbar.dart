// lib/src/mindmap/ui/markdown_editor_toolbar.dart

import 'package:flutter/material.dart';

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
      if (suffix != null && suffix.isNotEmpty) {
        newSelection = TextSelection.collapsed(
          offset: start + prefix.length,
        );
      } else {
        newSelection = TextSelection.collapsed(
          offset: start + prefix.length,
        );
      }
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
      padding: const EdgeInsets.all(6),
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
              _ToolbarButton(
                tooltip: '标题 (###)',
                onTap: () => insertMarkdown('### '),
                child: Text(
                  'H',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ToolbarButton(
                tooltip: '粗体 (**)',
                onTap: () => insertMarkdown('**', '**'),
                child: Text(
                  'B',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _ToolbarButton(
                tooltip: '斜体 (*)',
                onTap: () => insertMarkdown('*', '*'),
                child: Text(
                  'I',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _ToolbarButton(
                tooltip: '删除线 (~~)',
                onTap: () => insertMarkdown('~~', '~~'),
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    decoration: TextDecoration.lineThrough,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _ToolbarButton(
                tooltip: '超链接 ([]())',
                onTap: () => insertMarkdown('[', ']()'),
                child: Icon(
                  Icons.link_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const _VerticalSeparator(),
              _ToolbarButton(
                tooltip: '无序列表',
                onTap: () => insertMarkdown('\n- '),
                child: Icon(
                  Icons.format_list_bulleted_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              _ToolbarButton(
                tooltip: '有序列表',
                onTap: () => insertMarkdown('\n1. '),
                child: Icon(
                  Icons.format_list_numbered_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              _ToolbarButton(
                tooltip: '任务列表',
                onTap: () => insertMarkdown('\n- [ ] '),
                child: Icon(
                  Icons.check_box_outlined,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const _VerticalSeparator(),
              _ToolbarButton(
                tooltip: '引用',
                onTap: () => insertMarkdown('\n> '),
                child: Transform.rotate(
                  angle: -0.5,
                  child: Icon(
                    Icons.send_rounded,
                    size: 13,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
              _ToolbarButton(
                tooltip: '分割线',
                onTap: () => insertMarkdown('\n---\n'),
                child: Icon(
                  Icons.horizontal_rule_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Row 2
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ToolbarButton(
                tooltip: '代码块',
                onTap: () => insertMarkdown('\n```\n', '\n```\n'),
                child: Icon(
                  Icons.code_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              _ToolbarButton(
                tooltip: '行内代码',
                onTap: () => insertMarkdown('`', '`'),
                child: Icon(
                  Icons.terminal_rounded,
                  size: 15,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const _VerticalSeparator(),
              _ToolbarButton(
                tooltip: '云端同步',
                onTap: () {
                  insertMarkdown('![Image](https://)');
                  _showMockToast(context, '图片占位符已插入并同步云端', Icons.cloud_done_outlined);
                },
                child: Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              _ToolbarButton(
                tooltip: '表格',
                onTap: () => insertMarkdown('\n| Header | Header |\n| ------ | ------ |\n| Cell   | Cell   |\n'),
                child: Icon(
                  Icons.grid_on_rounded,
                  size: 15,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              const _VerticalSeparator(),
              _ToolbarButton(
                tooltip: '撤销 (Undo)',
                onTap: () => _showMockToast(context, '撤销成功', Icons.undo_rounded),
                child: Icon(
                  Icons.undo_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
              _ToolbarButton(
                tooltip: '重做 (Redo)',
                onTap: () => _showMockToast(context, '重做成功', Icons.redo_rounded),
                child: Icon(
                  Icons.redo_rounded,
                  size: 16,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatefulWidget {
  final Widget child;
  final String tooltip;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.child,
    required this.tooltip,
    required this.onTap,
  });

  @override
  State<_ToolbarButton> createState() => _ToolbarButtonState();
}

class _ToolbarButtonState extends State<_ToolbarButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      textStyle: const TextStyle(color: Colors.white, fontSize: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0A07),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x1F2A3547), width: 1),
      ),
      waitDuration: const Duration(milliseconds: 500),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() {
          _isHovered = false;
          _isPressed = false;
        }),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _isPressed
                  ? const Color(0x25FFFFFF)
                  : _isHovered
                      ? const Color(0x10FFFFFF)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: widget.child,
          ),
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
