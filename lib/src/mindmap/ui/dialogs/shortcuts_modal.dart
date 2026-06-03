// lib/src/mindmap/ui/dialogs/shortcuts_modal.dart
//
// 快捷键弹窗。
//
// 显示所有快捷键列表，支持重置和自定义。

import 'dart:ui';
import 'package:flutter/material.dart';

/// 快捷键弹窗。
class ShortcutsModal extends StatelessWidget {
  final VoidCallback? onClose;
  final VoidCallback? onReset;

  const ShortcutsModal({
    super.key,
    this.onClose,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
          child: Container(
            width: 520,
            height: 600,
            decoration: BoxDecoration(
              color: const Color(0xF51E1A16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1AFFDC8C), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.75),
                  blurRadius: 64,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: Column(
              children: [
                // Header
                _buildHeader(context),
                // Content
                Expanded(
                  child: _buildContent(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0x14FFDC8C), width: 1),
        ),
      ),
      child: Row(
        children: [
          // 取消按钮
          GestureDetector(
            onTap: onClose,
            child: const Text(
              '取消',
              style: TextStyle(
                color: Color(0xFF5CB8FC),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Spacer(),
          // 标题
          const Text(
            '快捷键',
            style: TextStyle(
              color: Color(0xE6FFF8E6),
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // 重置 + 保存
          Row(
            children: [
              GestureDetector(
                onTap: onReset,
                child: const Text(
                  '重置',
                  style: TextStyle(
                    color: Color(0xFFE05858),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: onClose,
                child: const Text(
                  '保存',
                  style: TextStyle(
                    color: Color(0xB3FFF8E6),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 全局快捷键
          const Text(
            '全局 (任意文档下可用)',
            style: TextStyle(
              color: Color(0xFFE8A83C),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ..._globalShortcuts.map((item) => _ShortcutItem(item: item)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              // TODO: 编辑全局快捷键
            },
            child: const Text(
              '编辑全局快捷键',
              style: TextStyle(
                color: Color(0xFF5CB8FC),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 结构与节点
          const Text(
            '结构与节点',
            style: TextStyle(
              color: Color(0xFFE8A83C),
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ..._nodeShortcuts.map((item) => _ShortcutItem(item: item)),
        ],
      ),
    );
  }

  static const _globalShortcuts = [
    _ShortcutItemData(label: '分屏模式', keys: 'Ctrl + Alt + S'),
    _ShortcutItemData(label: '折叠/恢复左侧标签页', keys: 'Ctrl + Alt + ['),
    _ShortcutItemData(label: '折叠/恢复右侧标签页', keys: 'Ctrl + Alt + ]'),
    _ShortcutItemData(label: '交换左右标签页', keys: 'Ctrl + Alt + \\'),
    _ShortcutItemData(label: '切换焦点到对侧标签页', keys: 'Alt + Q'),
    _ShortcutItemData(label: '关闭标签页', keys: 'Ctrl + W'),
    _ShortcutItemData(label: '窗口截图', keys: 'Ctrl + Shift + E'),
  ];

  static const _nodeShortcuts = [
    _ShortcutItemData(label: '添加子节点', keys: 'Tab'),
    _ShortcutItemData(label: '添加同级节点', keys: 'Enter'),
    _ShortcutItemData(label: '折叠/展开分支', keys: 'Space'),
    _ShortcutItemData(label: '编辑选中节点', keys: 'F2'),
    _ShortcutItemData(label: '删除选中节点', keys: 'Delete'),
  ];
}

class _ShortcutItemData {
  final String label;
  final String keys;

  const _ShortcutItemData({required this.label, required this.keys});
}

class _ShortcutItem extends StatelessWidget {
  final _ShortcutItemData item;

  const _ShortcutItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0x05FFF8E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x08FFF8E6), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            item.label,
            style: const TextStyle(
              color: Color(0xB3FFF8E6),
              fontSize: 12.5,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0x0DFFF8E6),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0x14FFDC8C), width: 1),
            ),
            child: Text(
              item.keys,
              style: const TextStyle(
                color: Color(0xE6FFF8E6),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 显示快捷键弹窗
Future<void> showShortcutsModal(BuildContext context) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'shortcuts_modal',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, anim1, anim2) {
      return GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Material(
          color: Colors.transparent,
          child: FadeTransition(
            opacity: anim1,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.94, end: 1.0).animate(
                CurvedAnimation(parent: anim1, curve: Curves.easeOut),
              ),
              child: ShortcutsModal(
                onClose: () => Navigator.of(context).pop(),
                onReset: () {
                  // TODO: 重置快捷键
                  Navigator.of(context).pop();
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
