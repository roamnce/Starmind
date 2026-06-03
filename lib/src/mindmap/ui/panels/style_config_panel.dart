// lib/src/mindmap/ui/panels/style_config_panel.dart
//
// 样式配置面板。
//
// 提供画布背景色、网格线颜色、彩虹分支、线样式等配置。

import 'package:flutter/material.dart';
import '../mindmap_controller.dart';

/// 样式配置面板。
///
/// 显示画布背景色、网格颜色、彩虹分支、线样式等配置选项。
class StyleConfigPanel extends StatelessWidget {
  final MindMapController controller;

  const StyleConfigPanel({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 画布背景色
        const Text(
          '画布背景色',
          style: TextStyle(
            color: Color(0xB3FFF8E6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildColorPresetRow(
          colors: [
            const Color(0xFF0C0A07),
            const Color(0xFF141B24),
            const Color(0xFF0A140D),
            const Color(0xFF0A0515),
          ],
          names: ['经典漆黑', '深空灰蓝', '密林暗绿', '紫幻魅影'],
          currentColor: controller.canvasBgColor,
          onSelect: (color) => controller.updateTheme(canvasBgColor: color),
        ),

        const SizedBox(height: 16),

        // 网格线颜色
        const Text(
          '网格线颜色',
          style: TextStyle(
            color: Color(0xB3FFF8E6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildColorPresetRow(
          colors: [
            const Color(0x05FFFFFF),
            const Color(0x0DFAD278),
            const Color(0x0800F0FF),
            const Color(0x08FF007F),
          ],
          names: ['微白', '浅柔金', '冰爽蓝', '霓虹红'],
          currentColor: controller.gridColor,
          onSelect: (color) => controller.updateTheme(gridColor: color),
          isGrid: true,
        ),

        const SizedBox(height: 16),

        // 显示网格
        _buildSettingRow(
          label: '显示网格',
          value: controller.showGrid,
          onChanged: (val) => controller.updateTheme(showGrid: val),
        ),

        const SizedBox(height: 12),

        // 彩虹分支颜色
        _buildSettingRow(
          label: '彩虹分支颜色',
          value: controller.isRainbowBranch,
          onChanged: (_) => controller.toggleRainbowBranch(),
        ),

        const SizedBox(height: 12),

        // 导图线样式
        const Text(
          '导图线样式',
          style: TextStyle(
            color: Color(0xB3FFF8E6),
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        _buildLineStyleSelector(controller),

        const SizedBox(height: 16),

        // 网格大小
        if (controller.showGrid)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '网格大小: ${controller.gridSize.toInt()}',
                style: const TextStyle(
                  color: Color(0xB3FFF8E6),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Slider(
                value: controller.gridSize.clamp(15.0, 30.0),
                min: 15,
                max: 30,
                onChanged: (val) => controller.updateTheme(gridSize: val),
                activeColor: const Color(0xFF5CB8FC),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildColorPresetRow({
    required List<Color> colors,
    required List<String> names,
    required Color currentColor,
    required ValueChanged<Color> onSelect,
    bool isGrid = false,
  }) {
    return Row(
      children: List.generate(colors.length, (index) {
        final color = colors[index];
        final isSelected = currentColor.value == color.value;

        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(color),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              height: 40,
              decoration: BoxDecoration(
                color: isGrid ? controller.canvasBgColor : color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected ? const Color(0xFF5CB8FC) : const Color(0x14FFDC8C),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  names[index],
                  style: TextStyle(
                    color: isSelected ? const Color(0xE6FFF8E6) : const Color(0x80FFF8E6),
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSettingRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xB3FFF8E6),
            fontSize: 13,
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF5CB8FC),
        ),
      ],
    );
  }

  Widget _buildLineStyleSelector(MindMapController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x0DFFF8E6),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x14FFDC8C), width: 1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LineStyle>(
          value: controller.lineStyle,
          isExpanded: true,
          dropdownColor: const Color(0xFF1C1710),
          style: const TextStyle(color: Color(0xE6FFF8E6), fontSize: 12),
          items: const [
            DropdownMenuItem(
              value: LineStyle.bezier,
              child: Text('贝塞尔曲线'),
            ),
            DropdownMenuItem(
              value: LineStyle.straight,
              child: Text('直线连接'),
            ),
            DropdownMenuItem(
              value: LineStyle.ortho,
              child: Text('直角连线'),
            ),
          ],
          onChanged: (style) {
            if (style != null) {
              controller.setLineStyle(style);
            }
          },
        ),
      ),
    );
  }
}