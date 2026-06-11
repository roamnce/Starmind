// lib/src/mindmap/ui/node_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/mindmap_colors.dart';
import '../domain/note.dart';
import '../ink/ink_layer_repository.dart';
import 'mindmap_controller.dart';
import 'widgets/ink_thumbnail.dart';

/// 节点组件。
///
/// 显示导图节点，支持选中、展开/折叠、PDF 源跳转等。
class NodeWidget extends StatelessWidget {
  final Note note;
  final bool isSelected;
  final bool isCollapsed;
  final bool isFrameworkNode;
  final VoidCallback onTap;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;  // 右键菜单（桌面端）
  final VoidCallback? onAddChild;
  final VoidCallback? onDelete;
  final VoidCallback? onToggleCollapse;
  final Size? customSize;
  final MindMapController? controller;
  final InkLayerRepository? inkLayerRepository;

  const NodeWidget({
    super.key,
    required this.note,
    this.isSelected = false,
    this.isCollapsed = false,
    this.isFrameworkNode = false,
    required this.onTap,
    this.onDoubleTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.onAddChild,
    this.onDelete,
    this.onToggleCollapse,
    this.customSize,
    this.controller,
    this.inkLayerRepository,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = MindMapColors.accent;

    // 判断是否为被选中状态 (或者在控制器的多选列表中)
    final selected = isSelected || (controller != null && controller!.selectedNoteIds.contains(note.id));

    // 根据布局样式选择渲染方式（使用 topic 级布局状态）
    if (isFrameworkNode) {
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
        onSecondaryTap: onSecondaryTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: MindMapColors.nestedCardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? accentColor : MindMapColors.accentBorder,
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
                  color: selected ? MindMapColors.accentSelectedHeader : MindMapColors.nestedCardBackground,
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
                      color: selected ? accentColor : MindMapColors.accent.withOpacity(0.8),
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
      onSecondaryTap: onSecondaryTap,  // 右键菜单（桌面端）
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: customSize?.width,
        height: customSize?.height,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: MindMapColors.nodeBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected 
                ? accentColor 
                : (isNestedCard ? MindMapColors.accent.withOpacity(0.5) : MindMapColors.nodeBorder),
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
            // 墨迹缩略图
            if (note.inkLayerId != null && inkLayerRepository != null)
              InkThumbnail(
                inkLayerId: note.inkLayerId!,
                nodeId: note.id,
                repository: inkLayerRepository!,
                size: 32,
                opacity: 0.7,
              ),
            if (note.inkLayerId != null) const SizedBox(width: 6),
            // 卡片组折叠图标
            if (isNestedCard) ...[
              Icon(
                Icons.grid_view_rounded,
                size: 14,
                color: selected ? accentColor : MindMapColors.accent.withOpacity(0.8),
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
              child: controller?.editingNoteId == note.id
                  ? Shortcuts(
                      shortcuts: const {
                        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                      },
                      child: Actions(
                        actions: {
                          DismissIntent: CallbackAction<DismissIntent>(
                            onInvoke: (_) {
                              controller?.cancelEditing(note.id);
                              return null;
                            },
                          ),
                        },
                        child: TextField(
                          controller: TextEditingController(text: note.title)
                            ..selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: note.title.length,
                            ),
                          autofocus: true,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onSubmitted: (value) {
                            controller?.commitEditing(note.id, value);
                          },
                        ),
                      ),
                    )
                  : Text(
                      note.title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: (selected || isNestedCard) ? FontWeight.w600 : FontWeight.normal,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
            ),
            // 标签芯片（最多 3 个）
            if (controller != null &&
                controller!.tagsByNoteId.containsKey(note.id)) ...[
              const SizedBox(width: 4),
              ...controller!.tagsByNoteId[note.id]!.take(3).map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFFC8841A).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    tag.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFE8A83C),
                      fontSize: 9,
                    ),
                  ),
                );
              }),
            ],
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
                '',
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
      onSecondaryTap: onSecondaryTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: w,
        height: h,
        decoration: BoxDecoration(
          color: MindMapColors.nestedCardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accentColor : MindMapColors.frameworkBorder,
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
                color: selected ? MindMapColors.accentSelectedHeader : MindMapColors.nestedCardBackground,
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
                    color: selected ? accentColor : MindMapColors.accent.withOpacity(0.8),
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

