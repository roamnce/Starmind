// lib/src/mindmap/ui/bottom_action_bar.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'mindmap_controller.dart';
import 'tree_layout.dart';

class BottomActionBar extends StatelessWidget {
  final MindMapController controller;
  final VoidCallback onFitToScreen;

  const BottomActionBar({
    super.key,
    required this.controller,
    required this.onFitToScreen,
  });

  String _getLayoutText(LayoutDirection direction) {
    switch (direction) {
      case LayoutDirection.bothSides:
        return '两侧布局';
      case LayoutDirection.left:
        return '左侧布局';
      case LayoutDirection.horizontal:
        return '右侧布局';
      case LayoutDirection.vertical:
        return '垂直布局';
    }
  }

  void _showLayoutMenu(BuildContext context, RenderBox button, RenderBox overlay) {
    final Offset buttonPosition = button.localToGlobal(Offset.zero, ancestor: overlay);
    final Size buttonSize = button.size;

    // Position exactly 2px above the button
    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy - 2,
      buttonPosition.dx + buttonSize.width,
      buttonPosition.dy,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1C222B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x1F2A3547), width: 1),
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'bothSides',
          child: Text('两侧布局', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: 'left',
          child: Text('左侧布局', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: 'horizontal',
          child: Text('右侧布局', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: 'nestedCard',
          child: Text('嵌套卡片', style: TextStyle(color: Colors.white70, fontSize: 13)),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      if (value == 'bothSides') {
        controller.changeLayoutDirection(LayoutDirection.bothSides);
      } else if (value == 'left') {
        controller.changeLayoutDirection(LayoutDirection.left);
      } else if (value == 'horizontal') {
        controller.changeLayoutDirection(LayoutDirection.horizontal);
      } else if (value == 'nestedCard') {
        // "嵌套卡片" -> does nothing or toggles default layout style (note: layout nestedCard is handled dynamically inside TreeLayout, but keeping standard tree direction is fine).
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLassoMode = controller.interactMode == CanvasInteractMode.lasso;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xCC141921),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0x1F2A3547),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom out button
              IconButton(
                key: const ValueKey('zoom_out'),
                icon: const Icon(Icons.remove_rounded, color: Colors.white70, size: 20),
                onPressed: controller.zoomOut,
                tooltip: '缩小',
                splashRadius: 20,
              ),
              // Scale display
              SizedBox(
                width: 48,
                child: Center(
                  child: Text(
                    '${(controller.viewportScale * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              // Zoom in button
              IconButton(
                key: const ValueKey('zoom_in'),
                icon: const Icon(Icons.add_rounded, color: Colors.white70, size: 20),
                onPressed: controller.zoomIn,
                tooltip: '放大',
                splashRadius: 20,
              ),
              // Separator
              _buildVerticalDivider(),
              // Zoom Fit
              IconButton(
                key: const ValueKey('zoom_fit'),
                icon: const Icon(Icons.fit_screen_rounded, color: Colors.white70, size: 20),
                onPressed: onFitToScreen,
                tooltip: '适应屏幕',
                splashRadius: 20,
              ),
              // Separator
              _buildVerticalDivider(),
              // Canvas mode toggle (hand/crop)
              IconButton(
                key: const ValueKey('mode_toggle'),
                icon: Icon(
                  isLassoMode ? Icons.crop_free_rounded : Icons.pan_tool_rounded,
                  color: isLassoMode ? const Color(0xFF1862C6) : Colors.white70,
                  size: 20,
                ),
                onPressed: () {
                  final nextMode = isLassoMode ? CanvasInteractMode.drag : CanvasInteractMode.lasso;
                  controller.setInteractMode(nextMode);
                },
                tooltip: isLassoMode ? '框选模式' : '拖拽模式',
                splashRadius: 20,
              ),
              // Separator
              _buildVerticalDivider(),
              // Layout popup selector
              Builder(
                builder: (buttonContext) {
                  return InkWell(
                    key: const ValueKey('layout_selector'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      final RenderBox button = buttonContext.findRenderObject() as RenderBox;
                      final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
                      _showLayoutMenu(buttonContext, button, overlay);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            _getLayoutText(controller.layoutDirection),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_drop_up_rounded,
                            color: Colors.white70,
                            size: 18,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Separator
              _buildVerticalDivider(),
              // Edit lock
              IconButton(
                key: const ValueKey('edit_lock'),
                icon: Icon(
                  controller.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  color: controller.isLocked ? Colors.redAccent : Colors.white70,
                  size: 20,
                ),
                onPressed: controller.toggleLock,
                tooltip: controller.isLocked ? '已锁定编辑' : '已启用编辑',
                splashRadius: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      height: 16,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0x1F2A3547),
    );
  }
}
