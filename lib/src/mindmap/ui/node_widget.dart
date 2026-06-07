// lib/src/mindmap/ui/node_widget.dart

import 'package:flutter/material.dart';
import '../domain/note.dart';
import 'mindmap_controller.dart';

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
  final Size? customSize;
  final MindMapController? controller;

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
    this.customSize,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // 自定义金黄色选中状态
    final accentColor = const Color(0xFFC8841A);

    // 判断是否为被选中状态 (或者在控制器的多选列表中)
    final selected = isSelected || (controller != null && controller!.selectedNoteIds.contains(note.id));

    // 新增：根据布局样式选择渲染方式
    if (note.layoutStyle == 'framework') {
      return _buildFrameworkNode(context, theme, accentColor, selected);
    }

    // 判断是否为嵌套卡片容器
    final isNestedCard = note.highlightStyle == 'nestedCard';

    if (isNestedCard && !isCollapsed) {
      // 展开状态的嵌套卡片容器
      final w = customSize?.width ?? 200.0;
      final h = customSize?.height ?? 150.0;

      return GestureDetector(
        onTap: onTap,
        onDoubleTap: onDoubleTap ?? onToggleCollapse,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: const Color(0x0DFFFFFF), // 半透明高质感背景
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accentColor : const Color(0x40C8841A),
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(selected ? 0.3 : 0.08),
                blurRadius: selected ? 12 : 6,
                spreadRadius: selected ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 容器头部 (高度固定为 40px)
              Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: selected ? const Color(0x1CC8841A) : const Color(0x0DFFFFFF),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(11),
                    topRight: Radius.circular(11),
                  ),
                ),
                child: Row(
                  children: [
                    // 卡片组专属图标
                    Icon(
                      Icons.grid_view_rounded,
                      size: 16,
                      color: selected ? accentColor : const Color(0xFFC8841A).withOpacity(0.8),
                    ),
                    const SizedBox(width: 8),
                    // 容器名称
                    Expanded(
                      child: Text(
                        note.title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withOpacity(0.95),
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // 折叠按钮
                    if (onToggleCollapse != null)
                      GestureDetector(
                        onTap: onToggleCollapse,
                        child: Icon(
                          Icons.keyboard_arrow_up_rounded,
                          size: 18,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                  ],
                ),
              ),
              // 中部透明预留区域 (供子节点显示)
              const Spacer(),
            ],
          ),
        ),
      );
    }

    // 普通节点，或者折叠状态的嵌套卡片容器
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap ?? onToggleCollapse,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: customSize?.width,
        height: customSize?.height,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF242930), // 原型经典深灰色
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected 
                ? accentColor 
                : (isNestedCard ? const Color(0xFFC8841A).withOpacity(0.5) : const Color(0x15FFDC8C)),
            width: selected ? 2.0 : 1.0,
          ),
          boxShadow: [
            if (selected)
              BoxShadow(
                color: accentColor.withOpacity(0.35),
                blurRadius: 10,
                spreadRadius: 2,
              )
            else
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Row(
          mainAxisSize: customSize == null ? MainAxisSize.min : MainAxisSize.max,
          children: [
            // 卡片组折叠图标
            if (isNestedCard) ...[
              Icon(
                Icons.grid_view_rounded,
                size: 14,
                color: selected ? accentColor : const Color(0xFFC8841A).withOpacity(0.8),
              ),
              const SizedBox(width: 6),
            ] else if (note.pdfId != null) ...[
              // PDF 来源图标
              Icon(
                Icons.picture_as_pdf_outlined,
                size: 14,
                color: selected ? accentColor : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            // 标题
            Flexible(
              child: Text(
                note.title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontWeight: (selected || isNestedCard) ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // 子节点数量
            if (note.childIds.isNotEmpty) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: onToggleCollapse,
                child: Icon(
                  isCollapsed ? Icons.chevron_right : Icons.expand_more,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
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

  /// 构建框架式节点
  Widget _buildFrameworkNode(
    BuildContext context,
    ThemeData theme,
    Color accentColor,
    bool selected,
  ) {
    final w = customSize?.width ?? 200.0;
    final h = customSize?.height ?? 150.0;

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap ?? onToggleCollapse,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: const Color(0x0DFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : const Color(0x25C8841A),
            width: selected ? 2.5 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withOpacity(selected ? 0.3 : 0.08),
              blurRadius: selected ? 12 : 6,
              spreadRadius: selected ? 2 : 0,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected ? const Color(0x1CC8841A) : const Color(0x0DFFFFFF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(11),
                  topRight: Radius.circular(11),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.view_module_rounded,
                    size: 16,
                    color: selected ? accentColor : const Color(0xFFC8841A).withOpacity(0.8),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (onToggleCollapse != null)
                    GestureDetector(
                      onTap: onToggleCollapse,
                      child: Icon(
                        isCollapsed ? Icons.add_rounded : Icons.keyboard_arrow_up_rounded,
                        size: 18,
                        color: Colors.white.withOpacity(0.6),
                      ),
                    ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
