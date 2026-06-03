// lib/src/mindmap/ui/components/vertical_tab_bar.dart
//
// 垂直标签栏组件。
//
// 用于切换侧边栏面板的垂直标签栏。

import 'package:flutter/material.dart';
import '../mindmap_controller.dart';

/// 垂直标签栏。
///
/// 显示侧边栏的切换按钮（笔记、搜索、主题、样式、图标）。
class VerticalTabBar extends StatelessWidget {
  final MindMapController controller;

  const VerticalTabBar({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      decoration: const BoxDecoration(
        color: Color(0xFF0E0A07),
        border: Border(
          left: BorderSide(color: Color(0x14FFDC8C), width: 1),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          _buildTabButton(context, SidebarTab.note, Icons.send_rounded, '节点笔记'),
          const SizedBox(height: 12),
          _buildTabButton(context, SidebarTab.search, Icons.search_rounded, '节点搜索'),
          const SizedBox(height: 12),
          _buildTabButton(context, SidebarTab.theme, Icons.palette_outlined, '导图主题'),
          const SizedBox(height: 12),
          _buildTabButton(context, SidebarTab.config, Icons.tune_rounded, '样式配置'),
          const SizedBox(height: 12),
          _buildTabButton(context, SidebarTab.icon, Icons.sentiment_satisfied_alt_rounded, '节点图标'),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildTabButton(BuildContext context, SidebarTab tab, IconData icon, String tooltip) {
    final isActive = controller.isSidebarExpanded && controller.activeSidebarTab == tab;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => controller.toggleSidebar(tab),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive ? const Color(0xFF1862C6) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: const Color(0xFF1862C6).withOpacity(0.4),
                      blurRadius: 8,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Transform.rotate(
            angle: tab == SidebarTab.note ? -0.5 : 0.0,
            child: Icon(
              icon,
              color: isActive ? Colors.white : const Color(0xB3FFF8E6),
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}