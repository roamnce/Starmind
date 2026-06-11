// lib/src/mindmap/ui/components/ink_toolbar.dart
//
// 手写工具栏：笔 / 荧光笔 / 橡皮 + 颜色选择器。
// 仅在 isInkMode 时由 MindMapPage 显示。

import 'dart:ui';
import 'package:flutter/material.dart';
import '../mindmap_controller.dart';
import '../../ink/ink_layer.dart' show InkTool;

/// 手写工具栏子组件。
///
/// 包含 pen / highlighter / eraser 三个工具按钮和颜色选择器。
/// 当 [MindMapController.isInkMode] 为 true 时由父组件显示。
class InkToolbar extends StatelessWidget {
  final MindMapController controller;

  /// 手写工具变更回调——用于同步 InkLayerController
  final void Function(InkTool)? onToolChanged;

  /// 颜色变更回调——用于同步 InkLayerController
  final void Function(int)? onColorChanged;

  /// 预设颜色列表
  static const _presetColors = [
    Color(0xFFFFFFFF), // 白
    Color(0xFFE8A83C), // 琥珀
    Color(0xFF4D96FF), // 蓝
    Color(0xFF6BCB77), // 绿
    Color(0xFFFF6B6B), // 红
    Color(0xFF9B59B6), // 紫
  ];

  const InkToolbar({
    super.key,
    required this.controller,
    this.onToolChanged,
    this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xB814100C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0x14FFDC8C),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 笔
              _buildToolButton(
                icon: Icons.edit,
                isActive: controller.inkTool == InkTool.pen,
                onPressed: () {
                  controller.setInkTool(InkTool.pen);
                  onToolChanged?.call(InkTool.pen);
                },
                tooltip: '画笔',
              ),
              // 荧光笔
              _buildToolButton(
                icon: Icons.highlight,
                isActive: controller.inkTool == InkTool.highlighter,
                onPressed: () {
                  controller.setInkTool(InkTool.highlighter);
                  onToolChanged?.call(InkTool.highlighter);
                },
                tooltip: '荧光笔',
              ),
              // 橡皮
              _buildToolButton(
                icon: Icons.cleaning_services,
                isActive: controller.inkTool == InkTool.eraser,
                onPressed: () {
                  controller.setInkTool(InkTool.eraser);
                  onToolChanged?.call(InkTool.eraser);
                },
                tooltip: '橡皮',
              ),
              _buildDivider(),
              // 颜色选择器
              ..._presetColors.map((color) => _buildColorButton(color)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? const Color(0x26C8841A) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isActive
                ? Border.all(color: const Color(0x33C8841A), width: 1)
                : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isActive
                ? const Color(0xFFE8A83C)
                : const Color(0xB3FFF8E6),
          ),
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    return Tooltip(
      message: '#${color.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
      child: InkWell(
        onTap: () {
          onColorChanged?.call(color.value);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0x33FFDC8C),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 16,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0x14FFDC8C),
    );
  }
}
