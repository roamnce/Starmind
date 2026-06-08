import 'package:flutter/material.dart';
import '../domain/topic.dart';
import '../domain/note.dart';
import '../service/mindmap_service.dart';
import '../study/study_mode_controller.dart';
import '../layout/layout_result.dart';
import '../rendering/connection_renderer.dart';
import 'tree_layout.dart' show LayoutDirection;
import 'mixins/tree_traversal.dart';
import 'controllers/mindmap_viewport_controller.dart';
import 'controllers/mindmap_theme_controller.dart';
import 'controllers/mindmap_layout_controller.dart';
import 'controllers/mindmap_crud_controller.dart';

// Re-export for backward compatibility
export 'controllers/mindmap_layout_controller.dart' show LineStyle;

/// 渚ц竟鏍忔爣绛鹃〉
enum SidebarTab { note, search, theme, config, icon }

/// 鐢诲竷浜や簰妯″紡
enum CanvasInteractMode { drag, lasso }

/// MindMap UI 鐘舵€佺鐞嗐€?///
/// 缁勫悎澶氫釜瀛愭帶鍒跺櫒锛屾彁渚涚粺涓€鐨勬帴鍙ｃ€?/// 瀛愭帶鍒跺櫒锛歷iewport, theme, layout, crud
class MindMapController extends ChangeNotifier with TreeTraversal {
  final MindMapService _service;
  final String? _initialTopicId;

  MindMapController(this._service, [this._initialTopicId]);

  /// 瀛愭帶鍒跺櫒
  late final MindMapViewportController viewport = MindMapViewportController();
  late final MindMapThemeController theme = MindMapThemeController();
  late final MindMapLayoutController layout = MindMapLayoutController();
  late final MindMapCrudController crud = MindMapCrudController(service: _service);
  late final StudyModeController studyModeController = StudyModeController(
    service: _service,
  );

  // ==================== 鐘舵€佸鎵?====================

  /// 鎵€鏈夌瑪璁版湰鍒楄〃
  List<Topic> get topics => crud.topics;

  /// 褰撳墠閫変腑鐨勭瑪璁版湰
  Topic? get selectedTopic => crud.selectedTopic;

  /// 褰撳墠绗旇鏈殑鑺傜偣鏍?  List<NoteTreeNode> get noteTree => crud.noteTree;

  /// 閫変腑鐨勮妭鐐?  Note? get selectedNote => crud.selectedNote;

  /// 澶氶€夎妭鐐?ID
  Set<String> get selectedNoteIds => crud.selectedNoteIds;

  /// 鍔犺浇鐘舵€?  bool get isLoading => crud.isLoading;

  /// 瑙嗗彛缂╂斁
  double get viewportScale => viewport.scale;

  /// 瑙嗗彛鍋忕Щ
  Offset get viewportOffset => viewport.offset;

  /// 甯冨眬缁撴灉
  LayoutResult? get layoutResult => layout.result;

  /// 甯冨眬鏂瑰悜
  LayoutDirection get layoutDirection => layout.direction;`r`n`r`n  /// 布局样式`r`n  String get layoutStyle => layout.layoutStyle;

  /// 杩炵嚎鏍峰紡
  ConnectionStyle get connectionStyle => layout.connectionStyle;

  /// 瀵煎浘绾挎牱寮?  LineStyle get lineStyle => layout.lineStyle;

  /// 鏄惁浣跨敤鏂板竷灞€寮曟搸
  bool get useNewLayoutEngine => layout.useNewLayoutEngine;

  /// 鐢诲竷鑳屾櫙鑹?  Color get canvasBgColor => theme.canvasBgColor;

  /// 缃戞牸棰滆壊
  Color get gridColor => theme.gridColor;

  /// 鏄惁鏄剧ず缃戞牸
  bool get showGrid => theme.showGrid;

  /// 缃戞牸澶у皬
  double get gridSize => theme.gridSize;

