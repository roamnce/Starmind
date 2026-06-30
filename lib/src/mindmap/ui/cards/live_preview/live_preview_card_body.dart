// lib/src/mindmap/ui/cards/live_preview/live_preview_card_body.dart
//
// 方案 A：单 TextField + 富文本 buildTextSpan + 顶部 markdown 工具栏。
//
// 设计取舍
// - 整个卡片只有一个 [TextField]，由 [LivePreviewController] 在 buildTextSpan
//   中把原始 markdown 文本「就地」渲染成富文本（标题大字号、加粗、斜体、代码、
//   链接、删除线等）。
// - 语法符号本身不被删除，但用很淡的灰色绘制，看起来像不存在——这是 Obsidian
//   Live Preview 的实际实现思路（基于 CodeMirror decoration）。
// - 光标、IME、选区、平台 undo/redo 完全由 Flutter 处理：永远不会被「重建
//   widget」打断；用户输入立即触发 buildTextSpan 重绘 → 渲染态同步更新。
//
// 公共 API 与 MarkdownHighlightCardBody 对齐，作为 LivePreview 后端
// 的实现。

import 'dart:async';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart' show FilePicker, FileType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'live_preview_controller.dart';
import 'live_preview_toolbar.dart';
import 'card_overlay_renderer.dart';
import 'placeholder_tracker.dart';
import 'file_attachment_service.dart';
import 'link_handler.dart';

/// Live Preview 卡片正文 widget。
class LivePreviewCardBody extends StatefulWidget {
  /// 初始 markdown 文本。
  final String initialMarkdown;

  /// 内容变更回调（debounced 800ms）。
  final void Function(String markdown)? onContentChanged;

  /// 工具栏请求插入图片时的回调（图片走外部 file picker）。
  final VoidCallback? onInsertImageRequested;

  /// 文本前景色。
  final Color? textColor;

  /// 背景色（保留作 API 兼容）。
  final Color? backgroundColor;

  /// 边框色（保留作 API 兼容）。
  final Color? borderColor;

  /// 只读模式。
  final bool readOnly;

  /// 可选文档 ID（保留作 API 兼容）。
  final String? docId;

  /// 是否显示顶部 markdown 工具栏。
  final bool showToolbar;

  const LivePreviewCardBody({
    super.key,
    required this.initialMarkdown,
    this.onContentChanged,
    this.onInsertImageRequested,
    this.textColor,
    this.backgroundColor,
    this.borderColor,
    this.readOnly = false,
    this.docId,
    this.showToolbar = true,
  });

  @override
  State<LivePreviewCardBody> createState() => LivePreviewCardBodyState();
}

class LivePreviewCardBodyState extends State<LivePreviewCardBody> {
  static const Duration debounceDuration = Duration(milliseconds: 800);

  late final LivePreviewController _controller;
  late final FocusNode _focusNode;
  final _placeholderTracker = PlaceholderTracker();
  final _textFieldKey = GlobalKey();
  Timer? _debounceTimer;
  String? _pendingContent;

  /// 用户是否本地修改过，阻止 didUpdateWidget 用外部输入覆盖在打字中的内容。
  bool _userModified = false;

  /// 源码模式（关闭富文本渲染，只展示纯文本）。
  bool _isSourceMode = false;

  bool get isSourceMode => _isSourceMode;
  bool get isReady => true;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _controller = LivePreviewController(
      text: widget.initialMarkdown,
      focusNode: _focusNode,
    );
    _controller.addListener(_handleTextChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(LivePreviewCardBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_userModified &&
        oldWidget.initialMarkdown != widget.initialMarkdown &&
        widget.initialMarkdown != _controller.text) {
      _controller.text = widget.initialMarkdown;
    }
    if (_userModified && widget.initialMarkdown == _controller.text) {
      _userModified = false;
    }
  }

