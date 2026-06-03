// lib/src/mindmap/ui/dialogs/more_actions_menu.dart
//
// 更多操作下拉菜单。
//
// 包含导出、闪卡、演示模式、UI组件显示控制等选项。

import 'package:flutter/material.dart';

/// 更多操作菜单项数据
class MoreActionItem {
  final String label;
  final IconData? icon;
  final bool isDanger;
  final VoidCallback? onTap;

  const MoreActionItem({
    required this.label,
    this.icon,
    this.isDanger = false,
    this.onTap,
  });
}

/// 显示更多操作菜单
void showMoreActionsMenu({
  required BuildContext context,
  required Offset position,
  required List<MoreActionItem> items,
}) {
  showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx - 170,
      position.dy + 8,
      position.dx,
      position.dy,
    ),
    color: const Color(0xFF1C1710),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: const BorderSide(color: Color(0x1AFFDC8C), width: 1),
    ),
    items: items.map((item) {
      return PopupMenuItem<String>(
        value: item.label,
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 14,
                color: item.isDanger ? const Color(0xFFE05858) : const Color(0xB3FFF8E6),
              ),
              const SizedBox(width: 10),
            ],
            Text(
              item.label,
              style: TextStyle(
                color: item.isDanger ? const Color(0xFFE05858) : const Color(0xB3FFF8E6),
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: item.onTap,
      );
    }).toList(),
  );
}

/// 默认的更多操作菜单项
List<MoreActionItem> getDefaultMoreActions({
  VoidCallback? onExport,
  VoidCallback? onFlashcard,
  VoidCallback? onPresent,
  VoidCallback? onToggleTopLeft,
  VoidCallback? onToggleLeftZoom,
  VoidCallback? onToggleBottomToolbar,
  bool topLeftVisible = true,
  bool leftZoomVisible = true,
  bool bottomToolbarVisible = true,
}) {
  return [
    MoreActionItem(
      label: '导出文件',
      icon: Icons.upload_file_rounded,
      onTap: onExport,
    ),
    MoreActionItem(
      label: '生成闪卡',
      icon: Icons.style_rounded,
      onTap: onFlashcard,
    ),
    MoreActionItem(
      label: '演示模式',
      icon: Icons.play_arrow_rounded,
      onTap: onPresent,
    ),
    // 分隔线通过 isDense 实现
    MoreActionItem(
      label: topLeftVisible ? '隐藏左上按钮组' : '显示左上按钮组',
      icon: Icons.visibility_off_rounded,
      onTap: onToggleTopLeft,
    ),
    MoreActionItem(
      label: leftZoomVisible ? '隐藏左下按钮组' : '显示左下按钮组',
      icon: Icons.visibility_off_rounded,
      onTap: onToggleLeftZoom,
    ),
    MoreActionItem(
      label: bottomToolbarVisible ? '隐藏底部按钮组' : '显示底部按钮组',
      icon: Icons.visibility_off_rounded,
      onTap: onToggleBottomToolbar,
    ),
  ];
}
