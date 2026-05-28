import 'package:flutter/material.dart';
import '../pdf_viewport_controller.dart';
import '../../domain/annotation.dart';

/// 浮动工具栏，用于文本选择后的批注操作
class SelectionToolbar extends StatelessWidget {
  final PdfViewportController controller;
  final int pageIndex;
  final int startCharIndex;
  final int endCharIndex;
  final List<Rect> rects;
  final String selectedText;
  final VoidCallback? onClose;
  final void Function(AnnotationType type, Color color)? onCreateAnnotation;

  const SelectionToolbar({
    super.key,
    required this.controller,
    required this.pageIndex,
    required this.startCharIndex,
    required this.endCharIndex,
    required this.rects,
    required this.selectedText,
    this.onClose,
    this.onCreateAnnotation,
  });

  void _onHighlightPressed(Color color) {
    if (onCreateAnnotation != null) {
      onCreateAnnotation!(AnnotationType.highlight, color);
    }
    controller.clearSelection();
    onClose?.call();
  }

  void _onUnderlinePressed(Color color) {
    if (onCreateAnnotation != null) {
      onCreateAnnotation!(AnnotationType.underline, color);
    }
    controller.clearSelection();
    onClose?.call();
  }

  void _onCopyPressed() {
    // Clipboard.setData(ClipboardData(text: selectedText));
    controller.clearSelection();
    onClose?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 高亮按钮
            IconButton(
              icon: const Icon(Icons.highlight, size: 20),
              tooltip: '高亮',
              onPressed: () => _onHighlightPressed(const Color(0xFFFFEB3B)),
            ),
            // 下划线按钮
            IconButton(
              icon: const Icon(Icons.format_underlined, size: 20),
              tooltip: '下划线',
              onPressed: () => _onUnderlinePressed(Colors.red),
            ),
            // 复制按钮
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              tooltip: '复制',
              onPressed: _onCopyPressed,
            ),
            // 颜色选择
            PopupMenuButton<Color>(
              icon: const Icon(Icons.palette, size: 20),
              tooltip: '选择颜色',
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: Color(0xFFFFEB3B),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFFFFEB3B), size: 16),
                      SizedBox(width: 8),
                      Text('黄色'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: Color(0xFF4CAF50),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFF4CAF50), size: 16),
                      SizedBox(width: 8),
                      Text('绿色'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: Color(0xFF2196F3),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFF2196F3), size: 16),
                      SizedBox(width: 8),
                      Text('蓝色'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: Color(0xFFFF5722),
                  child: Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFFFF5722), size: 16),
                      SizedBox(width: 8),
                      Text('橙色'),
                    ],
                  ),
                ),
              ],
              onSelected: _onHighlightPressed,
            ),
          ],
        ),
      ),
    );
  }
}