  @override
  void dispose() {
    flush();
    _controller.removeListener(_handleTextChanged);
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 切换源码 / 渲染视图。
  void toggleSourceMode() {
    setState(() => _isSourceMode = !_isSourceMode);
  }

  /// TextField 自带平台撤销/重做栈。
  void undo() {}
  void redo() {}

  /// 在光标处插入图片 markdown。
  void insertImage({required String url, String? alt}) {
    final label = alt ?? 'image';
    _insertAtSelection('![$label]($url)');
  }

  /// 立刻 flush 等待中的 markdown 变更。
  void flush() {
    _debounceTimer?.cancel();
    if (_pendingContent != null) {
      widget.onContentChanged?.call(_pendingContent!);
      _pendingContent = null;
    }
  }

  /// 记录上一次文本内容，用于区分纯光标移动和真正的文本编辑。
  late String _lastText = widget.initialMarkdown;

  void _handleTextChanged() {
    final newText = _controller.text;
    if (newText == _lastText) {
      // 纯光标移动（箭头键、点击等），Flutter 自动触发 buildTextSpan 重绘，
      // 但不需要标记 _userModified 或重置 debounce。
      return;
    }
    _lastText = newText;
    _userModified = true;
    _pendingContent = newText;
    _placeholderTracker.rebuild(newText);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, flush);
  }

  /// 焦点变化时直接 setState 重建 widget，使 TextField 重新调用
  /// buildTextSpan——里面通过传入的 FocusNode 判断光标行。
  void _handleFocusChanged() {
    if (!mounted) return;
    setState(() {});
  }

  // --- 文本编辑命令（工具栏调用） ---

