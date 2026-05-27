/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:starmind/src/rust/frb_generated.dart';
import 'package:starmind/src/domain/document.dart';
import 'package:starmind/src/domain/folder.dart';
import 'package:starmind/src/domain/tag.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/home/workspace_controller_provider.dart';
import 'package:starmind/src/home/tab_layout.dart';
import 'package:starmind/src/domain/ffi_storage_repository.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';
import 'package:starmind/src/pdf/widgets/pdf_viewport_widget.dart';
import 'package:starmind/src/pdf/widgets/text_selection_overlay.dart';
import 'package:starmind/src/pdf/widgets/ink_toolbar.dart';
import 'package:starmind/src/pdf/widgets/pdf_annotation_integration.dart';
import 'package:starmind/src/pdf/widgets/interactive_canvas_viewer.dart';
import 'package:starmind/src/pdf/annotation_controller.dart';
import 'package:starmind/src/pdf/widgets/annotation_sidebar_panel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize the Rust library (PDFium will be initialized by Rust's pdfium-render, not pdfrx)
  await RustLib.init();

  // Initialize workspace controller with explicit dependency injection
  final workspaceController = WorkspaceController(FfiStorageRepository());
  await workspaceController.init();

  runApp(WorkspaceControllerProvider(
    controller: workspaceController,
    child: const MyApp(),
  ));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: context.workspaceController,
      builder: (context, _) {
        final controller = context.workspaceController;
        final isDark = controller.isDarkMode;

        return MaterialApp(
          title: 'StarMind',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFFFC800), // Vibrant saber gold
              brightness: isDark ? Brightness.dark : Brightness.light,
              background: isDark ? const Color(0xFF0C0A07) : const Color(0xFFFAF9F6),
              surface: isDark ? const Color(0xFF141008) : const Color(0xFFF0EDE5),
            ),
            useMaterial3: true,
            fontFamily: 'AtkinsonHyperlegibleNext',
          ),
          home: const WorkspacePage(),
        );
      },
    );
  }
}

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final WorkspaceController _workspaceController;

  // Cache of PDF controllers mapped by docId
  final Map<String, PdfViewportController> _pdfControllers = {};

  // Track expanded folder and tag nodes
  final Set<String> _expandedFolderIds = {'root'};
  final Set<String> _expandedTagIds = {'root'};

  // Track active sidebar selection type ('all', 'unclassified', 'trash', 'folder', 'tag')
  String _activeNavType = 'all';

  @override
  void initState() {
    super.initState();
    _workspaceController = context.workspaceController;
    _workspaceController.addListener(_onWorkspaceChanged);
  }

  @override
  void dispose() {
    _workspaceController.removeListener(_onWorkspaceChanged);
    for (final ctrl in _pdfControllers.values) {
      ctrl.closeDoc();
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onWorkspaceChanged() {
    _syncPdfControllers();
    if (mounted) {
      setState(() {});
    }
  }

  /// Syncs cached PDF controllers with active workspace tabs.
  void _syncPdfControllers() {
    final root = _workspaceController.rootLayoutNode;
    if (root is! LeafNode) return;

    final activePdfIds = root.tabs
        .where((t) => t.type == TabType.pdf)
        .map((t) => t.id)
        .toSet();

    // Dispose controllers for closed tabs
    final closedIds = _pdfControllers.keys.where((id) => !activePdfIds.contains(id)).toList();
    for (final id in closedIds) {
      final ctrl = _pdfControllers.remove(id);
      ctrl?.closeDoc();
      ctrl?.dispose();
    }
  }

  /// Gets or creates a PdfViewportController for a tab.
  PdfViewportController _getOrBuildController(String docId, String filePath) {
    if (!_pdfControllers.containsKey(docId)) {
      final ctrl = PdfViewportController();
      ctrl.loadDoc(filePath);
      _pdfControllers[docId] = ctrl;
    }
    return _pdfControllers[docId]!;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _workspaceController.isDarkMode;
    final leaf = _workspaceController.rootLayoutNode as LeafNode;
    final activeIndex = leaf.activeIndex;
    final activeTab = leaf.tabs[activeIndex];
    final sidebarOpen = _workspaceController.sidebarOpen;

    // ── SYSTEM STATUS BAR CONTROL ──
    final shouldHideStatusBar = _workspaceController.hideSystemStatusBar ||
        (activeTab.type == TabType.pdf && _workspaceController.isImmersiveMode);

    if (shouldHideStatusBar) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    final shouldShowTabBar = !(activeTab.type == TabType.pdf && _workspaceController.isImmersiveMode);
    final showSidebar = sidebarOpen && activeTab.type == TabType.home;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0C0A07) : const Color(0xFFFAF8F5),
      body: SafeArea(
        top: !shouldHideStatusBar,
        bottom: false,
        left: false,
        right: false,
        child: Stack(
          children: [
            // Orb glow backgrounds (for Dark Mode only)
            OrbBackground(isDark: isDark),
  
            Column(
              children: [
                // ── TOP TAB BAR ──
                if (shouldShowTabBar)
                  TabBarWidget(
                    tabs: leaf.tabs,
                    activeIndex: activeIndex,
                    onSelect: (idx) => _workspaceController.selectTab(idx),
                    onClose: (idx) {
                      final tabToClose = leaf.tabs[idx];
                      _workspaceController.closeTab(idx);
                      _pdfControllers.remove(tabToClose.id);
                    },
                  ),
  
                // ── MAIN BODY (Sidebar + Workspace content) ──
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Glass sidebar with transitions
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.fastOutSlowIn,
                        width: showSidebar ? 258 : 0,
                        child: ClipRect(
                          child: showSidebar
                              ? SidebarWidget(
                                  controller: _workspaceController,
                                  expandedFolderIds: _expandedFolderIds,
                                  expandedTagIds: _expandedTagIds,
                                  activeNavType: _activeNavType,
                                  onSelectNav: (type, id) {
                                    setState(() {
                                      _activeNavType = type;
                                    });
                                    if (type == 'all') {
                                      _workspaceController.setFilters(folderFilter: 'all', resetOther: true);
                                    } else if (type == 'unclassified') {
                                      _workspaceController.setFilters(folderFilter: 'unclassified', resetOther: true);
                                    } else if (type == 'folder') {
                                      _workspaceController.setFilters(folderFilter: id, resetOther: true);
                                    } else if (type == 'tag') {
                                      _workspaceController.setFilters(tagFilter: id, resetOther: true);
                                    }
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
  
                      // Main Viewport Area
                      Expanded(
                        child: activeTab.type == TabType.home
                            ? HomeDashboard(
                                controller: _workspaceController,
                                activeNavType: _activeNavType,
                              )
                            : PdfTabViewport(
                                docId: activeTab.id,
                                filePath: activeTab.filePath ?? '',
                                pdfController: _getOrBuildController(activeTab.id, activeTab.filePath ?? ''),
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
  
            // Floating Controls (Fold Sidebar & Settings) - Only show on Home Tab
            if (activeTab.type == TabType.home)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 350),
                curve: Curves.fastOutSlowIn,
                top: 54,
                left: sidebarOpen ? 258 - 88 : 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingButton(
                      icon: Icons.splitscreen_rounded,
                      tooltip: sidebarOpen ? '折叠侧栏' : '展开侧栏',
                      onTap: () => _workspaceController.setSidebarOpen(!sidebarOpen),
                    ),
                    const SizedBox(width: 6),
                    _buildFloatingButton(
                      icon: Icons.settings_rounded,
                      tooltip: '设置',
                      onTap: () => _showSettingsDialog(context),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0x11FFDC78),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0x33FFDC8C), width: 1),
          ),
          child: Icon(icon, size: 16, color: const Color(0xB3FFF8E6)),
        ),
      ),
    );
  }
}

// ── CUSTOM FLOATING CONTEXT MENU ──

class ContextMenuItem {
  final String title;
  final IconData? icon;
  final bool isDanger;
  final VoidCallback onTap;

  ContextMenuItem({
    required this.title,
    this.icon,
    this.isDanger = false,
    required this.onTap,
  });
}

void _showGlassContextMenu({
  required BuildContext context,
  required Offset tapPosition,
  required List<ContextMenuItem> items,
}) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'context_menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, anim1, anim2) {
      return Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              behavior: HitTestBehavior.translucent,
            ),
          ),
          Positioned(
            left: tapPosition.dx,
            top: tapPosition.dy,
            child: FadeTransition(
              opacity: anim1,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.92, end: 1.0).animate(
                  CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: 160,
                    decoration: BoxDecoration(
                      color: const Color(0xED16110A),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x33FFDC8C), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: items.map((item) {
                          return InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              item.onTap();
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                children: [
                                  if (item.icon != null) ...[
                                    Icon(item.icon,
                                        size: 14,
                                        color: item.isDanger
                                            ? const Color(0xFFE05858)
                                            : const Color(0xFFFFC800)),
                                    const SizedBox(width: 10),
                                  ],
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        color: item.isDanger
                                            ? const Color(0xFFE05858)
                                            : const Color(0xFFFFF8E6),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
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

// ── GLASS DIALOG BUILDER ──

Future<T?> _showGlassDialog<T>({
  required BuildContext context,
  required Widget child,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'glass_dialog',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (context, anim1, anim2) {
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Center(
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: FadeTransition(
              opacity: anim1,
              child: child,
            ),
          ),
        ),
      );
    },
  );
}

// ── ORB BACKGROUND GLOWS ──

class OrbBackground extends StatelessWidget {
  final bool isDark;
  const OrbBackground({super.key, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (!isDark) return const SizedBox.shrink();

    return Stack(
      children: [
        Positioned(
          top: -150,
          left: -100,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF6B3A08).withOpacity(0.18),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -80,
          right: -60,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 360,
              height: 360,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF3D1F02).withOpacity(0.22),
              ),
            ),
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.35,
          left: MediaQuery.of(context).size.width * 0.42,
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1A2820).withOpacity(0.15),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── TAB BAR WIDGET ──

class TabBarWidget extends StatelessWidget {
  final List<TabItem> tabs;
  final int activeIndex;
  final ValueChanged<int> onSelect;
  final ValueChanged<int> onClose;

  const TabBarWidget({
    super.key,
    required this.tabs,
    required this.activeIndex,
    required this.onSelect,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;
    const double leftSpacerWidth = 12.0;

    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xCC0E0B06) : const Color(0xFFEFECE6),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1AFFDC8C) : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Padding to account for floating control buttons on the left
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.fastOutSlowIn,
            width: leftSpacerWidth,
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: tabs.length,
              itemBuilder: (context, idx) {
                final tab = tabs[idx];
                final isActive = idx == activeIndex;

                return GestureDetector(
                  onTap: () => onSelect(idx),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: isActive
                          ? (isDark ? const Color(0x2E6B3A08) : const Color(0x1F6B3A08))
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(
                        color: isActive
                            ? (isDark ? const Color(0x4DC8841A) : const Color(0x33C8841A))
                            : Colors.transparent,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          tab.type == TabType.home
                              ? Icons.home_rounded
                              : Icons.picture_as_pdf_rounded,
                          size: 13,
                          color: isActive
                              ? const Color(0xFFFFC800)
                              : (isDark ? Colors.white60 : Colors.black54),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          tab.title,
                          style: TextStyle(
                            fontSize: 12,
                            color: isActive
                                ? const Color(0xFFFFF8E6)
                                : (isDark ? Colors.white70 : Colors.black87),
                            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        if (tab.type != TabType.home) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              onClose(idx);
                            },
                            child: Icon(
                              Icons.close_rounded,
                              size: 11,
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // Split Pane placeholder button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Tooltip(
              message: '双联分屏(敬请期待)',
              child: Icon(
                Icons.vertical_split_rounded,
                size: 15,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── SIDEBAR WIDGET ──

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
    final totalNotesCount = controller.documents.length; // Placeholder or calculate
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
                  onAdd: () => _showCreateFolderDialog(context, null),
                ),
                if (folderTree != null)
                  ...folderTree.children.map((child) => _buildFolderNode(context, child, 0)),

                const SizedBox(height: 16),

                // ── TAGS TREE GROUP ──
                _buildSectionHeader(
                  title: '标签',
                  icon: Icons.sell_rounded,
                  iconColor: const Color(0xFFE06080),
                  onAdd: () => _showCreateTagDialog(context, null),
                ),
                if (tagTree != null)
                  ...tagTree.children.map((child) => _buildTagNode(context, child, 0)),
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
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: isDark ? const Color(0xCCFFF8E6) : Colors.black87,
            ),
          ),
          const SizedBox(width: 6),
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
                      ? (isDark ? const Color(0xFFFFF8E6) : const Color(0xFF805C00))
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
    final isSelected = activeNavType == 'folder' && controller.activeFolderFilter == node.id;
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
            margin: EdgeInsets.only(left: (depth * 10).toDouble(), top: 1, bottom: 1),
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
                        ? (isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded)
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
                      : (isDark ? const Color(0xFFE8A040) : const Color(0xFFB37424)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? (isDark ? const Color(0xFFFFF8E6) : const Color(0xFF805C00))
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
          ...node.children.map((child) => _buildFolderNode(context, child, depth + 1)),
      ],
    );
  }

  void _showFolderContextMenu(BuildContext context, Offset position, Folder node) {
    _showGlassContextMenu(
      context: context,
      tapPosition: position,
      items: [
        ContextMenuItem(
          title: '新建子文件夹',
          icon: Icons.create_new_folder_rounded,
          onTap: () => _showCreateFolderDialog(context, node.id),
        ),
        ContextMenuItem(
          title: '重命名',
          icon: Icons.edit_rounded,
          onTap: () => _showRenameFolderDialog(context, node),
        ),
        ContextMenuItem(
          title: '删除文件夹',
          icon: Icons.delete_forever_rounded,
          isDanger: true,
          onTap: () => _showDeleteFolderConfirm(context, node),
        ),
      ],
    );
  }

  // ── TAG TREE NODE RENDERING ──

  Widget _buildTagNode(BuildContext context, Tag node, int depth) {
    final isExpanded = expandedTagIds.contains(node.id);
    final isSelected = activeNavType == 'tag' && controller.activeTagFilter == node.id;
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
            margin: EdgeInsets.only(left: (depth * 10).toDouble(), top: 1, bottom: 1),
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
                        ? (isExpanded ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded)
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
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? (isDark ? const Color(0xFFFFF8E6) : const Color(0xFF805C00))
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
          ...node.children.map((child) => _buildTagNode(context, child, depth + 1)),
      ],
    );
  }

  void _showTagContextMenu(BuildContext context, Offset position, Tag node) {
    _showGlassContextMenu(
      context: context,
      tapPosition: position,
      items: [
        ContextMenuItem(
          title: '新建子标签',
          icon: Icons.sell_rounded,
          onTap: () => _showCreateTagDialog(context, node.id),
        ),
        ContextMenuItem(
          title: '重命名',
          icon: Icons.edit_rounded,
          onTap: () => _showRenameTagDialog(context, node),
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

void _showCreateFolderDialog(BuildContext context, String? parentId) {
  final controller = TextEditingController();
  final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;

  _showGlassDialog(
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
                const Icon(Icons.create_new_folder_rounded, color: Color(0xFFFFC800)),
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
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
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
                  child: Text('取消', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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

void _showRenameFolderDialog(BuildContext context, Folder node) {
  final controller = TextEditingController(text: node.name);
  final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;

  _showGlassDialog(
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
                  child: Text('取消', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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

void _showDeleteFolderConfirm(BuildContext context, Folder node) {
  final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;

  _showGlassDialog(
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
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFE05858)),
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
                  child: Text('取消', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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

void _showCreateTagDialog(BuildContext context, String? parentId) {
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

  _showGlassDialog(
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
                    hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
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
                    final colorVal = Color(int.parse(colorHex.replaceFirst('#', '0xFF')));
                    final isSelected = selectedColor == colorHex;

                    return GestureDetector(
                      onTap: () => setModalState(() => selectedColor = colorHex),
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
                              ? [BoxShadow(color: colorVal.withOpacity(0.5), blurRadius: 6, spreadRadius: 2)]
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
                      child: Text('取消', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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
                          context.workspaceController.createTag(name, parentId, selectedColor);
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

void _showRenameTagDialog(BuildContext context, Tag node) {
  final controller = TextEditingController(text: node.name);
  final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;

  _showGlassDialog(
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
                  child: Text('取消', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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

// ── APP SETTINGS DIALOG ──

void _showSettingsDialog(BuildContext context) {
  final controller = context.workspaceController;
  final isDark = controller.isDarkMode;

  _showGlassDialog(
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
                    const Icon(Icons.settings_rounded, color: Color(0xFFFFC800)),
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
                _buildSettingsSectionHeader(isDark, '通用'),
                _buildSettingsRow(
                  isDark: isDark,
                  label: '自动保存',
                  subLabel: '笔记变更时自动保存到本地',
                  value: controller.autoSave,
                  onChanged: (val) {
                    controller.setAutoSave(val);
                    setModalState(() {});
                  },
                ),
                _buildSettingsRow(
                  isDark: isDark,
                  label: '深色模式',
                  subLabel: '使用深色太空美学主题',
                  value: controller.isDarkMode,
                  onChanged: (val) {
                    controller.setDarkMode(val);
                    setModalState(() {});
                  },
                ),
                 _buildSettingsRow(
                  isDark: isDark,
                  label: '侧边栏默认展开',
                  subLabel: '启动时自动展开左侧导航',
                  value: controller.sidebarOpen,
                  onChanged: (val) {
                    controller.setSidebarOpen(val);
                    setModalState(() {});
                  },
                ),
                _buildSettingsRow(
                  isDark: isDark,
                  label: '隐藏系统状态栏',
                  subLabel: '开启后将隐藏安卓系统的状态栏',
                  value: controller.hideSystemStatusBar,
                  onChanged: (val) {
                    controller.setHideSystemStatusBar(val);
                    setModalState(() {});
                  },
                ),
                _buildSettingsSectionHeader(isDark, 'PDF 阅读'),
                _buildSettingsRow(
                  isDark: isDark,
                  label: '自由平移',
                  subLabel: '允许 PDF 页面在视口内自由移动',
                  value: controller.freePanEnabled,
                  onChanged: (val) {
                    controller.setFreePanEnabled(val);
                    setModalState(() {});
                  },
                ),
                _buildSettingsRow(
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

Widget _buildSettingsSectionHeader(bool isDark, String title) {
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

Widget _buildSettingsRow({
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

class GlassToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const GlassToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 20,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: value ? const Color(0xFFC8841A) : Colors.white10,
          border: Border.all(
            color: value ? const Color(0xFFC8841A) : const Color(0x1AFFDC8C),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.all(2),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── DOCUMENT IMPORT MODAL ──

void _showImportPdfDialog(BuildContext context, WorkspaceController workspaceController) {
  final isDark = workspaceController.isDarkMode;
  String? folderId = workspaceController.activeFolderFilter;

  // If active filter is "all" or "unclassified" or tag filters, import to null (Unclassified)
  if (folderId == 'all' || folderId == 'unclassified') {
    folderId = null;
  }

  _showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0x33FFDC8C)),
      ),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFFFC800)),
                const SizedBox(width: 10),
                Text(
                  '导入 PDF 文件',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _handlePdfFileSelection(context, folderId, workspaceController),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0x33FFC800),
                    style: BorderStyle.solid,
                    width: 2,
                  ),
                  color: isDark ? const Color(0x0CFFC800) : const Color(0x05FFC800),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 40, color: Color(0xFFFFC800)),
                    const SizedBox(height: 10),
                    Text(
                      '选择并导入 PDF 文件',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '文件将被物理拷贝至 App 沙盒目录内',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white30 : Colors.black38,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _handlePdfFileSelection(
  BuildContext context,
  String? folderId,
  WorkspaceController workspaceController,
) async {
  // Close selection dialog first
  Navigator.pop(context);

  final result = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf'],
  );

  if (result == null || result.files.single.path == null) return;

  final filePath = result.files.single.path!;
  final fileName = result.files.single.name;
  final defaultTitle = fileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), '');

  if (!context.mounted) return;

  // Pop up title confirm dialog
  final titleController = TextEditingController(text: defaultTitle);
  final isDark = workspaceController.isDarkMode;

  _showGlassDialog(
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
            Text(
              '确认文档标题',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                filled: true,
                fillColor: isDark ? Colors.black26 : Colors.black12,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('取消', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFC800),
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    Navigator.pop(context); // Close title dialog

                    // Show loader dialog during copy
                    _showLoaderDialog(context, isDark);

                    try {
                      await workspaceController.importPdfFile(title, filePath, folderId);
                    } catch (e) {
                      debugPrint('Import PDF failed: $e');
                    } finally {
                      if (context.mounted) {
                        Navigator.pop(context); // Close loader
                      }
                    }
                  },
                  child: const Text('开始导入'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

void _showLoaderDialog(BuildContext context, bool isDark) {
  _showGlassDialog(
    context: context,
    child: Card(
      color: isDark ? const Color(0xF216110A) : const Color(0xF2FFFBF7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      child: Container(
        width: 260,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Color(0xFFFFC800)),
            const SizedBox(height: 18),
            Text(
              '正在拷贝至沙盒目录...',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── HOME DASHBOARD PORTAL ──

class HomeDashboard extends StatefulWidget {
  final WorkspaceController controller;
  final String activeNavType;

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
  String _activeGridFilter = '全部'; // '全部', '笔记', 'PDF'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showSortContextMenu(BuildContext context, Offset globalPosition) {
    _showGlassContextMenu(
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

    // Filter items locally based on 'All/Note/PDF' selector
    // In our phase 3 context, we only support PDF documents imports.
    // So '全部' and 'PDF' will show PDFs, '笔记' is empty.
    final displayDocs = docs.where((doc) {
      if (_activeGridFilter == '笔记') return false;
      return true;
    }).toList();

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
            border: Border(bottom: BorderSide(color: isDark ? const Color(0x0CFFDC8C) : Colors.black12)),
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
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
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
                onTapDown: (details) => _showSortContextMenu(context, details.globalPosition),
                isDark: isDark,
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFC800),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                  fixedSize: const Size.fromHeight(32),
                  elevation: 6,
                  shadowColor: const Color(0x33FFC800),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.add, size: 14),
                label: const Text('导入 PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                onPressed: () => _showImportPdfDialog(context, widget.controller),
              ),
            ],
          ),
        ),

        // ── FILTER BAR ──
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: isDark ? const Color(0x0CFFDC8C) : Colors.black12)),
          ),
          child: Row(
            children: ['全部', '笔记', 'PDF'].map((filter) {
              final isActive = _activeGridFilter == filter;

              return GestureDetector(
                onTap: () => setState(() => _activeGridFilter = filter),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isActive ? const Color(0xFFFFC800) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    filter,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
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
          child: displayDocs.isEmpty && widget.activeNavType == 'trash'
              ? const Center(child: Text('回收站为空', style: TextStyle(color: Colors.white24)))
              : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 180,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 3 / 4.4,
                  ),
                  itemCount: displayDocs.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == 0) {
                      // First slot is "Import PDF" dashed card
                      return _buildImportDashedCard(isDark);
                    }

                    final doc = displayDocs[idx - 1];
                    return _buildDocumentCard(context, doc, isDark);
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
            color: isActive ? const Color(0xFFFFC800) : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildImportDashedCard(bool isDark) {
    return GestureDetector(
      onTap: () => _showImportPdfDialog(context, widget.controller),
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

  // Cover background gradient presets
  final List<List<Color>> _coverGradients = const [
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
    final dateStr = '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

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
          border: Border.all(color: isDark ? Colors.white10 : const Color(0x1F805C00)),
          color: isDark ? Colors.white10 : Colors.white,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PDF',
                            style: TextStyle(fontSize: 8, color: Color(0xFFFFC800), fontWeight: FontWeight.bold),
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
                            color: Colors.white.withOpacity(0.9),
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Cover structural lines placeholder
                        Container(height: 2, width: 80, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(1))),
                        const SizedBox(height: 3),
                        Container(height: 2, width: 50, decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(1))),
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

  void _showCardContextMenu(BuildContext context, Offset position, Document doc) {
    _showGlassContextMenu(
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

    _showGlassDialog(
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
                  child: Text('暂无标签，请先在侧边栏创建。', style: TextStyle(color: Colors.white30, fontSize: 13)),
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
                        title: Text(tag.name, style: const TextStyle(fontSize: 13)),
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
                    child: Text('取消', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)),
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

// ── PDF VIEWPORT TAB CONTENT ──

class PdfTabViewport extends StatefulWidget {
  final String docId;
  final String filePath;
  final PdfViewportController pdfController;

  const PdfTabViewport({
    super.key,
    required this.docId,
    required this.filePath,
    required this.pdfController,
  });

  @override
  State<PdfTabViewport> createState() => _PdfTabViewportState();
}

class _PdfTabViewportState extends State<PdfTabViewport> {
  final TransformationController _transformController = TransformationController();

  final GlobalKey _viewportKey = GlobalKey();
  final GlobalKey _pdfStackKey = GlobalKey();

  bool _isExcerptsOpen = true;
  int _currentPage = 1;
  bool _isInteracting = false;

  String _activeTool = 'select';
  Color _activeColor = const Color(0xFFFFC800);

  // Ink drawing state
  InkTool _inkTool = InkTool.pen;
  final double _strokeWidth = 2.0;
  bool _palmRejectionEnabled = false;
  PointerDeviceKind? _lastPointerDeviceKind;

  // Annotation controller for ink drawing and annotations
  AnnotationController? _annotationController;

  @override
  void initState() {
    super.initState();
    widget.pdfController.addListener(_onPdfChanged);
    _initAnnotationController();
    _palmRejectionEnabled = context.workspaceController.palmRejectionEnabled;
  }

  Future<void> _initAnnotationController() async {
    final repository = context.workspaceController.repository;
    _annotationController = AnnotationController(
      repository: repository,
      documentId: widget.docId,
    );
    await _annotationController!.loadAnnotations();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.pdfController.removeListener(_onPdfChanged);
    _transformController.dispose();
    _annotationController?.dispose();
    super.dispose();
  }

  void _onPdfChanged() {
    if (mounted && !_isInteracting) {
      _syncTransformFromController();
      _updateCurrentPage();
      setState(() {});
    }
  }

  void _syncTransformFromController() {
    final pdfCtrl = widget.pdfController;
    final viewportSize = _viewportKey.currentContext?.size;
    if (viewportSize == null) return;

    final pdfSize = pdfCtrl.pageSizes.isNotEmpty ? pdfCtrl.pageSizes.values.first : null;
    if (pdfSize == null) return;

    final matrix = Matrix4.identity()
      ..scale(pdfCtrl.zoom, pdfCtrl.zoom, 1.0)
      ..translate(pdfCtrl.panOffset.dx, pdfCtrl.panOffset.dy, 0.0);

    _transformController.value = matrix;
  }

  void _onInteractionStart(ScaleStartDetails details) {
    _isInteracting = true;
  }

  void _onInteractionUpdate(ScaleUpdateDetails details) {
    if (!mounted) return;

    final pdfCtrl = widget.pdfController;
    final viewportSize = _viewportKey.currentContext?.size;
    final pdfSize = pdfCtrl.pageSizes.isNotEmpty ? pdfCtrl.pageSizes.values.first : null;
    if (viewportSize == null || pdfSize == null) return;

    final matrix = _transformController.value;
    final zoom = matrix.getMaxScaleOnAxis().clamp(0.5, 5.0);

    final panX = matrix.entry(0, 3) / zoom;
    final panY = matrix.entry(1, 3) / zoom;

    pdfCtrl.setViewportState(zoom: zoom, panOffset: Offset(panX, panY));
    _updateCurrentPage();
  }

  void _onInteractionEnd(ScaleEndDetails details) {
    _isInteracting = false;
    _applyCenteringIfNeeded();
  }

  /// Center the PDF horizontally if it's narrower than the viewport.
  void _applyCenteringIfNeeded() {
    final pdfCtrl = widget.pdfController;
    final viewportSize = _viewportKey.currentContext?.size;
    final pdfSize = pdfCtrl.pageSizes.isNotEmpty ? pdfCtrl.pageSizes.values.first : null;

    if (viewportSize == null || pdfSize == null) return;

    final baseScale = viewportSize.width / pdfSize.width;

    // If PDF display width is smaller than viewport, center it
    final pdfDisplayWidth = pdfSize.width * baseScale * pdfCtrl.zoom;
    if (pdfDisplayWidth < viewportSize.width) {
      pdfCtrl.setViewportState(
        zoom: pdfCtrl.zoom,
        panOffset: Offset(0, pdfCtrl.panOffset.dy),
      );
      _syncTransformFromController();
    }
  }

  void _updateCurrentPage() {
    if (!mounted) return;
    final controller = widget.pdfController;
    if (controller.pageCount <= 1) return;

    final scrollOffset = -controller.panOffset.dy;
    final viewportBox = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final viewportWidth = viewportBox?.size.width ?? (MediaQuery.of(context).size.width * 0.55);

    double currentHeightAccumulator = 0;
    int detectedPage = 0;

    for (int i = 0; i < controller.pageCount; i++) {
      final size = controller.pageSizes[i];
      double pageHeight = 842.0;
      if (size != null) {
        pageHeight = size.height;
      } else if (controller.pageSizes.isNotEmpty) {
        pageHeight = controller.pageSizes.values.first.height;
      }

      final double pdfWidth = size?.width ?? 595.0;
      final baseScale = viewportWidth / pdfWidth;
      final logicalHeight = pageHeight * baseScale + 16.0; // Static layout height

      if (scrollOffset < currentHeightAccumulator + logicalHeight / 2) {
        detectedPage = i;
        break;
      }
      currentHeightAccumulator += logicalHeight;
      detectedPage = i;
    }

    final newPage = (detectedPage + 1).clamp(1, controller.pageCount);
    if (newPage != _currentPage) {
      setState(() {
        _currentPage = newPage;
      });
    }
  }

  Offset? _getToolbarLocalPosition() {
    if (widget.pdfController.selectionToolbarPosition == null) return null;
    final RenderBox? stackBox = _pdfStackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return null;
    return stackBox.globalToLocal(widget.pdfController.selectionToolbarPosition!);
  }

  /// Builds the text selection gesture layer for a page.
  Widget _buildTextSelectionLayer(int pageIndex, PdfViewportController pdfCtrl) {
    final pdfSize = pdfCtrl.pageSizes[pageIndex];
    if (pdfSize == null) return const SizedBox.shrink();

    final viewportWidth = _viewportKey.currentContext?.size?.width ?? (MediaQuery.of(context).size.width * 0.55);
    final baseScale = viewportWidth / pdfSize.width;

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPressStart: (details) {
          final pdfPoint = _screenToPdf(details.localPosition, baseScale, pdfSize.height);
          pdfCtrl.startSelection(pageIndex, pdfPoint);
        },
        onLongPressMoveUpdate: (details) {
          final pdfPoint = _screenToPdf(details.localPosition, baseScale, pdfSize.height);
          pdfCtrl.updateSelection(pdfPoint);
        },
        onLongPressEnd: (details) {
          pdfCtrl.endSelection(details.globalPosition);
        },
        child: Container(color: Colors.transparent),
      ),
    );
  }

  /// Converts screen coordinates to PDF coordinates.
  Offset _screenToPdf(Offset localPos, double baseScale, double pdfHeight) {
    final pdfX = localPos.dx / baseScale;
    final pdfY = pdfHeight - (localPos.dy / baseScale);
    return Offset(pdfX, pdfY);
  }

  Widget _buildTopToolbar(BuildContext context, bool isDark, PdfViewportController pdfCtrl) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xEC100D08) : const Color(0xECFFFBF7),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0x1AFFDC8C) : Colors.black12,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildToolbarButton(
            icon: Icons.near_me_rounded,
            tooltip: '选择',
            isActive: _activeTool == 'select',
            onTap: () => setState(() => _activeTool = 'select'),
            isDark: isDark,
          ),
          _buildToolbarButton(
            icon: Icons.pan_tool_rounded,
            tooltip: '手形拖动',
            isActive: _activeTool == 'hand',
            onTap: () => setState(() => _activeTool = 'hand'),
            isDark: isDark,
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 18, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(width: 6),
          _buildToolbarButton(
            icon: Icons.edit_rounded,
            tooltip: '画笔',
            isActive: _activeTool == 'pen',
            onTap: () => setState(() {
              _activeTool = 'pen';
              _inkTool = InkTool.pen;
            }),
            isDark: isDark,
          ),
          _buildToolbarButton(
            icon: Icons.border_color_rounded,
            tooltip: '高亮',
            isActive: _activeTool == 'highlight',
            onTap: () => setState(() {
              _activeTool = 'highlight';
              _inkTool = InkTool.highlighter;
            }),
            isDark: isDark,
          ),
          _buildToolbarButton(
            icon: Icons.text_fields_rounded,
            tooltip: '文本批注',
            isActive: _activeTool == 'text',
            onTap: () => setState(() => _activeTool = 'text'),
            isDark: isDark,
          ),
          _buildToolbarButton(
            icon: Icons.auto_fix_normal_rounded,
            tooltip: '橡皮擦',
            isActive: _activeTool == 'eraser',
            onTap: () => setState(() {
              _activeTool = 'eraser';
              _inkTool = InkTool.eraser;
            }),
            isDark: isDark,
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 18, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(width: 6),
          _buildToolbarButton(
            icon: _palmRejectionEnabled ? Icons.do_not_touch : Icons.touch_app,
            tooltip: _palmRejectionEnabled ? '防误触: 开' : '防误触: 关',
            isActive: _palmRejectionEnabled,
            onTap: () => setState(() {
              _palmRejectionEnabled = !_palmRejectionEnabled;
              context.workspaceController.setPalmRejectionEnabled(_palmRejectionEnabled);
            }),
            isDark: isDark,
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 18, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(width: 12),
          ...[const Color(0xFFFFC800), const Color(0xFF4CAF50), const Color(0xFF2196F3), const Color(0xFFE05858)].map((color) {
            final isSelected = _activeColor == color;
            return GestureDetector(
              onTap: () => setState(() => _activeColor = color),
              child: Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? (isDark ? Colors.white : Colors.black87) : Colors.transparent,
                    width: 1.5,
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          _buildToolbarButton(
            icon: Icons.undo_rounded,
            tooltip: '撤销',
            isActive: false,
            onTap: pdfCtrl.canUndo ? () => pdfCtrl.undo() : null,
            isDark: isDark,
            enabled: pdfCtrl.canUndo,
          ),
          _buildToolbarButton(
            icon: Icons.redo_rounded,
            tooltip: '重做',
            isActive: false,
            onTap: pdfCtrl.canRedo ? () => pdfCtrl.redo() : null,
            isDark: isDark,
            enabled: pdfCtrl.canRedo,
          ),
          const SizedBox(width: 6),
          Container(width: 1, height: 18, color: isDark ? Colors.white12 : Colors.black12),
          const SizedBox(width: 6),
          _buildToolbarButton(
            icon: _isExcerptsOpen ? Icons.menu_open_rounded : Icons.menu_rounded,
            tooltip: '批注列表',
            isActive: _isExcerptsOpen,
            onTap: () => setState(() => _isExcerptsOpen = !_isExcerptsOpen),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required IconData icon,
    required String tooltip,
    required bool isActive,
    required VoidCallback? onTap,
    required bool isDark,
    bool enabled = true,
  }) {
    final color = enabled
        ? (isActive
            ? const Color(0xFFFFC800)
            : (isDark ? Colors.white70 : Colors.black87))
        : (isDark ? Colors.white24 : Colors.black26);

    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 16, color: color),
        onPressed: onTap,
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
      ),
    );
  }

  Widget _buildBottomStatusBar(BuildContext context, bool isDark, PdfViewportController pdfCtrl) {
    return ListenableBuilder(
      listenable: pdfCtrl,
      builder: (context, _) {
        final ws = context.workspaceController;
        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0C0A07) : const Color(0xFFFAF8F5),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0x1AFFDC8C) : Colors.black12,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.picture_as_pdf_rounded, size: 12, color: isDark ? Colors.white30 : Colors.black38),
                  const SizedBox(width: 6),
                  Text(
                    '$_currentPage / ${pdfCtrl.pageCount}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline_rounded,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.black54),
                    onPressed: () => pdfCtrl.setZoom(pdfCtrl.zoom - 0.5),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${(pdfCtrl.zoom * 100).round()}%',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded,
                        size: 14,
                        color: isDark ? Colors.white54 : Colors.black54),
                    onPressed: () => pdfCtrl.setZoom(pdfCtrl.zoom + 0.5),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 12,
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                  const SizedBox(width: 12),
                  Tooltip(
                    message: ws.isImmersiveMode ? '退出沉浸模式' : '沉浸模式',
                    child: IconButton(
                      icon: Icon(
                        ws.isImmersiveMode
                            ? Icons.fullscreen_exit_rounded
                            : Icons.fullscreen_rounded,
                        size: 16,
                        color: const Color(0xFFFFC800),
                      ),
                      onPressed: () {
                        ws.setImmersiveMode(!ws.isImmersiveMode);
                      },
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(4),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExcerptsSidebar(BuildContext context, bool isDark, PdfViewportController pdfCtrl) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0C08) : const Color(0xFFF5F2EC),
        border: Border(
          left: BorderSide(
            color: isDark ? const Color(0x1AFFDC8C) : Colors.black12,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '摘录与思维导图',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Color(0xFFFFC800),
                  ),
                ),
                Chip(
                  backgroundColor: const Color(0x26FFC800),
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4),
                  label: Text(
                    '${pdfCtrl.highlights.length} 项',
                    style: const TextStyle(
                      color: Color(0xFFFFC800),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0x12FFDC8C), height: 1),
          Expanded(
            child: pdfCtrl.highlights.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.format_indent_increase_rounded,
                            size: 36,
                            color: isDark ? Colors.white12 : Colors.black12,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '暂无摘录',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '长按文档文字进行高亮和摘录。',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.white30 : Colors.black38,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(10.0),
                    itemCount: pdfCtrl.highlights.length,
                    itemBuilder: (context, index) {
                      final item = pdfCtrl.highlights[index];

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4.0),
                        color: isDark ? const Color(0x1F1A150F) : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: item.color.withOpacity(0.3),
                            width: 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  width: 5,
                                  color: item.color,
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '第 ${item.pageIndex + 1} 页',
                                              style: TextStyle(
                                                color: isDark ? Colors.white30 : Colors.black38,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => pdfCtrl.removeHighlight(item.id),
                                              child: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Color(0xFFE05858),
                                                size: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item.text,
                                          style: TextStyle(
                                            color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                                            fontSize: 12.5,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.maybeWorkspaceController?.isDarkMode ?? true;
    final pdfCtrl = widget.pdfController;

    // Diagnostic: show loading step overlay when PDF is loading or error
    if (pdfCtrl.isLoading || pdfCtrl.loadingError != null) {
      return Column(
        children: [
          _buildTopToolbar(context, isDark, pdfCtrl),
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xEC100D08) : const Color(0xECFFFBF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFC800), width: 2),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pdfCtrl.loadingError != null)
                      const Icon(Icons.error_outline, size: 40, color: Color(0xFFE05858))
                    else
                      const CircularProgressIndicator(color: Color(0xFFFFC800)),
                    const SizedBox(height: 16),
                    Text(
                      pdfCtrl.loadingError ?? pdfCtrl.loadingStep,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (pdfCtrl.loadingError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '诊断提示：PDFium初始化或文档加载可能失败，请检查Starmind-DIAG日志',
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0x66FFFFFF) : Colors.black45),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _buildBottomStatusBar(context, isDark, pdfCtrl),
        ],
      );
    }

    final viewportWidth = MediaQuery.of(context).size.width * 0.55;

    return Column(
      children: [
        _buildTopToolbar(context, isDark, pdfCtrl),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  key: _pdfStackKey,
                  children: [
                    Container(
                      key: _viewportKey,
                      color: isDark ? const Color(0xFF1A1610) : const Color(0xFFFAF9F6),
                      child: Listener(
                        onPointerDown: (event) {
                          _lastPointerDeviceKind = event.kind;
                        },
                        child: InteractiveCanvasViewer(
                          transformationController: _transformController,
                          minScale: 0.5,
                          maxScale: 5.0,
                          constrained: false,
                          panEnabled: true,
                          scaleEnabled: true,
                          isDrawGesture: (details) {
                            if (_activeTool == 'select') return false;
                            if (_palmRejectionEnabled && _lastPointerDeviceKind != PointerDeviceKind.stylus) {
                              return false;
                            }
                            if (details.pointerCount >= 2) return false;
                            return _activeTool == 'pen' || _activeTool == 'highlight' || _activeTool == 'eraser';
                          },
                          onInteractionStart: _onInteractionStart,
                          onInteractionUpdate: _onInteractionUpdate,
                          onInteractionEnd: _onInteractionEnd,
                          child: Column(
                            children: List.generate(pdfCtrl.pageCount, (index) {
                              final isInkMode = _activeTool == 'pen' || _activeTool == 'highlight' || _activeTool == 'eraser';
                              final colorHex = '#${_activeColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
                              final size = pdfCtrl.pageSizes[index];
                              final double pdfWidth = size?.width ?? 595.0;
                              final baseScale = viewportWidth / pdfWidth;

                              return Stack(
                                children: [
                                  PdfPageWidget(
                                    pageIndex: index,
                                    controller: pdfCtrl,
                                    viewportKey: _viewportKey,
                                    viewportWidth: viewportWidth,
                                  ),
                                  // Text selection gesture layer
                                  if (_activeTool == 'select')
                                    _buildTextSelectionLayer(index, pdfCtrl),
                                  // Ink drawing layer for handwriting
                                  if (isInkMode)
                                    buildInkDrawingLayer(
                                      controller: pdfCtrl,
                                      pageIndex: index,
                                      isInkMode: isInkMode,
                                      currentTool: _inkTool,
                                      currentColor: colorHex,
                                      strokeWidth: _strokeWidth,
                                      scale: baseScale,
                                      annotationController: _annotationController,
                                    ),
                                  // Annotation renderer for highlights, underlines, etc.
                                  buildAnnotationRenderer(
                                    controller: pdfCtrl,
                                    pageIndex: index,
                                    scale: baseScale,
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                    if (pdfCtrl.selectionToolbarPosition != null)
                      () {
                        final pos = _getToolbarLocalPosition();
                        if (pos != null) {
                          return PdfSelectionToolbar(
                            position: pos,
                            onDismiss: () => pdfCtrl.clearSelection(),
                            onHighlight: (color) {
                              final pageIndex = pdfCtrl.selectingPageIndex!;
                              final start = min(pdfCtrl.selectionStartCharIndex!, pdfCtrl.selectionEndCharIndex!).toInt();
                              final end = max(pdfCtrl.selectionStartCharIndex!, pdfCtrl.selectionEndCharIndex!).toInt();
                              final text = pdfCtrl.getSelectedText();
                              final rects = pdfCtrl.getSelectionRects(pageIndex);

                              final highlight = PdfHighlight(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                pageIndex: pageIndex,
                                startCharIndex: start,
                                endCharIndex: end,
                                color: color,
                                rects: rects,
                                text: text,
                              );
                              pdfCtrl.addHighlight(highlight);
                              pdfCtrl.clearSelection();
                            },
                            onExcerpt: () {
                              final pageIndex = pdfCtrl.selectingPageIndex!;
                              final start = min(pdfCtrl.selectionStartCharIndex!, pdfCtrl.selectionEndCharIndex!).toInt();
                              final end = max(pdfCtrl.selectionStartCharIndex!, pdfCtrl.selectionEndCharIndex!).toInt();
                              final text = pdfCtrl.getSelectedText();
                              final rects = pdfCtrl.getSelectionRects(pageIndex);

                              final highlight = PdfHighlight(
                                id: DateTime.now().millisecondsSinceEpoch.toString(),
                                pageIndex: pageIndex,
                                startCharIndex: start,
                                endCharIndex: end,
                                color: const Color(0xFFFFC800),
                                rects: rects,
                                text: text,
                              );
                              pdfCtrl.addHighlight(highlight);
                              pdfCtrl.clearSelection();
                            },
                          );
                        }
                        return const SizedBox.shrink();
                      }(),
                  ],
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isExcerptsOpen ? MediaQuery.of(context).size.width * 0.28 : 0,
                child: ClipRect(
                  child: _isExcerptsOpen
                      ? (_annotationController != null
                          ? AnnotationSidebarPanel(
                              annotationController: _annotationController!,
                              currentPageIndex: _currentPage - 1,
                              onNavigate: (pageIndex, annotation) {
                                // Scroll to page
                                // For now, just update current page indicator
                                setState(() {
                                  _currentPage = pageIndex + 1;
                                });
                              },
                            )
                          : _buildExcerptsSidebar(context, isDark, pdfCtrl))
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),
        _buildBottomStatusBar(context, isDark, pdfCtrl),
      ],
    );
  }
}
