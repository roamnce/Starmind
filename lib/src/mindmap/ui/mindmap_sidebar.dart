// lib/src/mindmap/ui/mindmap_sidebar.dart

import 'package:flutter/material.dart';
import 'mindmap_controller.dart';
import '../domain/note.dart';
import 'markdown_editor_toolbar.dart';

class MindMapSidebar extends StatelessWidget {
  final MindMapController controller;
  final TextEditingController textController;
  final FocusNode? focusNode;

  const MindMapSidebar({
    super.key,
    required this.controller,
    required this.textController,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    if (!controller.isSidebarExpanded) {
      return const SizedBox.shrink();
    }

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF141921),
        border: Border(
          left: BorderSide(color: Color(0x1F2A3547), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: Color(0x1F2A3547)),
          Expanded(
            child: _buildContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final tab = controller.activeSidebarTab;
    final IconData icon;
    final String title;
    Widget? trailing;

    switch (tab) {
      case SidebarTab.note:
        icon = Icons.send_rounded; // diagonal paper plane
        title = '节点笔记';
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              onPressed: () => controller.navigateSibling('prev'),
              tooltip: '上一个同级节点',
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                foregroundColor: Colors.white70,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 20),
              onPressed: () => controller.navigateSibling('next'),
              tooltip: '下一个同级节点',
              style: IconButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(32, 32),
                foregroundColor: Colors.white70,
              ),
            ),
          ],
        );
        break;
      case SidebarTab.style:
        icon = Icons.push_pin_rounded; // diagonal pin/thumbtack
        title = '导图主题';
        break;
      case SidebarTab.icon:
        icon = Icons.sentiment_satisfied_alt_rounded; // smiley face
        title = '节点图标';
        break;
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Transform.rotate(
            angle: tab == SidebarTab.note ? -0.5 : 0.0, // diagonal look for paper plane
            child: Icon(icon, color: const Color(0xFF1862C6), size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (controller.activeSidebarTab) {
      case SidebarTab.note:
        return _buildNotePanel(context);
      case SidebarTab.style:
        return _buildStylePanel(context);
      case SidebarTab.icon:
        return _buildIconPanel(context);
    }
  }

  Widget _buildNotePanel(BuildContext context) {
    final note = controller.selectedNote;
    if (note == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.edit_note_rounded, size: 48, color: Colors.white30),
              SizedBox(height: 12),
              Text(
                '请在画布中选中一个节点\n以编辑笔记',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white30, fontSize: 14, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '标题: ${note.title}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          MarkdownEditorToolbar(
            textController: textController,
            focusNode: focusNode,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x0DFFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x1F2A3547)),
              ),
              child: TextField(
                controller: textController,
                focusNode: focusNode,
                maxLines: null,
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                decoration: const InputDecoration(
                  hintText: '输入笔记内容...',
                  hintStyle: TextStyle(color: Colors.white30),
                  border: InputBorder.none,
                ),
                onChanged: (val) {
                  controller.updateNoteContent(note.id, val);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStylePanel(BuildContext context) {
    // Presets defined in requirement
    final bgPresets = [
      {'name': '经典暗黑', 'color': const Color(0xFF0C0A07)},
      {'name': '深空灰蓝', 'color': const Color(0xFF141B24)},
      {'name': '暗绿森林', 'color': const Color(0xFF0A140D)},
      {'name': '幽冥幻紫', 'color': const Color(0xFF0A0515)},
    ];

    final gridPresets = [
      {'name': '经典白', 'color': const Color(0x05FFFFFF)},
      {'name': '奢华金', 'color': const Color(0x0DFAD278)},
      {'name': '冰川蓝', 'color': const Color(0x0800F0FF)},
      {'name': '霓虹红', 'color': const Color(0x08FF007F)},
    ];

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Presets Canvas Background
        const Text(
          '画布背景色',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: bgPresets.map((preset) {
            final isSelected = controller.canvasBgColor == preset['color'];
            return InkWell(
              onTap: () => controller.updateTheme(canvasBgColor: preset['color'] as Color),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                decoration: BoxDecoration(
                  color: preset['color'] as Color,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1862C6) : const Color(0x1F2A3547),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  preset['name'] as String,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        // Custom Canvas Background
        _buildCustomBgSliders(),

        const SizedBox(height: 24),
        // Presets Grid Line Color
        const Text(
          '网格线颜色',
          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.2,
          children: gridPresets.map((preset) {
            final isSelected = controller.gridColor.value == (preset['color'] as Color).value;
            return InkWell(
              onTap: () => controller.updateTheme(gridColor: preset['color'] as Color),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                decoration: BoxDecoration(
                  color: controller.canvasBgColor,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF1862C6) : const Color(0x1F2A3547),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Stack(
                  children: [
                    // Grid pattern preview
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MiniGridPainter(preset['color'] as Color),
                      ),
                    ),
                    Center(
                      child: Text(
                        preset['name'] as String,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white60,
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 16),
        // Custom Grid Color
        _buildCustomGridSliders(),

        const SizedBox(height: 24),
        // Grid Display and Size Settings
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              '网格显示',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            Switch(
              value: controller.showGrid,
              onChanged: (val) => controller.updateTheme(showGrid: val),
              activeColor: const Color(0xFF1862C6),
              activeTrackColor: const Color(0x3D1862C6),
              inactiveThumbColor: Colors.grey,
              inactiveTrackColor: const Color(0x1F2A3547),
            ),
          ],
        ),

        if (controller.showGrid) ...[
          const SizedBox(height: 12),
          Text(
            '网格大小: ${controller.gridSize.toStringAsFixed(0)}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Slider(
            value: controller.gridSize.clamp(20.0, 100.0),
            min: 20.0,
            max: 100.0,
            activeColor: const Color(0xFF1862C6),
            inactiveColor: const Color(0x1F2A3547),
            onChanged: (val) => controller.updateTheme(gridSize: val),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomBgSliders() {
    final color = controller.canvasBgColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x05FFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '自定义背景色 (RGB)',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
          const SizedBox(height: 8),
          _buildColorSlider('R', color.red, (val) {
            controller.updateTheme(canvasBgColor: Color.fromARGB(255, val, color.green, color.blue));
          }),
          _buildColorSlider('G', color.green, (val) {
            controller.updateTheme(canvasBgColor: Color.fromARGB(255, color.red, val, color.blue));
          }),
          _buildColorSlider('B', color.blue, (val) {
            controller.updateTheme(canvasBgColor: Color.fromARGB(255, color.red, color.green, val));
          }),
        ],
      ),
    );
  }

  Widget _buildCustomGridSliders() {
    final color = controller.gridColor;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x05FFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0DFFFFFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '自定义网格色 (RGBA)',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
          const SizedBox(height: 8),
          _buildColorSlider('R', color.red, (val) {
            controller.updateTheme(gridColor: Color.fromARGB(color.alpha, val, color.green, color.blue));
          }),
          _buildColorSlider('G', color.green, (val) {
            controller.updateTheme(gridColor: Color.fromARGB(color.alpha, color.red, val, color.blue));
          }),
          _buildColorSlider('B', color.blue, (val) {
            controller.updateTheme(gridColor: Color.fromARGB(color.alpha, color.red, color.green, val));
          }),
          Row(
            children: [
              SizedBox(
                width: 16,
                child: Text('A', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
              ),
              Expanded(
                child: Slider(
                  value: color.opacity,
                  min: 0.0,
                  max: 1.0,
                  activeColor: const Color(0xFF1862C6),
                  inactiveColor: const Color(0x1F2A3547),
                  onChanged: (val) {
                    controller.updateTheme(gridColor: color.withOpacity(val));
                  },
                ),
              ),
              SizedBox(
                width: 32,
                child: Text(
                  color.opacity.toStringAsFixed(2),
                  textAlign: TextAlign.end,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorSlider(String label, int value, ValueChanged<int> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 16,
          child: Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 255,
            activeColor: const Color(0xFF1862C6),
            inactiveColor: const Color(0x1F2A3547),
            onChanged: (val) => onChanged(val.toInt()),
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _buildIconPanel(BuildContext context) {
    final emojis = ['📌', '🚀', '⭐', '🔥', '✅', '❌', '📝', '💡', '🎨', '🔍', '📅', '👑', '💻', '💼', '📈', '🎯', '❤️', '👍', '🔔', '📣'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '快捷节点图标 (点击插入或替换标题首部)',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.count(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: emojis.map((emoji) {
                return InkWell(
                  onTap: () {
                    if (controller.selectedNote != null) {
                      final currentTitle = controller.selectedNote!.title;
                      // Replace existing emoji if title starts with one, or just prepend
                      var newTitle = currentTitle;
                      final regex = RegExp(r'^[\u2000-\u32FF\ud83c-\udbff\udc00-\udfff\ufe0f]+\s*');
                      if (regex.hasMatch(currentTitle)) {
                        newTitle = currentTitle.replaceFirst(regex, '$emoji ');
                      } else {
                        newTitle = '$emoji $currentTitle';
                      }
                      controller.updateNoteTitle(controller.selectedNote!.id, newTitle);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0x05FFFFFF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0x0DFFFFFF)),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniGridPainter extends CustomPainter {
  final Color gridColor;

  _MiniGridPainter(this.gridColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0;

    for (double x = 4; x < size.width; x += 12) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 4; y < size.height; y += 12) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniGridPainter oldDelegate) => gridColor != oldDelegate.gridColor;
}
