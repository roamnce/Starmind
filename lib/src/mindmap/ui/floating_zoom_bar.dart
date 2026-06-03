// lib/src/mindmap/ui/floating_zoom_bar.dart
//
// 左下角浮动缩放条组件。
//
// 包含缩放控制、关于导图、快捷键、小地图按钮。

import 'dart:ui';
import 'package:flutter/material.dart';
import 'mindmap_controller.dart';

/// 左下角浮动缩放条。
///
/// 显示缩放控制按钮和其他快捷入口。
class FloatingZoomBar extends StatelessWidget {
  final MindMapController controller;
  final VoidCallback? onShowInfo;
  final VoidCallback? onShowShortcuts;
  final VoidCallback? onToggleMinimap;

  const FloatingZoomBar({
    super.key,
    required this.controller,
    this.onShowInfo,
    this.onShowShortcuts,
    this.onToggleMinimap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 24,
      left: 24,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xB814100C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0x14FFDC8C),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 放大按钮
                _buildButton(
                  icon: Icons.add_rounded,
                  onPressed: controller.zoomIn,
                  tooltip: '放大',
                ),
                // 缩放百分比
                GestureDetector(
                  onDoubleTap: controller.resetViewport,
                  child: Container(
                    height: 24,
                    constraints: const BoxConstraints(minWidth: 36),
                    alignment: Alignment.center,
                    child: Text(
                      '${(controller.viewportScale * 100).toInt()}%',
                      style: const TextStyle(
                        color: Color(0xB3FFF8E6),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                // 缩小按钮
                _buildButton(
                  icon: Icons.remove_rounded,
                  onPressed: controller.zoomOut,
                  tooltip: '缩小',
                ),
                // 分隔线
                Container(
                  width: 18,
                  height: 1,
                  margin: const EdgeInsets.symmetric(vertical: 3),
                  color: const Color(0x14FFDC8C),
                ),
                // 关于导图按钮
                _buildButton(
                  icon: Icons.info_outline_rounded,
                  onPressed: onShowInfo,
                  tooltip: '关于导图',
                ),
                // 快捷键按钮
                _buildButton(
                  icon: Icons.help_outline_rounded,
                  onPressed: onShowShortcuts,
                  tooltip: '快捷键',
                ),
                // 小地图按钮
                _buildButton(
                  icon: Icons.map_outlined,
                  onPressed: onToggleMinimap,
                  isActive: controller.isMinimapVisible,
                  tooltip: controller.isMinimapVisible ? '隐藏小地图' : '显示小地图',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required VoidCallback? onPressed,
    required String tooltip,
    bool isActive = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isActive ? const Color(0x26C8841A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: const Color(0x33C8841A), width: 1)
                : null,
          ),
          child: Icon(
            icon,
            size: 15,
            color: isActive ? const Color(0xFFE8A83C) : const Color(0xB3FFF8E6),
          ),
        ),
      ),
    );
  }
}