  /// 在当前光标处插入文本，光标移动到末尾。
  void _insertAtSelection(String text) {
    final value = _controller.value;
    final sel = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: value.text.length);
    final next = value.text.replaceRange(sel.start, sel.end, text);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: sel.start + text.length),
    );
  }

  /// 用 [before]/[after] 包裹选区；无选区时插入并把光标放到中间。
  void _wrapSelection(String before, String after) {
    final value = _controller.value;
    final sel = value.selection;
    if (!sel.isValid) {
      _insertAtSelection('$before$after');
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length - after.length);
      return;
    }
    if (sel.isCollapsed) {
      final next = value.text.replaceRange(sel.start, sel.end, '$before$after');
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: sel.start + before.length),
      );
    } else {
      final selected = value.text.substring(sel.start, sel.end);
      final replacement = '$before$selected$after';
      final next = value.text.replaceRange(sel.start, sel.end, replacement);
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection(
          baseOffset: sel.start + before.length,
          extentOffset: sel.start + before.length + selected.length,
        ),
      );
    }
  }

  /// 在当前行行首插入 [prefix]。
  void _insertLinePrefix(String prefix) {
    final value = _controller.value;
    final sel = value.selection;
    final offset = sel.isValid ? sel.baseOffset : value.text.length;
    int lineStart =
        offset > 0 ? value.text.lastIndexOf('\n', offset - 1) : -1;
    lineStart = lineStart == -1 ? 0 : lineStart + 1;
    final next = value.text.replaceRange(lineStart, lineStart, prefix);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: offset + prefix.length),
    );
  }

  /// 插入块（前后各 [before]/[after]，常用于 ``` code ```、$$ math $$ 等）。
  void _insertBlock(String before, String after) {
    final value = _controller.value;
    final sel = value.selection;
    if (!sel.isValid || sel.isCollapsed) {
      _insertAtSelection('$before$after');
      _controller.selection =
          TextSelection.collapsed(offset: _controller.text.length - after.length);
      return;
    }
    final selected = value.text.substring(sel.start, sel.end);
    final replacement = '$before$selected$after';
    final next = value.text.replaceRange(sel.start, sel.end, replacement);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection(
        baseOffset: sel.start + before.length,
        extentOffset: sel.start + before.length + selected.length,
      ),
    );
  }

  /// 检测光标是否落在任务列表的 `[ ]`/`[x]` 标记上，如果是则切换。
  ///
  /// 只有光标在 `[ ]` / `[x]` 字符范围内（即 lineStart + prefixLen 到
  /// lineStart + prefixLen + 3）时才触发切换，避免点击行内任意位置都打勾。
  void _toggleCheckboxAtCursor() {
    final text = _controller.text;
    final sel = _controller.selection;
    if (!sel.isValid || !sel.isCollapsed) return;
    final offset = sel.baseOffset.clamp(0, text.length);

    // 找到光标所在行的起止位置。
    int lineStart = offset > 0 ? text.lastIndexOf('\n', offset - 1) + 1 : 0;
    int lineEnd = text.indexOf('\n', offset);
    if (lineEnd == -1) lineEnd = text.length;
    final line = text.substring(lineStart, lineEnd);

    // 匹配 `- [ ] xxx` 或 `- [x] xxx` 或 `- [X] xxx`
    final taskRe = RegExp(r'^(\s*[-*+]\s+)\[([ xX])\](\s+.*)$');
    final match = taskRe.firstMatch(line);
    if (match == null) return;

    // 计算 `[ ]` / `[x]` 在行内的字符范围。
    final prefixLen = match.group(1)!.length; // `- ` 或 `- ` 的长度
    final boxStart = lineStart + prefixLen;     // `[` 的位置
    final boxEnd = boxStart + 3;                // `]` 之后的位置

    // 只有光标在 `[ ]` / `[x]` 范围内才切换。
    if (offset < boxStart || offset > boxEnd) return;

    final current = match.group(2);
    final rest = match.group(3)!;
    final newMark = (current == ' ') ? 'x' : ' ';
    final newLine = '${match.group(1)!}[$newMark]$rest';
    final newText = text.replaceRange(lineStart, lineEnd, newLine);

    // 光标保持在复选框之后。
    final newOffset = (boxEnd).clamp(0, newText.length);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newOffset),
    );
  }

  void _handleToolbarAction(MdToolbarAction action) {
    if (widget.readOnly) return;
    switch (action) {
      case MdToolbarAction.bold:
        _wrapSelection('**', '**');
      case MdToolbarAction.italic:
        _wrapSelection('*', '*');
      case MdToolbarAction.strikethrough:
        _wrapSelection('~~', '~~');
      case MdToolbarAction.inlineCode:
        _wrapSelection('`', '`');
      case MdToolbarAction.heading1:
        _insertLinePrefix('# ');
      case MdToolbarAction.heading2:
        _insertLinePrefix('## ');
      case MdToolbarAction.heading3:
        _insertLinePrefix('### ');
      case MdToolbarAction.bulletList:
        _insertLinePrefix('- ');
      case MdToolbarAction.orderedList:
        _insertLinePrefix('1. ');
      case MdToolbarAction.taskList:
        _insertLinePrefix('- [ ] ');
      case MdToolbarAction.blockquote:
        _insertLinePrefix('> ');
      case MdToolbarAction.codeBlock:
        _insertBlock('```\n', '\n```');
      case MdToolbarAction.link:
        _wrapSelection('[', '](url)');
      case MdToolbarAction.image:
        _pickAndInsertImage();
      case MdToolbarAction.attachFile:
        _pickAndInsertFile();
      case MdToolbarAction.horizontalRule:
        _insertAtSelection('\n---\n');
    }
    // 工具栏点击后保持焦点，便于继续输入。
    _focusNode.requestFocus();
  }

  Future<void> _pickAndInsertImage() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) return;

      final assetPath = await FileAttachmentService.copyToAssets(filePath);
      final alt = result.files.first.name;
      final markdown =
          FileAttachmentService.toMarkdownInsertion(assetPath, alt: alt);
      _insertAtSelection(markdown);
    } catch (e) {
      // ignore: avoid_print
      'Image pick error: $e';
    }
  }

  Future<void> _pickAndInsertFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;
      final filePath = result.files.first.path;
      if (filePath == null) return;

      final assetPath = await FileAttachmentService.copyToAssets(filePath);
      final markdown = FileAttachmentService.toMarkdownInsertion(assetPath);
      _insertAtSelection(markdown);
    } catch (e) {
      // ignore
    }
  }

  /// Handle drag-and-drop of files from the desktop into the editor.
  ///
  /// Image files are inserted as `![alt](path)`, other files as `[name](path)`.
  /// Multiple files are inserted separated by a space.
  Future<void> _handleFileDrop(DropDoneDetails details) async {
    final parts = <String>[];
    for (final xFile in details.files) {
      try {
        final assetPath = await FileAttachmentService.copyToAssets(xFile.path);
        final markdown = FileAttachmentService.toMarkdownInsertion(assetPath);
        parts.add(markdown);
      } catch (_) {
        // Ignore individual file failures so one bad file doesn't block the rest.
      }
    }
    if (parts.isNotEmpty) {
      _insertAtSelection(parts.join(' '));
    }
  }

  void _handleLinkTap() {
    try {
      final isCtrlPressed =
          HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      if (!isCtrlPressed) return;

      final offset = _controller.selection.baseOffset;
      if (offset < 0 || offset > _controller.text.length) return;

      final links = LinkHandler.extractLinks(_controller.text);
      final link = LinkHandler.isLinkAtOffset(links, offset);
      if (link != null) {
        LinkHandler.openLink(link.url);
      }
    } catch (e) {
      // ignore
    }
  }

  // --- UI ---

  @override
  Widget build(BuildContext context) {
    final text = widget.textColor ?? const Color(0xFFE6EDF3);
    // 用户传入的 textColor 覆盖默认文本颜色（其他渲染颜色继续走 controller 默认）。
    _controller.textColor = text;
    _controller.headingColor = text;
    _controller.boldColor = text;
    _controller.italicColor = text;
    _controller.strikeColor = text;

    if (_isSourceMode) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: SelectableText(
          _controller.text,
          style: TextStyle(
            color: text,
            fontSize: 14,
            height: 1.4,
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    final editorStyle = TextStyle(
      color: text,
      fontSize: 14,
      height: 1.5,
    );

    final editor = Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.keyB, control: true):
            _ToolbarShortcutIntent(MdToolbarAction.bold),
        SingleActivator(LogicalKeyboardKey.keyI, control: true):
            _ToolbarShortcutIntent(MdToolbarAction.italic),
        SingleActivator(LogicalKeyboardKey.keyB, meta: true):
            _ToolbarShortcutIntent(MdToolbarAction.bold),
        SingleActivator(LogicalKeyboardKey.keyI, meta: true):
            _ToolbarShortcutIntent(MdToolbarAction.italic),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _ToolbarShortcutIntent: CallbackAction<_ToolbarShortcutIntent>(
            onInvoke: (intent) {
              _handleToolbarAction(intent.action);
              return null;
            },
          ),
        },
        child: TextField(
          key: _textFieldKey,
          controller: _controller,
          focusNode: _focusNode,
          readOnly: widget.readOnly,
          maxLines: null,
          minLines: null,
          expands: false,
          textAlignVertical: TextAlignVertical.top,
          style: editorStyle,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            border: InputBorder.none,
            hintText: 'markdown...',
          ),
          onTap: () {
              _toggleCheckboxAtCursor();
              _handleLinkTap();
            },
        ),
      ),
    );

    final editorArea = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showToolbar && !widget.readOnly)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
            child: LivePreviewToolbar(
              onAction: _handleToolbarAction,
              iconColor: text.withValues(alpha: 0.85),
            ),
          ),
        Expanded(child: editor),
      ],
    );

    final stack = Stack(
      children: [
        editorArea,
        CardOverlayRenderer(
          markdown: _controller.text,
          maxWidth: MediaQuery.of(context).size.width - 40,
          placeholderTracker: _placeholderTracker,
          textFieldKey: _textFieldKey,
        ),
      ],
    );

    if (widget.readOnly) {
      return stack;
    }

    return DropTarget(
      onDragDone: (detail) => _handleFileDrop(detail),
      child: stack,
    );
  }
}

class _ToolbarShortcutIntent extends Intent {
  final MdToolbarAction action;
  const _ToolbarShortcutIntent(this.action);
}
