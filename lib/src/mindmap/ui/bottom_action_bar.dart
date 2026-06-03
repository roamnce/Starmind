// lib/src/mindmap/ui/bottom_action_bar.dart
//
// 底部浮动操作栏。
//
// 按原型设计包含 11 个按钮：拖动、套索、添加子节点、添加同级节点、
// 创建概要、创建边框、关联线、创建标签、导图布局、添加节点笔记、锁定。

import 'dart:ui';
import 'package:flutter/material.dart';
import 'mindmap_controller.dart';
import 'tree_layout.dart';

class BottomActionBar extends StatelessWidget {
  final MindMapController controller;
  final VoidCallback? onFitToScreen;
  final VoidCallback? onShowAddChildDialog;
  final VoidCallback? onShowAddSiblingDialog;
  final VoidCallback? onAddNote;

  const BottomActionBar({
    super.key,
    required this.controller,
    this.onFitToScreen,
    this.onShowAddChildDialog,
    this.onShowAddSiblingDialog,
    this.onAddNote,
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

    final RelativeRect position = RelativeRect.fromLTRB(
      buttonPosition.dx,
      buttonPosition.dy - 2,
      buttonPosition.dx + buttonSize.width,
      buttonPosition.dy,
    );

    showMenu<String>(
      context: context,
      position: position,
      color: const Color(0xFF1C1710),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0x14FFDC8C), width: 1),
      ),
      items: const [
        PopupMenuItem<String>(
          value: 'bothSides',
          child: Text('两侧布局', style: TextStyle(color: Color(0xB3FFF8E6), fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: 'left',
          child: Text('左侧布局', style: TextStyle(color: Color(0xB3FFF8E6), fontSize: 13)),
        ),
        PopupMenuItem<String>(
          value: 'horizontal',
          child: Text('右侧布局', style: TextStyle(color: Color(0xB3FFF8E6), fontSize: 13)),
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
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLassoMode = controller.interactMode == CanvasInteractMode.lasso;

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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. 拖动/手掌工具
                _buildButton(
                  icon: Icons.pan_tool_rounded,
                  isActive: !isLassoMode,
                  onPressed: () => controller.setInteractMode(CanvasInteractMode.drag),
                  tooltip: '拖动工具',
                ),
                // 2. 套索工具
                _buildButton(
                  icon: Icons.crop_free_rounded,
                  isActive: isLassoMode,
                  onPressed: () => controller.setInteractMode(CanvasInteractMode.lasso),
                  tooltip: '套索批量选择',
                ),
                _buildDivider(),
                // 3. 添加子节点
                _buildButton(
                  icon: Icons.add_circle_outline_rounded,
                  onPressed: onShowAddChildDialog,
                  tooltip: '添加子节点 (Tab)',
                ),
                // 4. 添加同级节点
                _buildButton(
                  icon: Icons.control_point_duplicate_rounded,
                  onPressed: onShowAddSiblingDialog,
                  tooltip: '添加同级节点 (Enter)',
                ),
                _buildDivider(),
                // 5. 创建概要
                _buildButton(
                  icon: Icons.subject_rounded,
                  onPressed: null, // TODO: 实现创建概要
                  tooltip: '创建概要',
                ),
                // 6. 创建边框
                _buildButton(
                  icon: Icons.rectangle_outlined,
                  onPressed: null, // TODO: 实现创建边框
                  tooltip: '创建边框',
                ),
                // 7. 关联线
                _buildButton(
                  icon: Icons.link_rounded,
                  onPressed: null, // TODO: 实现关联线
                  tooltip: '关联线',
                ),
                // 8. 创建标签
                _buildButton(
                  icon: Icons.local_offer_outlined,
                  onPressed: null, // TODO: 实现创建标签
                  tooltip: '创建标签',
                ),
                _buildDivider(),
                // 9. 导图布局
                Builder(
                  builder: (buttonContext) {
                    return _buildButton(
                      icon: Icons.account_tree_rounded,
                      onPressed: () {
                        final RenderBox button = buttonContext.findRenderObject() as RenderBox;
                        final RenderBox overlay = Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
                        _showLayoutMenu(buttonContext, button, overlay);
                      },
                      tooltip: '导图布局切换',
                    );
                  },
                ),
                // 10. 添加节点笔记
                _buildButton(
                  icon: Icons.note_add_outlined,
                  onPressed: onAddNote,
                  tooltip: '添加节点笔记',
                ),
                _buildDivider(),
                // 11. 锁定编辑
                _buildButton(
                  icon: controller.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
                  isActive: controller.isLocked,
                  onPressed: controller.toggleLock,
                  tooltip: controller.isLocked ? '已锁定编辑' : '锁定编辑',
                  isDanger: controller.isLocked,
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
    bool isDanger = false,
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
            color: isDanger
                ? const Color(0xFFE05858)
                : isActive
                    ? const Color(0xFFE8A83C)
                    : const Color(0xB3FFF8E6),
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
