// lib/src/mindmap/ui/node_widget.dart

import 'package:flutter/material.dart';
import '../domain/note.dart';

/// 节点组件。
///
/// 显示导图节点，支持选中、展开/折叠、PDF 源跳转等。
class NodeWidget extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final bool isCollapsed;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onAddChild;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleCollapse;

  const NodeWidget({
    super.key,
    required this.note,
    this.isSelected = false,
    this.isCollapsed = false,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onAddChild,
    this.onDelete,
    this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: colorScheme.primary, width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // PDF 来源图标
            if (note.pdfId != null) ...[
              Icon(
                Icons.picture_as_pdf,
                size: 16,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 8),
            ],
            // 标题
            Flexible(
              child: Text(
                note.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 子节点数量
            if (note.childIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              Icon(
                isCollapsed ? Icons.chevron_right : Icons.expand_more,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              Text(
                '${note.childIds.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}