import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// Markdown 编辑器，左侧为 TextField 编辑区，右侧为实时渲染预览。
///
/// 顶部工具栏提供常用 Markdown 格式化按钮：
/// - B（粗体）、I（斜体）
/// - H1/H2/H3 标题
/// - List（列表）
/// - Code（代码块）
/// - Link（链接）
/// - Image（图片）
///
/// @param initialText 初始 Markdown 内容
/// @param onTextChanged 文本变更回调
/// @param onImagePicked 图片上传回调
/// @param controller 可选的外部 TextEditingController
class MarkdownEditor extends StatefulWidget {
  /// 初始 Markdown 内容
  final String initialText;

  /// 文本变更回调
  final ValueChanged<String>? onTextChanged;

  /// 图片上传回调
  final VoidCallback? onImagePicked;

  /// 可选的外部 TextEditingController
  final TextEditingController? controller;

  const MarkdownEditor({
    super.key,
    required this.initialText,
    this.onTextChanged,
    this.onImagePicked,
    this.controller,
  });

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        TextEditingController(text: widget.initialText);
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_onTextChanged);
    }
    super.dispose();
  }

  void _onTextChanged() {
    widget.onTextChanged?.call(_controller.text);
  }

  /// 在选中文本前后插入包裹符号
  void _wrapSelection(String before, [String? after]) {
    final text = _controller.text;
    final selection = _controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start < 0 || end < 0) {
      // 没有选中文本，在光标位置插入
      final cursorPos = selection.baseOffset;
      final newText = text.substring(0, cursorPos) +
          before +
          (after ?? before) +
          text.substring(cursorPos);
      _controller.text = newText;
      _controller.selection = TextSelection.collapsed(
        offset: cursorPos + before.length,
      );
      return;
    }

    final selectedText = text.substring(start, end);
    final newText = text.substring(0, start) +
        before +
        selectedText +
        (after ?? before) +
        text.substring(end);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: start + before.length + selectedText.length,
    );
  }

  /// 在行首插入前缀
  void _insertLinePrefix(String prefix) {
    final text = _controller.text;
    final selection = _controller.selection;
    final cursorPos = selection.baseOffset;

    // 找到当前行的起始位置
    int lineStart = 0;
    for (int i = cursorPos - 1; i >= 0; i--) {
      if (text[i] == '\n') {
        lineStart = i + 1;
        break;
      }
    }

    final newText = text.substring(0, lineStart) +
        prefix +
        text.substring(lineStart);
    _controller.text = newText;
    _controller.selection = TextSelection.collapsed(
      offset: cursorPos + prefix.length,
    );
  }

  void _insertBold() => _wrapSelection('**');

  void _insertItalic() => _wrapSelection('*');

  void _insertH1() => _insertLinePrefix('# ');

  void _insertH2() => _insertLinePrefix('## ');

  void _insertH3() => _insertLinePrefix('### ');

  void _insertList() => _insertLinePrefix('- ');

  void _insertCodeBlock() => _wrapSelection('```\n', '\n```');

  void _insertLink() {
    final selection = _controller.selection;
    final start = selection.start;
    final end = selection.end;

    if (start >= 0 && end >= 0 && start != end) {
      // 有选中文本，将其作为链接文字
      final selectedText = _controller.text.substring(start, end);
      final text = _controller.text;
      final newText = text.substring(0, start) +
          '[$selectedText](url)' +
          text.substring(end);
      _controller.text = newText;
      // 将光标放在 url 位置以便编辑
      _controller.selection = TextSelection.collapsed(
        offset: start + selectedText.length + 3,
      );
    } else {
      // 没有选中文本，插入空链接
      _wrapSelection('[', '](url)');
    }
  }

  void _handleImagePick() {
    widget.onImagePicked?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildToolbar(),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: [
              // 左侧：编辑区
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: Theme.of(context).dividerColor,
                      ),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(16),
                    ),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              // 右侧：预览区
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: MarkdownBody(
                    data: _controller.text,
                    selectable: false,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.format_bold,
            tooltip: 'Bold',
            onPressed: _insertBold,
          ),
          _ToolbarButton(
            icon: Icons.format_italic,
            tooltip: 'Italic',
            onPressed: _insertItalic,
          ),
          const SizedBox(width: 8),
          _ToolbarTextButton(
            text: 'H1',
            tooltip: 'Heading 1',
            onPressed: _insertH1,
          ),
          _ToolbarTextButton(
            text: 'H2',
            tooltip: 'Heading 2',
            onPressed: _insertH2,
          ),
          _ToolbarTextButton(
            text: 'H3',
            tooltip: 'Heading 3',
            onPressed: _insertH3,
          ),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.format_list_bulleted,
            tooltip: 'List',
            onPressed: _insertList,
          ),
          _ToolbarButton(
            icon: Icons.code,
            tooltip: 'Code Block',
            onPressed: _insertCodeBlock,
          ),
          _ToolbarButton(
            icon: Icons.link,
            tooltip: 'Link',
            onPressed: _insertLink,
          ),
          _ToolbarButton(
            icon: Icons.image,
            tooltip: 'Image',
            onPressed: _handleImagePick,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class _ToolbarTextButton extends StatelessWidget {
  final String text;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolbarTextButton({
    required this.text,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: TextButton(
        onPressed: onPressed,
        child: Text(text),
      ),
    );
  }
}