  /// 鏄惁褰╄櫣鍒嗘敮
  bool get isRainbowBranch => theme.isRainbowBranch;

  // ==================== UI 鐘舵€?====================

  bool _isSidebarExpanded = false;
  bool get isSidebarExpanded => _isSidebarExpanded;

  SidebarTab _activeSidebarTab = SidebarTab.note;
  SidebarTab get activeSidebarTab => _activeSidebarTab;

  CanvasInteractMode _interactMode = CanvasInteractMode.drag;
  CanvasInteractMode get interactMode => _interactMode;

  bool _isLocked = false;
  bool get isLocked => _isLocked;

  bool _isMinimapVisible = false;
  bool get isMinimapVisible => _isMinimapVisible;

  // Inline editing state
  String? _editingNoteId;
  String? get editingNoteId => _editingNoteId;

  // 鍒嗗睆鐘舵€?  String? _splitType;
  String? get splitType => _splitType;

  String? _splitId;
  String? get splitId => _splitId;

  String? _splitTitle;
  String? get splitTitle => _splitTitle;

  String? _splitFilePath;
  String? get splitFilePath => _splitFilePath;

  // ==================== 缂╂斁闄愬埗甯搁噺 ====================

  static const double minScale = MindMapViewportController.minScale;
  static const double maxScale = MindMapViewportController.maxScale;

  // ==================== 鍒濆鍖?====================

  /// 鍔犺浇鎵€鏈夌瑪璁版湰
  Future<void> loadTopics() async {
    await crud.loadTopics();
    notifyListeners();
  }

  /// 鑾峰彇鎵€鏈夌瑪璁版湰
  Future<List<Topic>> getAllTopics() => crud.getAllTopics();

  /// 鍔犺浇鎸囧畾绗旇鏈?  Future<void> loadTopic() async {
    if (_initialTopicId == null) return;

    await crud.loadTopic(_initialTopicId!);

    // 鍔犺浇涓婚
    final topic = crud.selectedTopic;
    if (topic != null) {
      if (topic.thumbnailPath != null &&
          topic.thumbnailPath!.startsWith('{"theme":')) {
        theme.loadFromJson(topic.thumbnailPath);
      } else {
        theme.reset();
      }
      layout.recalculate(crud.noteTree);
      // Initialize layout from topic settings
      _initLayoutFromTopic(topic);
    }

