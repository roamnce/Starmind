import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/home/workspace_controller_provider.dart';
import 'package:starmind/src/home/tab_layout.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/ffi_mindmap_repository.dart';
import 'package:starmind/src/home/widgets/orb_background.dart';
import 'package:starmind/src/home/widgets/tab_bar_widget.dart';
import 'package:starmind/src/home/sidebar_widget.dart' show showSettingsDialog;
import 'package:starmind/src/home/sidebar_widget.dart' show SidebarWidget;
import 'package:starmind/src/home/home_dashboard.dart';
import 'package:starmind/src/pdf/widgets/pdf_tab_viewport.dart';
import 'package:starmind/src/mindmap/ui/mindmap_tab_viewport.dart';

/// Main workspace page with tabs, sidebar, and viewport management.
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key});

  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  WorkspaceController? _workspaceController;

  // Cache of PDF controllers mapped by docId
  final Map<String, PdfViewportController> _pdfControllers = {};

  // Cache of MindMap controllers mapped by topicId
  final Map<String, MindMapController> _mindMapControllers = {};

  // MindMap service (shared across all mindmap controllers)
  MindMapService? _mindMapService;

  // Track expanded folder and tag nodes
  final Set<String> _expandedFolderIds = {'root'};
  final Set<String> _expandedTagIds = {'root'};

  // Track active sidebar selection type ('all', 'unclassified', 'trash', 'folder', 'tag')
  String _activeNavType = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_workspaceController == null) {
      _workspaceController = context.workspaceController;
      _workspaceController!.addListener(_onWorkspaceChanged);
    }
  }

  @override
  void dispose() {
    _workspaceController?.removeListener(_onWorkspaceChanged);
    for (final ctrl in _pdfControllers.values) {
      ctrl.closeDoc();
      ctrl.dispose();
    }
    for (final ctrl in _mindMapControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onWorkspaceChanged() {
    _syncPdfControllers();
    _syncMindMapControllers();
    if (mounted) {
      setState(() {});
    }
  }

  /// Syncs cached PDF controllers with active workspace tabs.
  void _syncPdfControllers() {
    if (_workspaceController == null) return;
    final root = _workspaceController!.rootLayoutNode;
    if (root is! LeafNode) return;

    final activePdfIds = root.tabs
        .where((t) => t.type == TabType.pdf)
        .map((t) => t.id)
        .toSet();

    // Dispose controllers for closed tabs
    final closedIds = _pdfControllers.keys
        .where((id) => !activePdfIds.contains(id))
        .toList();
    for (final id in closedIds) {
      final ctrl = _pdfControllers.remove(id);
      ctrl?.closeDoc();
      ctrl?.dispose();
    }
  }

  /// Syncs cached MindMap controllers with active workspace tabs.
  void _syncMindMapControllers() {
    if (_workspaceController == null) return;
    final root = _workspaceController!.rootLayoutNode;
    if (root is! LeafNode) return;

    final activeMindMapIds = root.tabs
        .where((t) => t.type == TabType.mindmap)
        .map((t) => t.id)
        .toSet();

    // Dispose controllers for closed tabs
    final closedIds = _mindMapControllers.keys
        .where((id) => !activeMindMapIds.contains(id))
        .toList();
    for (final id in closedIds) {
      final ctrl = _mindMapControllers.remove(id);
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

  /// Gets or creates a MindMapController for a topic.
  MindMapController _getOrBuildMindMapController(String topicId) {
    if (!_mindMapControllers.containsKey(topicId)) {
      // Initialize service lazily if needed
      _mindMapService ??= MindMapService(FfiMindMapRepository());
      final ctrl = MindMapController(_mindMapService!, topicId);
      ctrl.loadTopic();
      _mindMapControllers[topicId] = ctrl;
    }
    return _mindMapControllers[topicId]!;
  }

  @override
  Widget build(BuildContext context) {
    // If controller not initialized yet, show loading
    if (_workspaceController == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDark = _workspaceController!.isDarkMode;
    final leaf = _workspaceController!.rootLayoutNode as LeafNode;
    final activeIndex = leaf.activeIndex;
    final activeTab = leaf.tabs[activeIndex];
    final sidebarOpen = _workspaceController!.sidebarOpen;

    // ── SYSTEM STATUS BAR CONTROL ──
    final shouldHideStatusBar =
        _workspaceController!.hideSystemStatusBar ||
        (activeTab.type == TabType.pdf &&
            _workspaceController!.isImmersiveMode);

    if (shouldHideStatusBar) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    final shouldShowTabBar =
        !(activeTab.type == TabType.pdf &&
            _workspaceController!.isImmersiveMode);
    final showSidebar = sidebarOpen && activeTab.type == TabType.home;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C0A07)
          : const Color(0xFFFAF8F5),
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
                    onSelect: (idx) => _workspaceController!.selectTab(idx),
                    onClose: (idx) {
                      final tabToClose = leaf.tabs[idx];
                      _workspaceController!.closeTab(idx);
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
                                  controller: _workspaceController!,
                                  expandedFolderIds: _expandedFolderIds,
                                  expandedTagIds: _expandedTagIds,
                                  activeNavType: _activeNavType,
                                  onSelectNav: (type, id) {
                                    setState(() {
                                      _activeNavType = type;
                                    });
                                    if (type == 'all') {
                                      _workspaceController!.setFilters(
                                        folderFilter: 'all',
                                        resetOther: true,
                                      );
                                    } else if (type == 'unclassified') {
                                      _workspaceController!.setFilters(
                                        folderFilter: 'unclassified',
                                        resetOther: true,
                                      );
                                    } else if (type == 'folder') {
                                      _workspaceController!.setFilters(
                                        folderFilter: id,
                                        resetOther: true,
                                      );
                                    } else if (type == 'tag') {
                                      _workspaceController!.setFilters(
                                        tagFilter: id,
                                        resetOther: true,
                                      );
                                    }
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),

                      // Main Viewport Area
                      Expanded(
                        child: switch (activeTab.type) {
                          TabType.home => HomeDashboard(
                            controller: _workspaceController!,
                            activeNavType: _activeNavType,
                          ),
                          TabType.pdf => PdfTabViewport(
                            docId: activeTab.id,
                            filePath: activeTab.filePath ?? '',
                            pdfController: _getOrBuildController(
                              activeTab.id,
                              activeTab.filePath ?? '',
                            ),
                          ),
                          TabType.mindmap => MindMapTabViewport(
                            topicId: activeTab.id,
                            title: activeTab.title,
                            controller: _getOrBuildMindMapController(
                              activeTab.id,
                            ),
                          ),
                        },
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
                      onTap: () =>
                          _workspaceController!.setSidebarOpen(!sidebarOpen),
                    ),
                    const SizedBox(width: 6),
                    _buildFloatingButton(
                      icon: Icons.settings_rounded,
                      tooltip: '设置',
                      onTap: () => showSettingsDialog(context),
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