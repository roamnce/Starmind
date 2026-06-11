import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:starmind/main.dart' show navigatorKey;
import 'package:starmind/src/domain/folder.dart';
import 'package:starmind/src/domain/tag.dart';
import 'package:starmind/src/home/dialogs/glass_dialogs.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/home/workspace_controller_provider.dart';
import 'package:starmind/src/home/widgets/context_menu_item.dart';
import 'package:starmind/src/home/widgets/glass_toggle.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/ffi_mindmap_repository.dart';

/// Sidebar widget displaying folder and tag navigation tree.
class SidebarWidget extends StatelessWidget {
  final WorkspaceController controller;
  final Set<String> expandedFolderIds;
  final Set<String> expandedTagIds;
  final String activeNavType;
  final void Function(String type, String id) onSelectNav;

  const SidebarWidget({
    super.key,
    required this.controller,
    required this.expandedFolderIds,
    required this.expandedTagIds,
    required this.activeNavType,
    required this.onSelectNav,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = controller.isDarkMode;
    final totalNotesCount =
        controller.documents.length; // Placeholder or calculate
    final folderTree = controller.folderTree;
    final tagTree = controller.tagTree;

    // Root folder document count represents Unclassified docs
    final unclassifiedCount = folderTree?.documentCount ?? 0;
    // Root tag count represents Untagged docs
    final untaggedCount = tagTree?.documentCount ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0x99141008) : const Color(0xDDFEFAF5),
        border: Border(
          right: BorderSide(
            color: isDark ? const Color(0x1AFFDC8C) : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 52), // Float control spacing
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              children: [
                // 全部笔记
                _buildSidebarItem(
                  isActive: activeNavType == 'all',
                  icon: Icons.notes_rounded,
                  iconColor: const Color(0xFFFFC800),
                  label: '全部笔记',
                  count: totalNotesCount,
                  onTap: () => onSelectNav('all', ''),
                ),

                // 未分类 / 未标签
                if (activeNavType == 'all' ||
                    activeNavType == 'unclassified' ||
                    activeNavType == 'untagged') ...[
                  _buildSidebarItem(
                    isActive: activeNavType == 'unclassified',
                    icon: Icons.folder_open_rounded,
                    label: '未分类',
                    count: unclassifiedCount,
                    indent: 16,
                    onTap: () => onSelectNav('unclassified', ''),
                  ),
                  _buildSidebarItem(
                    isActive: activeNavType == 'untagged',
                    icon: Icons.tag_rounded,
                    label: '未标签',
                    count: untaggedCount,
                    indent: 16,
                    onTap: () => onSelectNav('untagged', ''),
                  ),
                ],

                // 回收站
                _buildSidebarItem(
                  isActive: activeNavType == 'trash',
                  icon: Icons.delete_outline_rounded,
                  iconColor: const Color(0xFFE05858),
                  label: '回收站',
                  count: 0,
                  onTap: () => onSelectNav('trash', ''),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(color: Color(0x12FFDC8C), height: 1),
                ),

                // ── FOLDERS TREE GROUP ──
                _buildSectionHeader(
                  title: '文件夹',
                  icon: Icons.folder_rounded,
                  iconColor: const Color(0xFFE8A040),
                  onAdd: () => showCreateFolderDialog(context, null),
                ),
                if (folderTree != null)
                  ...folderTree.children.map(
                    (child) => _buildFolderNode(context, child, 0),
                  ),

                const SizedBox(height: 16),

                // ── TAGS TREE GROUP ──
                _buildSectionHeader(
                  title: '标签',
                  icon: Icons.sell_rounded,
                  iconColor: const Color(0xFFE06080),
                  onAdd: () => showCreateTagDialog(context, null),
                ),
                if (tagTree != null)
                  ...tagTree.children.map(
                    (child) => _buildTagNode(context, child, 0),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onAdd,
  }) {
    final isDark = controller.isDarkMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xCCFFF8E6) : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x55FFC800), width: 1.5),
              ),
              child: const Center(
                child: Icon(Icons.add, size: 10, color: Color(0xFFFFC800)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarItem({
    required bool isActive,
    required IconData icon,
    Color? iconColor,
    required String label,
    required int count,
    double indent = 0,
    required VoidCallback onTap,
  }) {
    final isDark = controller.isDarkMode;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: indent, top: 2, bottom: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? const Color(0x33C8841A) : const Color(0x2BFFC800))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isActive
                  ? (isDark ? const Color(0xFFFFC800) : const Color(0xFF805C00))
                  : (iconColor ?? (isDark ? Colors.white60 : Colors.black)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  color: isActive
                      ? (isDark
                            ? const Color(0xFFFFF8E6)
                            : const Color(0xFF805C00))
                      : (isDark ? Colors.white70 : Colors.black),
                ),
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0x1AFFDC8C) : Colors.black12,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0x99FFF8E6) : Colors.black87,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── FOLDER TREE NODE RENDERING ──

  Widget _buildFolderNode(BuildContext context, Folder node, int depth) {
    final isExpanded = expandedFolderIds.contains(node.id);
    final isSelected =
        activeNavType == 'folder' && controller.activeFolderFilter == node.id;
    final isDark = controller.isDarkMode;

    return Column(
      children: [
        GestureDetector(
          onTap: () => onSelectNav('folder', node.id),
          onSecondaryTapDown: (details) {
            _showFolderContextMenu(context, details.globalPosition, node);
          },
          onLongPressStart: (details) {
            _showFolderContextMenu(context, details.globalPosition, node);
          },
          child: Container(
            margin: EdgeInsets.only(
              left: (depth * 10).toDouble(),
              top: 1,
              bottom: 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0x33C8841A) : const Color(0x2BFFC800))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (isExpanded) {
                      expandedFolderIds.remove(node.id);
                    } else {
                      expandedFolderIds.add(node.id);
                    }
                    onSelectNav('folder', node.id);
                  },
                  child: Icon(
                    node.children.isNotEmpty
                        ? (isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded)
                        : Icons.fiber_manual_record,
                    size: node.children.isNotEmpty ? 14 : 6,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.folder_open_rounded,
                  size: 14,
                  color: isSelected
                      ? const Color(0xFFFFC800)
                      : (isDark
                            ? const Color(0xFFE8A040)
                            : const Color(0xFFB37424)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? (isDark
                                ? const Color(0xFFFFF8E6)
                                : const Color(0xFF805C00))
                          : (isDark ? Colors.white70 : Colors.black),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  node.documentCount.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0x66FFF8E6) : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && node.children.isNotEmpty)
          ...node.children.map(
            (child) => _buildFolderNode(context, child, depth + 1),
          ),
      ],
    );
  }

  void _showFolderContextMenu(
    BuildContext context,
    Offset position,
    Folder node,
  ) {
    showGlassContextMenu(
      context: context,
      tapPosition: position,
      items: [
        ContextMenuItem(
          title: '新建子文件夹',
          icon: Icons.create_new_folder_rounded,
          onTap: () => showCreateFolderDialog(context, node.id),
        ),
        ContextMenuItem(
          title: '重命名',
          icon: Icons.edit_rounded,
          onTap: () => showRenameFolderDialog(context, node),
        ),
        ContextMenuItem(
          title: '删除文件夹',
          icon: Icons.delete_forever_rounded,
          isDanger: true,
          onTap: () => showDeleteFolderConfirm(context, node),
        ),
      ],
    );
  }

  // ── TAG TREE NODE RENDERING ──

  Widget _buildTagNode(BuildContext context, Tag node, int depth) {
    final isExpanded = expandedTagIds.contains(node.id);
    final isSelected =
        activeNavType == 'tag' && controller.activeTagFilter == node.id;
    final isDark = controller.isDarkMode;

    final dotColor = node.color ?? const Color(0xFFFFC800);

    return Column(
      children: [
        GestureDetector(
          onTap: () => onSelectNav('tag', node.id),
          onSecondaryTapDown: (details) {
            _showTagContextMenu(context, details.globalPosition, node);
          },
          onLongPressStart: (details) {
            _showTagContextMenu(context, details.globalPosition, node);
          },
          child: Container(
            margin: EdgeInsets.only(
              left: (depth * 10).toDouble(),
              top: 1,
              bottom: 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isSelected
                  ? (isDark ? const Color(0x33C8841A) : const Color(0x2BFFC800))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (isExpanded) {
                      expandedTagIds.remove(node.id);
                    } else {
                      expandedTagIds.add(node.id);
                    }
                    onSelectNav('tag', node.id);
                  },
                  child: Icon(
                    node.children.isNotEmpty
                        ? (isExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_right_rounded)
                        : Icons.fiber_manual_record,
                    size: node.children.isNotEmpty ? 14 : 6,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? (isDark
                                ? const Color(0xFFFFF8E6)
                                : const Color(0xFF805C00))
                          : (isDark ? Colors.white70 : Colors.black),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  node.documentCount.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? const Color(0x66FFF8E6) : Colors.black38,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && node.children.isNotEmpty)
          ...node.children.map(
            (child) => _buildTagNode(context, child, depth + 1),
          ),
      ],
    );
  }

  void _showTagContextMenu(BuildContext context, Offset position, Tag node) {
    showGlassContextMenu(
      context: context,
      tapPosition: position,
      items: [
        ContextMenuItem(
          title: '新建子标签',
          icon: Icons.sell_rounded,
          onTap: () => showCreateTagDialog(context, node.id),
        ),
        ContextMenuItem(
          title: '重命名',
          icon: Icons.edit_rounded,
          onTap: () => showRenameTagDialog(context, node),
        ),
        ContextMenuItem(
          title: '删除标签',
          icon: Icons.delete_forever_rounded,
          isDanger: true,
          onTap: () => controller.deleteTag(node.id),
        ),
      ],
    );
  }
}

// ── CREATE / RENAME METADATA DIALOGS ──

void showCreateFolderDialog(BuildContext context, String? parentId) {
  final controller = TextEditingController();
  final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;

  showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x33FFDC8C)),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.create_new_folder_rounded,
                  color: Color(0xFFFFC800),
                ),
                const SizedBox(width: 10),
                Text(
                  parentId == null ? '新建文件夹' : '新建子文件夹',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '文件夹名称',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.black12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  context.workspaceController.createFolder(name, parentId);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC800),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      context.workspaceController.createFolder(name, parentId);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void showRenameFolderDialog(BuildContext context, Folder node) {
  final controller = TextEditingController(text: node.name);
  final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;

  showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x33FFDC8C)),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_rounded, color: Color(0xFFFFC800)),
                const SizedBox(width: 10),
                Text(
                  '重命名文件夹',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.black12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  context.workspaceController.renameFolder(node.id, name);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC800),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      context.workspaceController.renameFolder(node.id, name);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void showDeleteFolderConfirm(BuildContext context, Folder node) {
  final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;

  showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x33FFDC8C)),
      ),
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE05858),
                ),
                const SizedBox(width: 10),
                Text(
                  '删除文件夹',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '您确定要删除文件夹 "${node.name}" 吗？\n请选择如何处理该文件夹内的文档：',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black87,
                fontSize: 13.5,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white10 : Colors.black12,
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                  ),
                  onPressed: () {
                    context.workspaceController.deleteFolder(node.id, false);
                    Navigator.pop(context);
                  },
                  child: const Text('保留文档(设为未分类)'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE05858),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    context.workspaceController.deleteFolder(node.id, true);
                    Navigator.pop(context);
                  },
                  child: const Text('级联删除文档'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void showCreateTagDialog(BuildContext context, String? parentId) {
  final controller = TextEditingController();
  final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;

  final colorOptions = [
    '#5CB8FC', // Blue
    '#E8708A', // Pink
    '#5CE8A0', // Green
    '#E8C060', // Amber
    '#E05858', // Red
  ];
  String selectedColor = colorOptions[0];

  showGlassDialog(
    context: context,
    child: StatefulBuilder(
      builder: (context, setModalState) {
        return Card(
          color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0x33FFDC8C)),
          ),
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.sell_rounded, color: Color(0xFFFFC800)),
                    const SizedBox(width: 10),
                    Text(
                      parentId == null ? '新建标签' : '新建子标签',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: '标签名称',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: true,
                    fillColor: isDark ? Colors.black26 : Colors.black12,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '选择标签色彩',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: colorOptions.map((colorHex) {
                    final colorVal = Color(
                      int.parse(colorHex.replaceFirst('#', '0xFF')),
                    );
                    final isSelected = selectedColor == colorHex;

                    return GestureDetector(
                      onTap: () =>
                          setModalState(() => selectedColor = colorHex),
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          color: colorVal,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: colorVal.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        '取消',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC800),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () {
                        final name = controller.text.trim();
                        if (name.isNotEmpty) {
                          context.workspaceController.createTag(
                            name,
                            parentId,
                            selectedColor,
                          );
                          Navigator.pop(context);
                        }
                      },
                      child: const Text('创建'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void showRenameTagDialog(BuildContext context, Tag node) {
  final controller = TextEditingController(text: node.name);
  final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;

  showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x33FFDC8C)),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_rounded, color: Color(0xFFFFC800)),
                const SizedBox(width: 10),
                Text(
                  '重命名标签',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.black12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  context.workspaceController.renameTag(node.id, name);
                  Navigator.pop(context);
                }
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC800),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      context.workspaceController.renameTag(node.id, name);
                      Navigator.pop(context);
                    }
                  },
                  child: const Text('保存'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

// ── CREATE MENU (NEW/IMPORT) ──

void showCreateMenu(
  BuildContext context,
  WorkspaceController controller, {
  VoidCallback? onMindMapImported,
}) {
  final isDark = controller.isDarkMode;

  // Get button position for popup positioning
  final RenderBox? button = context.findRenderObject() as RenderBox?;
  final Offset buttonPosition =
      button?.localToGlobal(Offset.zero) ?? Offset.zero;
  final Size buttonSize = button?.size ?? Size.zero;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'create_menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, anim1, anim2) {
      return Stack(
        children: [
          // Invisible barrier to dismiss
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.translucent,
            ),
          ),
          // Popup menu positioned below button
          Positioned(
            left: buttonPosition.dx - 40,
            top: buttonPosition.dy + buttonSize.height + 8,
            child: FadeTransition(
              opacity: anim1,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xED16110A)
                          : const Color(0xEDFFFBF7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0x33FFDC8C),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          buildMenuItem(
                            context: context,
                            icon: Icons.account_tree_rounded,
                            label: '新建思维导图',
                            color: const Color(0xFF60A0E0),
                            onTap: () {
                              Navigator.pop(context);
                              // Pass controller directly to avoid using deactivated context
                              showCreateMindMapDialog(controller);
                            },
                          ),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: isDark
                                ? const Color(0x22FFDC8C)
                                : const Color(0x22D4C4A8),
                          ),
                          buildMenuItem(
                            context: context,
                            icon: Icons.picture_as_pdf_rounded,
                            label: '导入 PDF',
                            color: const Color(0xFFE86060),
                            onTap: () {
                              Navigator.pop(context);
                              // Note: _showImportPdfDialog needs to be defined elsewhere
                              // or imported from another module
                            },
                          ),
                          Container(
                            height: 1,
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            color: isDark
                                ? const Color(0x22FFDC8C)
                                : const Color(0x22D4C4A8),
                          ),
                          buildMenuItem(
                            context: context,
                            icon: Icons.account_tree_outlined,
                            label: '导入 GuruMind',
                            color: const Color(0xFF60A0E0),
                            onTap: () {
                              Navigator.pop(context);
                              handleGuruMindFileSelection(
                                context,
                                controller,
                                onImported: onMindMapImported,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

Widget buildMenuItem({
  required BuildContext context,
  required IconData icon,
  required String label,
  required Color color,
  required VoidCallback onTap,
}) {
  return InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFFFFF8E6),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

void showCreateMindMapDialog([WorkspaceController? controller]) {
  final textController = TextEditingController();
  final isDark = controller?.isDarkMode ?? true;
  // Use provided controller directly
  final workspaceController = controller;

  if (workspaceController == null) {
    debugPrint('Error: WorkspaceController is null');
    return;
  }

  // We need a context for showDialog, use the root navigator
  // Get context from navigator state
  final context = navigatorKey.currentContext;
  if (context == null) {
    debugPrint('Error: No navigator context available');
    return;
  }

  showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x33FFDC8C)),
      ),
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_tree_rounded,
                  color: Color(0xFF60A0E0),
                ),
                const SizedBox(width: 10),
                Text(
                  '创建思维导图',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            TextField(
              controller: textController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: '输入思维导图标题',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.black12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) {
                // Pop dialog first
                Navigator.pop(context);
                // Create mindmap with captured controller
                createAndOpenMindMap(textController.text, workspaceController);
              },
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '取消',
                    style: TextStyle(
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF60A0E0),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    // Pop dialog first
                    Navigator.pop(context);
                    // Create mindmap with captured controller
                    createAndOpenMindMap(
                      textController.text,
                      workspaceController,
                    );
                  },
                  child: const Text('创建'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> createAndOpenMindMap(
  String title,
  WorkspaceController controller,
) async {
  if (title.trim().isEmpty) return;
  try {
    final service = MindMapService(FfiMindMapRepository());
    final topic = await service.createTopic(title.trim());

    // Create default mindmap structure: root node with 3 child nodes
    // 根节点
    final rootNode = await service.createNote(
      topicId: topic.id,
      title: title.trim(),
      parentId: null,
    );
    await service.addRootNote(topicId: topic.id, noteId: rootNode.id);

    // 三个子节点
    final child1 = await service.createNote(
      topicId: topic.id,
      title: '分支主题1',
      parentId: rootNode.id,
    );
    await service.addChild(parentId: rootNode.id, childId: child1.id);

    final child2 = await service.createNote(
      topicId: topic.id,
      title: '分支主题2',
      parentId: rootNode.id,
    );
    await service.addChild(parentId: rootNode.id, childId: child2.id);

    final child3 = await service.createNote(
      topicId: topic.id,
      title: '分支主题3',
      parentId: rootNode.id,
    );
    await service.addChild(parentId: rootNode.id, childId: child3.id);

    // Open the mindmap tab
    controller.openMindMap(topic.id, topic.title);
  } catch (e) {
    debugPrint('Failed to create mindmap: $e');
  }
}

// ── APP SETTINGS DIALOG ──

Future<void> handleGuruMindFileSelection(
  BuildContext context,
  WorkspaceController workspaceController, {
  VoidCallback? onImported,
}) async {
  final result = await FilePicker.pickFiles(
    dialogTitle: '选择 GuruMind 文件',
    type: FileType.custom,
    allowedExtensions: ['gurumind'],
  );
  final filePath = result?.files.single.path;
  if (filePath == null) return;

  try {
    final service = MindMapService(FfiMindMapRepository());
    final importResult = await service.importGuruMindFile(filePath);
    if (!importResult.isSuccess || importResult.topic == null) {
      throw importResult.error ?? StateError('GuruMind import failed');
    }
    final topic = importResult.topic!;
    onImported?.call();
    workspaceController.openMindMap(topic.id, topic.title);

    final messengerContext = navigatorKey.currentContext ?? context;
    if (messengerContext.mounted) {
      ScaffoldMessenger.of(
        messengerContext,
      ).showSnackBar(SnackBar(content: Text('已导入 GuruMind：${topic.title}')));
    }
  } catch (error) {
    final messengerContext = navigatorKey.currentContext ?? context;
    if (messengerContext.mounted) {
      ScaffoldMessenger.of(
        messengerContext,
      ).showSnackBar(SnackBar(content: Text('GuruMind 导入失败：$error')));
    }
  }
}

void showSettingsDialog(BuildContext context) {
  final controller = context.workspaceController;
  final isDark = controller.isDarkMode;

  showGlassDialog(
    context: context,
    child: StatefulBuilder(
      builder: (context, setModalState) {
        return Card(
          color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: Color(0x33FFDC8C)),
          ),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.settings_rounded,
                      color: Color(0xFFFFC800),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '设置',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                buildSettingsSectionHeader(isDark, '通用'),
                buildSettingsRow(
                  isDark: isDark,
                  label: '自动保存',
                  subLabel: '笔记变更时自动保存到本地',
                  value: controller.autoSave,
                  onChanged: (val) {
                    controller.setAutoSave(val);
                    setModalState(() {});
                  },
                ),
                buildSettingsRow(
                  isDark: isDark,
                  label: '深色模式',
                  subLabel: '使用深色太空美学主题',
                  value: controller.isDarkMode,
                  onChanged: (val) {
                    controller.setDarkMode(val);
                    setModalState(() {});
                  },
                ),
                buildSettingsRow(
                  isDark: isDark,
                  label: '侧边栏默认展开',
                  subLabel: '启动时自动展开左侧导航',
                  value: controller.sidebarOpen,
                  onChanged: (val) {
                    controller.setSidebarOpen(val);
                    setModalState(() {});
                  },
                ),
                buildSettingsRow(
                  isDark: isDark,
                  label: '隐藏系统状态栏',
                  subLabel: '开启后将隐藏安卓系统的状态栏',
                  value: controller.hideSystemStatusBar,
                  onChanged: (val) {
                    controller.setHideSystemStatusBar(val);
                    setModalState(() {});
                  },
                ),
                buildSettingsSectionHeader(isDark, 'PDF 阅读'),
                buildSettingsRow(
                  isDark: isDark,
                  label: '自由平移',
                  subLabel: '允许 PDF 页面在视口内自由移动',
                  value: controller.freePanEnabled,
                  onChanged: (val) {
                    controller.setFreePanEnabled(val);
                    setModalState(() {});
                  },
                ),
                buildSettingsRow(
                  isDark: isDark,
                  label: '防误触',
                  subLabel: '书写时忽略手掌接触屏幕',
                  value: controller.palmRejectionEnabled,
                  onChanged: (val) {
                    controller.setPalmRejectionEnabled(val);
                    setModalState(() {});
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFFC800),
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('保存并返回'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Widget buildSettingsSectionHeader(bool isDark, String title) {
  return Container(
    margin: const EdgeInsets.only(top: 8, bottom: 8),
    padding: const EdgeInsets.only(bottom: 6),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0x11FFDC8C))),
    ),
    child: Text(
      title,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.bold,
        color: isDark ? Colors.white30 : Colors.black38,
        letterSpacing: 1.0,
      ),
    ),
  );
}

Widget buildSettingsRow({
  required bool isDark,
  required String label,
  required String subLabel,
  required bool value,
  required ValueChanged<bool> onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white38 : Colors.black45,
                ),
              ),
            ],
          ),
        ),
        GlassToggle(value: value, onChanged: onChanged),
      ],
    ),
  );
}