    notifyListeners();
  }

  // ==================== Topic 鎿嶄綔 ====================

  /// 鍒涘缓绗旇鏈?  Future<Topic> createTopic(String title, {String? author}) async {
    final topic = await crud.createTopic(title, author: author);
    notifyListeners();
    return topic;
  }

  /// 閫夋嫨绗旇鏈?  void selectTopic(Topic? topic) {
    crud.selectTopic(topic);

    if (topic != null) {
      if (topic.thumbnailPath != null &&
          topic.thumbnailPath!.startsWith('{"theme":')) {
        theme.loadFromJson(topic.thumbnailPath);
      } else {
        theme.reset();
      }
      _loadNoteTree(topic.id);
    } else {
      layout.clearCache();
      theme.reset();
      notifyListeners();
    }
  }

  /// 杞垹闄ょ瑪璁版湰
  Future<void> trashTopic(String id) async {
    await crud.trashTopic(id);
    notifyListeners();
  }

  /// 瀵煎嚭褰撳墠绗旇鏈负 GuruMind 鏍煎紡
  Future<void> exportCurrentTopicAsGuruMind(String outputPath) async {
    await crud.exportGuruMind(outputPath);
  }

  // ==================== Note 鎿嶄綔 ====================

  /// 娣诲姞鑺傜偣锛堢畝鍖?API锛?  Future<void> addNode(String title) async {
    if (crud.selectedTopic == null) return;

    final note = await crud.createNote(title: title);

    // 娣诲姞涓烘牴鑺傜偣
    await _service.addRootNote(
      topicId: crud.selectedTopic!.id,
      noteId: note.id,
    );

    await _loadNoteTree(crud.selectedTopic!.id);
  }

  /// 鍒涘缓鑺傜偣
  Future<Note> createNote({required String title, String? parentId}) async {
    final note = await crud.createNote(title: title, parentId: parentId);
    layout.recalculate(crud.noteTree);
    notifyListeners();
    return note;
  }

  /// 鍒涘缓瀛愯妭鐐?(Tab)
  Future<Note?> createChildNode({String? title, bool enterEditing = false}) async {
    final note = await crud.createChildNode(title: title);
    if (note != null) {
      layout.recalculate(crud.noteTree);
      if (enterEditing) beginEditing(note.id);
      notifyListeners();
    }
    return note;
  }

  /// 鍒涘缓鍚岀骇鑺傜偣 (Enter)
  Future<Note?> createSiblingNode({String? title, bool enterEditing = false}) async {
    final note = await crud.createSiblingNode(title: title);
    if (note != null) {
      layout.recalculate(crud.noteTree);
      if (enterEditing) beginEditing(note.id);
      notifyListeners();
    }
    return note;
  }

  /// 閫夋嫨鑺傜偣
  void selectNote(Note? note) {
    crud.selectNote(note);
    notifyListeners();
  }

  /// 鏇存柊鑺傜偣鏍囬
  Future<void> updateNoteTitle(String noteId, String newTitle) async {
    await crud.updateNoteTitle(noteId, newTitle);
    layout.recalculate(crud.noteTree);
    notifyListeners();
  }

  /// 鍒囨崲鑺傜偣鎶樺彔鐘舵€?  Future<void> toggleNodeCollapse(String noteId) async {
    await crud.toggleNoteCollapse(noteId);
    layout.recalculate(crud.noteTree);
    notifyListeners();
  }

  /// 鍒囨崲宓屽鍗＄墖缁勫鍣ㄧ姸鎬?  Future<void> toggleNestedCard(String noteId) async {
    await crud.toggleNestedCard(noteId);
    layout.recalculate(crud.noteTree);
    notifyListeners();
  }

  /// 鍒犻櫎鑺傜偣
  Future<void> deleteNote(String noteId) async {
    await crud.deleteNote(noteId);
    layout.recalculate(crud.noteTree);
    notifyListeners();
  }

  /// 鏇存柊鑺傜偣绗旇鍐呭
  Future<void> updateNoteContent(String noteId, String newText) async {
    await crud.updateNoteContent(noteId, newText);
    notifyListeners();
  }

  // ==================== 瑙嗗彛鎿嶄綔 ====================

  /// 鏀惧ぇ
  void zoomIn() {
    viewport.zoomIn();
    notifyListeners();
  }

  /// 缂╁皬
  void zoomOut() {
    viewport.zoomOut();
    notifyListeners();
  }

  /// 璁剧疆缂╂斁
  void setZoom(double scale) {
    viewport.setZoom(scale);
    notifyListeners();
  }

  /// 骞崇Щ
  void pan(Offset delta) {
    viewport.pan(delta);
    notifyListeners();
  }

  /// 璁剧疆鍋忕Щ
  void setOffset(Offset offset) {
    viewport.setOffset(offset);
    notifyListeners();
  }

  /// 閲嶇疆瑙嗗彛
  void resetViewport() {
    viewport.reset();
    notifyListeners();
  }

  /// 閫傚簲灞忓箷
  void fitToScreen(Size screenSize, Rect contentBounds) {
    viewport.fitToScreen(screenSize, contentBounds);
    notifyListeners();
  }

  // ==================== 甯冨眬鎿嶄綔 ====================

  /// 璁剧疆鏄惁浣跨敤鏂板竷灞€寮曟搸
  void setUseNewLayoutEngine(bool value) {
    layout.setUseNewLayoutEngine(value);
    if (value) {
      layout.recalculate(crud.noteTree);
    }
    notifyListeners();
  }

  /// 璁剧疆甯冨眬鏂瑰悜
  void changeLayoutDirection(LayoutDirection dir) {
    layout.setDirection(dir);
    layout.recalculate(crud.noteTree);
    notifyListeners();
  }

  /// 璁剧疆杩炵嚎鏍峰紡
  void setConnectionStyle(ConnectionStyle style) {
    layout.setConnectionStyle(style);
    notifyListeners();
  }

  /// 璁剧疆瀵煎浘绾挎牱寮?  void setLineStyle(LineStyle style) {
    layout.setLineStyle(style);
    notifyListeners();
  }

  /// 閲嶆柊璁＄畻甯冨眬
  void recalculateLayout() {
    layout.recalculate(crud.noteTree);
    notifyListeners();
  }

  // ==================== 涓婚鎿嶄綔 ====================

  /// 鏇存柊涓婚
  Future<void> updateTheme({
    Color? canvasBgColor,
    Color? gridColor,
    bool? showGrid,
    double? gridSize,
  }) async {
    theme.update(
      canvasBgColor: canvasBgColor,
      gridColor: gridColor,
      showGrid: showGrid,
      gridSize: gridSize,
    );

    // 鎸佷箙鍖栦富棰?    if (crud.selectedTopic != null) {
      final themeJson = theme.exportToJson();
      final updatedTopic = crud.selectedTopic!.copyWith(thumbnailPath: themeJson);
      await crud.updateTopic(updatedTopic);
    }

    notifyListeners();
  }

  /// 鍒囨崲褰╄櫣鍒嗘敮棰滆壊
  void toggleRainbowBranch() {
    theme.toggleRainbowBranch();
    notifyListeners();
  }

  /// 鍒囨崲灏忓湴鍥炬樉绀?  void toggleMinimap() {
    _isMinimapVisible = !_isMinimapVisible;
    notifyListeners();
  }

  // ==================== UI 鐘舵€佹搷浣?====================

  /// 鍒囨崲渚ц竟鏍?  void toggleSidebar(SidebarTab tab) {
    if (_isSidebarExpanded && _activeSidebarTab == tab) {
      _isSidebarExpanded = false;
    } else {
      _isSidebarExpanded = true;
      _activeSidebarTab = tab;
    }
    notifyListeners();
  }

  /// 璁剧疆浜や簰妯″紡
  void setInteractMode(CanvasInteractMode mode) {
    _interactMode = mode;
    // 鍒囨崲鍒?lasso 妯″紡鏃舵竻绌哄閫夛紝鍒囨崲鍒?drag 妯″紡鏃朵繚鐣欓€変腑鑺傜偣
    if (mode == CanvasInteractMode.lasso) {
      crud.selectedNoteIds.clear();
    }
    notifyListeners();
  }

  /// 鍒囨崲閿佸畾
  void toggleLock() {
    _isLocked = !_isLocked;
    notifyListeners();
  }

  /// 璁剧疆澶氶€夎妭鐐?  void setSelectedNotes(Set<String> noteIds) {
    crud.setSelectedNotes(noteIds);
    notifyListeners();
  }

  /// 寮€濮嬬紪杈戣妭鐐?  void beginEditing(String noteId) {
    _editingNoteId = noteId;
    notifyListeners();
  }

  /// 鎻愪氦缂栬緫
  Future<void> commitEditing(String noteId, String title) async {
    if (_editingNoteId != noteId) return;
    final trimmedTitle = title.trim();
    if (trimmedTitle.isNotEmpty) {
      await updateNoteTitle(noteId, trimmedTitle);
    }
    _editingNoteId = null;
    notifyListeners();
  }

  /// 鍙栨秷缂栬緫
  void cancelEditing(String noteId) {
    if (_editingNoteId != noteId) return;
    _editingNoteId = null;
    notifyListeners();
  }

  /// 鎵撳紑鍒嗗睆
  void openSplitScreen(
    String type,
    String id,
    String title, [
    String? filePath,
  ]) {
    _splitType = type;
    _splitId = id;
    _splitTitle = title;
    _splitFilePath = filePath;
    notifyListeners();
  }

  /// 鍏抽棴鍒嗗睆
  void closeSplitScreen() {
    _splitType = null;
    _splitId = null;
    _splitTitle = null;
    _splitFilePath = null;
    notifyListeners();
  }

  // ==================== 瀵艰埅 ====================

  /// 瀵艰埅鍒板悓绾ц妭鐐?  void navigateSibling(String direction) {
    if (crud.selectedNote == null || crud.selectedTopic == null) return;
    final parentId = crud.selectedNote!.parentId;
    List<String> siblingIds = [];
    if (parentId == null) {
      siblingIds = crud.selectedTopic!.rootNoteIds;
    } else {
      final parentNode = findNoteTreeNode(crud.noteTree, parentId);
      if (parentNode != null) {
        siblingIds = parentNode.note.childIds;
      }
    }

    if (siblingIds.isEmpty) return;

    final currentIndex = siblingIds.indexOf(crud.selectedNote!.id);
    if (currentIndex == -1) return;

    int nextIndex = currentIndex;
    if (direction == 'prev') {
      nextIndex = currentIndex - 1;
      if (nextIndex < 0) nextIndex = siblingIds.length - 1;
    } else if (direction == 'next') {
      nextIndex = currentIndex + 1;
      if (nextIndex >= siblingIds.length) nextIndex = 0;
    }

    final nextNoteId = siblingIds[nextIndex];
    final nextNode = findNoteTreeNode(crud.noteTree, nextNoteId);
    if (nextNode != null) {
      selectNote(nextNode.note);
    }
  }

  /// 鎼滅储鑺傜偣
  List<NoteTreeNode> searchNodes(String query) {
    if (query.isEmpty) return [];
    final lowerQuery = query.toLowerCase();
    final results = <NoteTreeNode>[];

    void traverse(List<NoteTreeNode> nodes) {
      for (final node in nodes) {
        if (node.note.title.toLowerCase().contains(lowerQuery)) {
          results.add(node);
        }
        traverse(node.children);
      }
    }

    traverse(crud.noteTree);
    return results;
  }

  // ==================== 绉佹湁鏂规硶 ====================

  Future<void> _loadNoteTree(String topicId) async {
    await crud.refreshNoteTree();
    layout.recalculate(crud.noteTree);
    notifyListeners();
  }

  /// 鍔犺浇涓婚浠?JSON锛堝吋瀹规棫 API锛?  void loadThemeFromJson(String? jsonStr) {
    theme.loadFromJson(jsonStr);
    notifyListeners();
  }

  /// 瀵煎嚭涓婚涓?JSON锛堝吋瀹规棫 API锛?  String exportThemeToJson() => theme.exportToJson();

  /// Initialize layout from topic settings
  void _initLayoutFromTopic(Topic topic) {
    layout.setDirection(_topicValueToLayoutDirection(topic.layoutDirection));
    layout.setLayoutStyle(topic.layoutStyle);
  }
  
  /// Convert topic value to LayoutDirection
  LayoutDirection _topicValueToLayoutDirection(String value) {
    switch (value) {
      case 'left': return LayoutDirection.left;
      case 'right': return LayoutDirection.horizontal;
      default: return LayoutDirection.bothSides;
    }
  }
  
  /// Convert LayoutDirection to topic value
  String _layoutDirectionToTopicValue(LayoutDirection dir) {
    switch (dir) {
      case LayoutDirection.left: return 'left';
      case LayoutDirection.horizontal: return 'right';
      default: return 'both';
    }
  }
}
