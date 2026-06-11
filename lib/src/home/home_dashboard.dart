import 'package:flutter/material.dart';
import 'package:starmind/src/domain/document.dart';
import 'package:starmind/src/domain/folder.dart';
import 'package:starmind/src/domain/tag.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/ffi_mindmap_repository.dart';
import 'package:starmind/src/home/widgets/context_menu_item.dart';
import 'package:starmind/src/home/dialogs/glass_dialogs.dart';
import 'package:starmind/src/home/dialogs/import_dialogs.dart'
    show showImportPdfDialog;
import 'package:starmind/src/home/sidebar_widget.dart'
    show showCreateMenu, showCreateMindMapDialog;

/// The main dashboard widget that displays a grid of documents and mind maps.
///
/// This widget provides filtering, sorting, and navigation capabilities
/// for the user's content library. It shows PDFs, mind maps, and notes
/// in a unified grid view with category tabs.
class HomeDashboard extends StatefulWidget {
  /// The workspace controller managing application state.
  final WorkspaceController controller;

  /// The current navigation type ('all', 'folder', 'tag', 'unclassified', etc.).
  final String activeNavType;

  /// Creates a [HomeDashboard] widget.
  ///
  /// Both [controller] and [activeNavType] are required.
  const HomeDashboard({
    super.key,
    required this.controller,
    required this.activeNavType,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchVisible = false;
  String _activeGridFilter = '全部'; // '全部', '笔记', 'PDF', '思维导图'
  List<Topic> _topics = [];
  bool _isLoadingTopics = false;

  @override
  void initState() {
    super.initState();
    _loadTopics();
  }

  @override
  void didUpdateWidget(HomeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeNavType != widget.activeNavType) {
      _loadTopics();
    }
  }

  Future<void> _loadTopics() async {
    if (_isLoadingTopics) return;
    setState(() => _isLoadingTopics = true);
    try {
      final service = MindMapService(FfiMindMapRepository());
      final topics = await service.getAllTopics();
      if (mounted) {
        setState(() {
          _topics = topics;
          _isLoadingTopics = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingTopics = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortContextMenu(BuildContext context, Offset globalPosition) {
    showGlassContextMenu(
      context: context,
      tapPosition: globalPosition,
      items: [
        ContextMenuItem(
          title: '按修改时间',
          icon: Icons.access_time_rounded,
          onTap: () {
            widget.controller.setSortBy('modified');
          },
        ),
        ContextMenuItem(
          title: '按标题名称',
          icon: Icons.title_rounded,
          onTap: () {
            widget.controller.setSortBy('name');
          },
        ),
        ContextMenuItem(
          title: '按创建时间',
          icon: Icons.calendar_today_rounded,
          onTap: () {
            widget.controller.setSortBy('created');
          },
        ),
      ],
    );
  }

  String _getHeaderTitle() {
    final navType = widget.activeNavType;
    final ctrl = widget.controller;

    if (navType == 'all') return '全部笔记';
    if (navType == 'unclassified') return '未分类';
    if (navType == 'untagged') return '未标签';
    if (navType == 'trash') return '回收站';

    if (navType == 'folder' && ctrl.activeFolderFilter != null) {
      final name = _findFolderName(ctrl.folderTree, ctrl.activeFolderFilter!);
      return name ?? '文件夹';
    }

    if (navType == 'tag' && ctrl.activeTagFilter != null) {
      final name = _findTagName(ctrl.tagTree, ctrl.activeTagFilter!);
      return name ?? '标签';
    }

    return '主页';
  }

  String? _findFolderName(Folder? root, String id) {
    if (root == null) return null;
    if (root.id == id) return root.name;
    for (final child in root.children) {
      final name = _findFolderName(child, id);
      if (name != null) return name;
    }
    return null;
  }

  String? _findTagName(Tag? root, String id) {
    if (root == null) return null;
    if (root.id == id) return root.name;
    for (final child in root.children) {
      final name = _findTagName(child, id);
      if (name != null) return name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.controller.isDarkMode;
    final docs = widget.controller.documents;

    // Filter items locally based on selector
    final displayDocs = docs.where((doc) {
      if (_activeGridFilter == '笔记') return false;
      if (_activeGridFilter == 'PDF') return true;
      if (_activeGridFilter == '思维导图') return false;
      return true; // '全部'
    }).toList();

    final List<dynamic> mergedList = [];
    if (_activeGridFilter == '全部') {
      mergedList.addAll(displayDocs);
      mergedList.addAll(_topics);
    } else if (_activeGridFilter == 'PDF') {
      mergedList.addAll(displayDocs);
    } else if (_activeGridFilter == '思维导图') {
      mergedList.addAll(_topics);
    }

    return Column(
      children: [
        // ── CONTENT HEADER ──
        AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.fastOutSlowIn,
          height: 52,
          padding: EdgeInsets.only(
            left: widget.controller.sidebarOpen ? 20.0 : 96.0,
            right: 20.0,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1F0C0A07) : const Color(0x0FFFFFFF),
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0x0CFFDC8C) : Colors.black12,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(
                _getHeaderTitle(),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              if (_isSearchVisible)
                Container(
                  width: 180,
                  height: 30,
                  margin: const EdgeInsets.only(right: 8),
                  child: TextField(
                    controller: _searchController,
                    style: const TextStyle(fontSize: 12),
                    decoration: InputDecoration(
                      hintText: '搜索文档...',
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 10,
                      ),
                      filled: true,
                      fillColor: isDark ? Colors.black26 : Colors.black12,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          widget.controller.setSearchQuery('');
                          setState(() {
                            _isSearchVisible = false;
                          });
                        },
                        child: const Icon(Icons.close_rounded, size: 14),
                      ),
                    ),
                    onChanged: (val) {
                      widget.controller.setSearchQuery(val.trim());
                    },
                  ),
                ),
              _buildHeaderActionButton(
                icon: Icons.search_rounded,
                tooltip: '搜索',
                onTap: () {
                  setState(() {
                    _isSearchVisible = !_isSearchVisible;
                  });
                },
                isActive: _isSearchVisible,
                isDark: isDark,
              ),
              const SizedBox(width: 6),
              _buildHeaderActionButton(
                icon: Icons.sort_rounded,
                tooltip: '排序',
                onTapDown: (details) =>
                    _showSortContextMenu(context, details.globalPosition),
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              Builder(
                builder: (btnContext) {
                  return ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFC800),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                      fixedSize: const Size.fromHeight(32),
                      elevation: 6,
                      shadowColor: const Color(0x33FFC800),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text(
                      '新建/导入',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: () => showCreateMenu(
                      btnContext,
                      widget.controller,
                      onMindMapImported: _loadTopics,
                    ),
                  );
                },
              ),
            ],
          ),
        ),

        // ── FILTER BAR ──
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isDark ? const Color(0x0CFFDC8C) : Colors.black12,
              ),
            ),
          ),
          child: Row(
            children: ['全部', '笔记', 'PDF', '思维导图'].map((filter) {
              final isActive = _activeGridFilter == filter;

              return GestureDetector(
                onTap: () {
                  setState(() => _activeGridFilter = filter);
                  _loadTopics();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isActive
                            ? const Color(0xFFFFC800)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isActive
                          ? const Color(0xFFFFC800)
                          : (isDark ? Colors.white60 : Colors.black54),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // ── GRID AREA ──
        Expanded(
          child: mergedList.isEmpty && widget.activeNavType == 'trash'
              ? const Center(
                  child: Text('回收站为空', style: TextStyle(color: Colors.white24)),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 3 / 4.4,
                  ),
                  itemCount: mergedList.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == 0) {
                      if (_activeGridFilter == '思维导图') {
                        return _buildCreateMindMapDashedCard(isDark);
                      } else {
                        return _buildImportDashedCard(isDark);
                      }
                    }

                    final item = mergedList[idx - 1];
                    if (item is Document) {
                      return _buildDocumentCard(context, item, isDark);
                    } else {
                      return _buildTopicGridCard(
                        context,
                        item as Topic,
                        isDark,
                      );
                    }
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHeaderActionButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onTap,
    void Function(TapDownDetails)? onTapDown,
    bool isActive = false,
    required bool isDark,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        onTapDown: onTapDown,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? const Color(0x33FFC800) : const Color(0x1AFFDC8C))
                : (isDark ? Colors.white10 : Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 15,
            color: isActive
                ? const Color(0xFFFFC800)
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildImportDashedCard(bool isDark) {
    return GestureDetector(
      onTap: () => showImportPdfDialog(context, widget.controller),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0x4DC8841A),
            style: BorderStyle.solid,
            width: 1.5,
          ),
          color: isDark ? const Color(0x0CFFC800) : const Color(0x05FFC800),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x77FFC800), width: 1.5),
              ),
              child: const Icon(Icons.add, color: Color(0xFFFFC800), size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              '导入文件',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateMindMapDashedCard(bool isDark) {
    return GestureDetector(
      onTap: () => showCreateMindMapDialog(widget.controller),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0x33FFDC8C) : const Color(0x331862C6),
            style: BorderStyle.solid,
            width: 1.5,
          ),
          color: isDark ? const Color(0x0C1862C6) : const Color(0x051862C6),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x7760A0E0), width: 1.5),
              ),
              child: const Icon(Icons.add, color: Color(0xFF60A0E0), size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              '新建思维导图',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? Colors.white60 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopicGridCard(BuildContext context, Topic topic, bool isDark) {
    final colors = [const Color(0xFF1862C6), const Color(0xFF60A0E0)];
    final date = topic.updatedAt;
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    return GestureDetector(
      onDoubleTap: () => widget.controller.openMindMap(topic.id, topic.title),
      onSecondaryTapDown: (details) {
        _showTopicCardContextMenu(context, details.globalPosition, topic);
      },
      onLongPressStart: (details) {
        _showTopicCardContextMenu(context, details.globalPosition, topic);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0x1F1862C6),
          ),
          color: isDark ? Colors.white10 : Colors.white,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover (3:4 aspect)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // MINDMAP Label tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '脑图',
                            style: TextStyle(
                              fontSize: 8,
                              color: Color(0xFF60A0E0),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Topic Title
                        Text(
                          topic.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Icon(
                          Icons.account_tree_rounded,
                          color: Colors.white30,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Meta info
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 9,
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTopicCardContextMenu(
    BuildContext context,
    Offset position,
    Topic topic,
  ) {
    showGlassContextMenu(
      context: context,
      tapPosition: position,
      items: [
        ContextMenuItem(
          title: '打开脑图',
          icon: Icons.open_in_new_rounded,
          onTap: () => widget.controller.openMindMap(topic.id, topic.title),
        ),
        ContextMenuItem(
          title: '彻底删除',
          icon: Icons.delete_sweep_rounded,
          isDanger: true,
          onTap: () async {
            final service = MindMapService(FfiMindMapRepository());
            await service.trashTopic(topic.id);
            _loadTopics();
          },
        ),
      ],
    );
  }

  // Cover background gradient presets
  static const List<List<Color>> _coverGradients = [
    [Color(0xFF1A3A2A), Color(0xFF0E2018)], // c1
    [Color(0xFF2A1A0E), Color(0xFF1A0E05)], // c2
    [Color(0xFF0E1A2A), Color(0xFF05101A)], // c3
    [Color(0xFF2A1A2A), Color(0xFF150D15)], // c4
    [Color(0xFF1A2A1A), Color(0xFF0E180E)], // c5
    [Color(0xFF2A200E), Color(0xFF1A1408)], // c6
    [Color(0xFF1E1018), Color(0xFF120A10)], // c7
    [Color(0xFF0E1E2A), Color(0xFF081218)], // c8
  ];

  List<Color> _getCoverGradient(String id) {
    final hash = id.hashCode.abs();
    return _coverGradients[hash % _coverGradients.length];
  }

  Widget _buildDocumentCard(BuildContext context, Document doc, bool isDark) {
    final colors = _getCoverGradient(doc.id);
    // Parse timestamp to YYYY/MM/DD
    final date = doc.createdAt;
    final dateStr =
        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

    return GestureDetector(
      onDoubleTap: () => widget.controller.openDocument(doc),
      onSecondaryTapDown: (details) {
        _showCardContextMenu(context, details.globalPosition, doc);
      },
      onLongPressStart: (details) {
        _showCardContextMenu(context, details.globalPosition, doc);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0x1F805C00),
          ),
          color: isDark ? Colors.white10 : Colors.white,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover (3:4 aspect)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: colors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // PDF Label tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PDF',
                            style: TextStyle(
                              fontSize: 8,
                              color: Color(0xFFFFC800),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Document Title
                        Text(
                          doc.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white.withValues(alpha: 0.9),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Cover structural lines placeholder
                        Container(
                          height: 2,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Container(
                          height: 2,
                          width: 50,
                          decoration: BoxDecoration(
                            color: Colors.white12,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Meta info
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isDark ? Colors.white30 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCardContextMenu(
    BuildContext context,
    Offset position,
    Document doc,
  ) {
    showGlassContextMenu(
      context: context,
      tapPosition: position,
      items: [
        ContextMenuItem(
          title: '打开文档',
          icon: Icons.open_in_new_rounded,
          onTap: () => widget.controller.openDocument(doc),
        ),
        ContextMenuItem(
          title: '绑定标签',
          icon: Icons.sell_rounded,
          onTap: () => _showBindTagDialog(context, doc),
        ),
        ContextMenuItem(
          title: '彻底删除',
          icon: Icons.delete_sweep_rounded,
          isDanger: true,
          onTap: () => widget.controller.deleteDoc(doc.id),
        ),
      ],
    );
  }

  void _showBindTagDialog(BuildContext context, Document doc) {
    final isDark = widget.controller.isDarkMode;
    final tagTree = widget.controller.tagTree;
    if (tagTree == null) return;

    // Collect all tags flatly
    final List<Tag> allTags = [];
    void collect(Tag node) {
      if (node.id != 'root') {
        allTags.add(node);
      }
      for (final kid in node.children) {
        collect(kid);
      }
    }

    collect(tagTree);

    showGlassDialog(
      context: context,
      child: Card(
        color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: Color(0x33FFDC8C)),
        ),
        child: Container(
          width: 340,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '绑定标签',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              if (allTags.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    '暂无标签，请先在侧边栏创建。',
                    style: TextStyle(color: Colors.white30, fontSize: 13),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: allTags.length,
                    itemBuilder: (context, idx) {
                      final tag = allTags[idx];
                      final hasTag = doc.tagIds.contains(tag.id);

                      return CheckboxListTile(
                        title: Text(
                          tag.name,
                          style: const TextStyle(fontSize: 13),
                        ),
                        value: hasTag,
                        activeColor: const Color(0xFFFFC800),
                        onChanged: (val) {
                          if (val == true) {
                            widget.controller.bindTag(doc.id, tag.id);
                          } else {
                            widget.controller.unbindTag(doc.id, tag.id);
                          }
                          Navigator.pop(context); // Close and refresh
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 12),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
