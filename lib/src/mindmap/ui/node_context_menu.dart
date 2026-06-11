// lib/src/mindmap/ui/node_context_menu.dart

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// 节点悬浮上下文菜单。
///
/// 使用 Forui 的 FPopover 实现横向悬浮菜单。
/// 包含四个图标按钮：添加子节点、添加兄弟节点、手写批注、删除节点。
class NodeContextMenu extends StatelessWidget {
  /// 子组件（节点）
  final Widget child;

  /// 添加子节点回调
  final VoidCallback? onAddChild;

  /// 添加兄弟节点回调
  final VoidCallback? onAddSibling;

  /// 手写批注回调（进入节点级手写模式）
  final VoidCallback? onEditInk;

  /// 删除节点回调
  final VoidCallback? onDelete;

  const NodeContextMenu({
    super.key,
    required this.child,
    this.onAddChild,
    this.onAddSibling,
    this.onEditInk,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 菜单固定显示在节点上方
    const popoverAnchor = Alignment.bottomCenter;
    const childAnchor = Alignment.topCenter;

    return FTheme(
      data: FThemes.neutral.dark.touch,
      child: FPopover(
        popoverAnchor: popoverAnchor,
        childAnchor: childAnchor,
        popoverBuilder: (context, controller) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3547),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x33FFDC8C)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 添加子节点
              _MenuButton(
                icon: FLucideIcons.plus,
                color: const Color(0xFFE8A83C),
                onPressed: () {
                  controller.hide();
                  onAddChild?.call();
                },
              ),
              const SizedBox(width: 4),
              // 添加兄弟节点（用向下箭头+加号表示"同级添加"）
              _MenuButton(
                icon: FLucideIcons.arrowDownFromLine,
                color: const Color(0xFFE8A83C),
                onPressed: () {
                  controller.hide();
                  onAddSibling?.call();
                },
              ),
              const SizedBox(width: 4),
              // 手写批注
              _MenuButton(
                icon: FLucideIcons.pencil,
                color: const Color(0xFF7DD3FC),
                onPressed: () {
                  controller.hide();
                  onEditInk?.call();
                },
              ),
              const SizedBox(width: 4),
              // 删除节点
              _MenuButton(
                icon: FLucideIcons.trash2,
                color: const Color(0xFFFF6B6B),
                onPressed: () {
                  controller.hide();
                  onDelete?.call();
                },
              ),
            ],
          ),
        ),
        builder: (context, controller, child) => GestureDetector(
          onSecondaryTap: controller.toggle,
          onLongPress: controller.toggle,
          child: this.child,
        ),
      ),
    );
  }
}

/// 概要悬浮上下文菜单。
///
/// 只包含删除按钮。
class SummaryContextMenu extends StatelessWidget {
  /// 子组件（概要标签）
  final Widget child;

  /// 删除概要回调
  final VoidCallback? onDelete;

  const SummaryContextMenu({
    super.key,
    required this.child,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // 菜单固定显示在概要上方
    const popoverAnchor = Alignment.bottomCenter;
    const childAnchor = Alignment.topCenter;

    return FTheme(
      data: FThemes.neutral.dark.touch,
      child: FPopover(
        popoverAnchor: popoverAnchor,
        childAnchor: childAnchor,
        popoverBuilder: (context, controller) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF2A3547),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0x33FFDC8C)),
          ),
          child: _MenuButton(
            icon: FLucideIcons.trash2,
            color: const Color(0xFFFF6B6B),
            onPressed: () {
              controller.hide();
              onDelete?.call();
            },
          ),
        ),
        builder: (context, controller, child) => GestureDetector(
          onSecondaryTap: controller.toggle,
          onLongPress: controller.toggle,
          onTap: () {
            // 单击选中概要
            controller.show();
          },
          child: this.child,
        ),
      ),
    );
  }
}

/// 菜单按钮
class _MenuButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _MenuButton({
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
      ),
    );
  }
}
