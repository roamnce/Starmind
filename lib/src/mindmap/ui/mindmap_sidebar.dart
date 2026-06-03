// lib/src/mindmap/ui/mindmap_sidebar.dart

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'mindmap_controller.dart';
import '../domain/note.dart';
import 'markdown_editor_toolbar.dart';
import 'panels/node_search_panel.dart';
import 'panels/style_config_panel.dart';

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
        color: Color(0xFF16110A),
        border: Border(
          left: BorderSide(color: Color(0x14FFDC8C), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context),
          const Divider(height: 1, color: Color(0x14FFDC8C)),
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
        icon = Icons.send_rounded;
        title = '节点笔记';
        trailing = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FButton.icon(
              variant: FButtonVariant.ghost,
              size: FButtonSizeVariant.xs,
              style: const FButtonStyleDelta.delta(
                iconContentStyle: FButtonIconContentStyleDelta.delta(
                  constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
                ),
              ),
              onPress: () => controller.navigateSibling('prev'),
              child: const Icon(Icons.chevron_left_rounded, size: 20, color: Colors.white70),
            ),
            const SizedBox(width: 4),
            FButton.icon(
              variant: FButtonVariant.ghost,
              size: FButtonSizeVariant.xs,
              style: const FButtonStyleDelta.delta(
                iconContentStyle: FButtonIconContentStyleDelta.delta(
                  constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: EdgeInsetsGeometryDelta.value(EdgeInsets.zero),
                ),
              ),
              onPress: () => controller.navigateSibling('next'),
              child: const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.white70),
            ),
          ],
        );
      case SidebarTab.search:
        icon = Icons.search_rounded;
        title = '节点搜索';
      case SidebarTab.theme:
        icon = Icons.palette_outlined;
        title = '导图主题';
      case SidebarTab.config:
        icon = Icons.tune_rounded;
        title = '样式配置';
      case SidebarTab.icon:
        icon = Icons.sentiment_satisfied_alt_rounded;
        title = '节点图标';
    }

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Transform.rotate(
            angle: tab == SidebarTab.note ? -0.5 : 0.0,
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
      case SidebarTab.search:
        return NodeSearchPanel(controller: controller);
      case SidebarTab.theme:
        return _buildThemePanel(context);
      case SidebarTab.config:
        return StyleConfigPanel(controller: controller);
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
            child: FTextField(
              control: FTextFieldControl.managed(
                controller: textController,
                onChange: (val) {
                  controller.updateNoteContent(note.id, val.text);
                },
              ),
              focusNode: focusNode,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              hint: '输入笔记内容...',
            ),
          ),
        ],
      ),
    );
  }

  /// 导图主题面板 - 按原型设计，3 个预设主题卡片
  Widget _buildThemePanel(BuildContext context) {
    final themes = [
      {
        'name': '经典深色 (默认)',
        'colors': [const Color(0xFF242930), const Color(0xFFE05858), const Color(0xFF7B61FF)],
        'theme': 'default',
      },
      {
        'name': '赛博朋克',
        'colors': [const Color(0xFF00F0FF), const Color(0xFFFF007F), const Color(0xFF7B00FF)],
        'theme': 'cyber',
      },
      {
        'name': '森林绿意',
        'colors': [const Color(0xFF2E7D32), const Color(0xFF81C784), const Color(0xFF4CAF50)],
        'theme': 'forest',
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '导图主题选择',
            style: TextStyle(
              color: Color(0xB3FFF8E6),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...themes.map((theme) {
            final isActive = false; // TODO: 检查当前主题
            return _ThemeCard(
              name: theme['name'] as String,
              colors: theme['colors'] as List<Color>,
              isActive: isActive,
              onTap: () {
                // TODO: 实现主题切换
              },
            );
          }),
        ],
      ),
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
                      var newTitle = currentTitle;
                      final regex = RegExp(r'^[ -㋿\ud83c-􏰀-\udfff️]+\s*');
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

/// 主题卡片组件
class _ThemeCard extends StatelessWidget {
  final String name;
  final List<Color> colors;
  final bool isActive;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.name,
    required this.colors,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0x05FFF8E6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive ? const Color(0xFFC8841A) : const Color(0x14FFDC8C),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Row(
              children: colors.map((color) {
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: isActive ? const Color(0xE6FFF8E6) : const Color(0xB3FFF8E6),
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
