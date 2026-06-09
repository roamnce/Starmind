import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../domain/topic.dart';
import '../domain/note.dart';
import '../domain/note_content.dart';
import '../service/mindmap_service.dart';
import '../utils/color_utils.dart';
import '../layout/layout_engine.dart';
import '../layout/tree_layout_engine.dart';
import '../layout/layout_config.dart';
import '../layout/layout_result.dart';
import '../rendering/connection_renderer.dart';
import '../study/study_mode_controller.dart';
import 'tree_layout.dart';
import 'mixins/tree_traversal.dart';

enum SidebarTab { note, search, theme, config, icon }
enum CanvasInteractMode { drag, lasso }
enum LineStyle { bezier, straight, ortho }

/// MindMap UI 状态管理 Controller。
///
/// 管理笔记本列表、当前选中笔记本、节点树等 UI 状态。
/// 同时管理视口变换（缩放、平移）。
/// 遵循项目现有的 WorkspaceController 模式。
class MindMapController extends ChangeNotifier with TreeTraversal {
  final MindMapService _service;
  final String? _initialTopicId;

  MindMapController(this._service, [this._initialTopicId]);

  late final StudyModeController studyModeController = StudyModeController(service: _service);

  // ==================== 状态 ====================

  /// 所有笔记本列表
  List<Topic> _topics = [];
  List<Topic> get topics => List.unmodifiable(_topics);

  /// 当前选中的笔记本
  Topic? _selectedTopic;
  Topic? get selectedTopic => _selectedTopic;

  /// 当前笔记本的节点树
  List<NoteTreeNode> _noteTree = [];
  List<NoteTreeNode> get noteTree => List.unmodifiable(_noteTree);

  /// 选中的节点
  Note? _selectedNote;
  Note? get selectedNote => _selectedNote;

  /// 加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  int _loadTreeSession = 0;

  // ==================== UI & 主题状态 ====================

  bool _isSidebarExpanded = false;
  bool get isSidebarExpanded => _isSidebarExpanded;

  SidebarTab _activeSidebarTab = SidebarTab.note;
  SidebarTab get activeSidebarTab => _activeSidebarTab;

  CanvasInteractMode _interactMode = CanvasInteractMode.drag;
  CanvasInteractMode get interactMode => _interactMode;

  bool _isLocked = false;
  bool get isLocked => _isLocked;

  final Set<String> _selectedNoteIds = {};
  Set<String> get selectedNoteIds => _selectedNoteIds;

  Color _canvasBgColor = const Color(0xFF0C0A07);
  Color get canvasBgColor => _canvasBgColor;

  Color _gridColor = const Color(0x05FAD278);
  Color get gridColor => _gridColor;

  bool _showGrid = true;
  bool get showGrid => _showGrid;

  double _gridSize = 40.0;
  double get gridSize => _gridSize;

  // 小地图显示状态
  bool _isMinimapVisible = false;
  bool get isMinimapVisible => _isMinimapVisible;

  // 彩虹分支颜色开关
  bool _isRainbowBranch = false;
  bool get isRainbowBranch => _isRainbowBranch;

  // 导图线样式
  LineStyle _lineStyle = LineStyle.bezier;
  LineStyle get lineStyle => _lineStyle;

  void _resetThemeToDefaults() {
    _canvasBgColor = const Color(0xFF0C0A07);
    _gridColor = const Color(0x05FAD278);
    _showGrid = true;
    _gridSize = 40.0;
    _isRainbowBranch = false;
    _lineStyle = LineStyle.bezier;
  }

  // ==================== 新布局引擎 ====================

  /// 布局引擎实例
  final LayoutEngine _layoutEngine = const TreeLayoutEngine();

  /// 是否使用新布局引擎（开关）
  bool useNewLayoutEngine = true;

  /// 缓存的布局结果
  LayoutResult? _cachedLayoutResult;

  /// 获取布局结果
  LayoutResult? get layoutResult => _cachedLayoutResult;

  /// 连线样式
  ConnectionStyle _connectionStyle = ConnectionStyle.bezier;
  ConnectionStyle get connectionStyle => _connectionStyle;

  /// 设置连线样式
  void setConnectionStyle(ConnectionStyle style) {
    _connectionStyle = style;
    notifyListeners();
  }

  /// 重新计算布局
  void recalculateLayout() {
    if (_selectedTopic == null || _noteTree.isEmpty) {
      _cachedLayoutResult = null;
      return;
    }

    if (!useNewLayoutEngine) {
      return;
    }

    final config = LayoutConfig(
      strategy: _layoutDirectionToStrategy(_layoutDirection),
      nodeWidth: 120.0,
      nodeHeight: 40.0,
      horizontalSpacing: 60.0,
      verticalSpacing: 30.0,
    );

    _cachedLayoutResult = _layoutRoots(_noteTree, config);

    notifyListeners();
  }

  LayoutResult _layoutRoots(List<NoteTreeNode> roots, LayoutConfig config) {
    if (roots.isEmpty) return LayoutResult.empty;
    if (roots.length == 1) return _layoutEngine.layout(roots.first, config);

    final positions = <String, Offset>{};
    final sizes = <String, Size>{};
    final connections = <ConnectionData>[];
    var nextX = 0.0;
    Rect? mergedBounds;

    for (final root in roots) {
      final result = _layoutEngine.layout(root, config);
      final rootShift = Offset(nextX - result.contentBounds.left, 0);

      for (final entry in result.nodePositions.entries) {
        positions[entry.key] = entry.value + rootShift;
      }
      sizes.addAll(result.nodeSizes);
      connections.addAll(result.connections.map((connection) {
        return ConnectionData(
          fromId: connection.fromId,
          toId: connection.toId,
          startPoint: connection.startPoint + rootShift,
          endPoint: connection.endPoint + rootShift,
          fromCenter: connection.fromCenter + rootShift,
          toCenter: connection.toCenter + rootShift,
        );
      }));

      final shiftedBounds = result.contentBounds.shift(rootShift);
      mergedBounds = mergedBounds == null ? shiftedBounds : mergedBounds.expandToInclude(shiftedBounds);
      nextX = shiftedBounds.right + config.horizontalSpacing;
    }

    return LayoutResult(
      nodePositions: positions,
      nodeSizes: sizes,
      connections: connections,
      contentBounds: mergedBounds ?? Rect.zero,
    );
  }

  /// 转换布局方向到策略
  LayoutStrategy _layoutDirectionToStrategy(LayoutDirection direction) {
    switch (direction) {
      case LayoutDirection.bothSides:
        return LayoutStrategy.bothSides;
      case LayoutDirection.horizontal:
      case LayoutDirection.left:
        return LayoutStrategy.rightOnly;
      case LayoutDirection.vertical:
        return LayoutStrategy.rightOnly;
    }
  }

  // ==================== 双视口分屏状态 ====================

  String? _splitType;
  String? get splitType => _splitType;

  String? _splitId;
  String? get splitId => _splitId;

  String? _splitTitle;
  String? get splitTitle => _splitTitle;

  String? _splitFilePath;
  String? get splitFilePath => _splitFilePath;

  void openSplitScreen(String type, String id, String title, [String? filePath]) {
    _splitType = type;
    _splitId = id;
    _splitTitle = title;
    _splitFilePath = filePath;
    notifyListeners();
  }

  void closeSplitScreen() {
    _splitType = null;
    _splitId = null;
    _splitTitle = null;
    _splitFilePath = null;
    notifyListeners();
  }



  // ==================== 视口状态 ====================

  /// 视口缩放比例
  double _viewportScale = 1.0;
  double get viewportScale => _viewportScale;

  /// 视口偏移
  Offset _viewportOffset = Offset.zero;
  Offset get viewportOffset => _viewportOffset;

  /// 布局方向
  LayoutDirection _layoutDirection = LayoutDirection.bothSides;
  LayoutDirection get layoutDirection => _layoutDirection;

  void changeLayoutDirection(LayoutDirection dir) {
    _layoutDirection = dir;
    notifyListeners();
  }

  /// 缩放限制
  static const double minScale = 0.1;
  static const double maxScale = 4.0;
  static const double zoomStep = 1.2;

  // ==================== Topic 操作 ====================

  /// 加载所有笔记本
  Future<void> loadTopics() async {
    _isLoading = true;
    notifyListeners();

    try {
      _topics = await _service.getAllTopics();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 获取所有笔记本
  Future<List<Topic>> getAllTopics() => _service.getAllTopics();

  Future<Topic?> importGuruMindFile(String filePath) async {
    final result = await _service.importGuruMindFile(filePath);
    if (!result.isSuccess || result.topic == null) {
      throw result.error ?? StateError('GuruMind import failed');
    }
    await loadTopics();
    selectTopic(result.topic);
    return result.topic;
  }

  Future<void> exportCurrentTopicAsGuruMind(String outputPath) async {
    final topic = _selectedTopic;
    if (topic == null) {
      throw StateError('No topic selected');
    }
    await _service.exportGuruMindTopic(topicId: topic.id, outputPath: outputPath);
  }

  /// Load a specific topic by ID (for tab-based navigation)
  Future<void> loadTopic() async {
    if (_initialTopicId == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final topic = await _service.getTopic(_initialTopicId);
      if (topic != null) {
        _selectedTopic = topic;
        _topics = [topic]; // Single topic mode
        if (topic.thumbnailPath != null && topic.thumbnailPath!.startsWith('{"theme":')) {
          loadThemeFromJson(topic.thumbnailPath);
        } else {
          _resetThemeToDefaults();
        }
        await _loadNoteTree(topic.id);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a node to the current topic (simplified API for UI)
  Future<void> addNode(String title) async {
    if (_selectedTopic == null) return;

    final note = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: title,
    );

    // Add as root node
    await _service.addRootNote(
      topicId: _selectedTopic!.id,
      noteId: note.id,
    );

    // Refresh tree
    await _loadNoteTree(_selectedTopic!.id);
  }

  /// 创建笔记本
  Future<Topic> createTopic(String title, {String? author}) async {
    final topic = await _service.createTopic(title, author: author);
    _topics = [..._topics, topic];
    _selectedTopic = topic;
    notifyListeners();
    return topic;
  }

  /// 选择笔记本
  void selectTopic(Topic? topic) {
    _selectedTopic = topic;
    _selectedNote = null;
    notifyListeners();

    if (topic != null) {
      if (topic.thumbnailPath != null && topic.thumbnailPath!.startsWith('{"theme":')) {
        loadThemeFromJson(topic.thumbnailPath);
      } else {
        _resetThemeToDefaults();
      }
      _loadNoteTree(topic.id);
    } else {
      _noteTree = [];
      _resetThemeToDefaults();
      notifyListeners();
    }
  }

  /// 软删除笔记本
  Future<void> trashTopic(String id) async {
    await _service.trashTopic(id);
    _topics = _topics.where((t) => t.id != id).toList();

    if (_selectedTopic?.id == id) {
      _selectedTopic = null;
      _noteTree = [];
    }
    notifyListeners();
  }

  // ==================== Note 操作 ====================

  /// 加载笔记本的节点树
  Future<void> _loadNoteTree(String topicId) async {
    final session = ++_loadTreeSession;
    _isLoading = true;
    notifyListeners();

    try {
      final tree = await _service.getTopicTree(topicId);
      if (session == _loadTreeSession) {
        _noteTree = tree;
      }
      // 重新计算布局
      if (session == _loadTreeSession && useNewLayoutEngine) {
        recalculateLayout();
      }
    } finally {
      if (session == _loadTreeSession) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 创建节点
  Future<Note> createNote({
    required String title,
    String? parentId,
  }) async {
    if (_selectedTopic == null) {
      throw StateError('No topic selected');
    }

    final note = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: title,
      parentId: parentId,
    );

    // 如果没有父节点，添加为根节点
    if (parentId == null) {
      await _service.addRootNote(
        topicId: _selectedTopic!.id,
        noteId: note.id,
      );
    } else {
      await _service.addChild(parentId: parentId, childId: note.id);
    }

    // 刷新节点树
    await _loadNoteTree(_selectedTopic!.id);
    return note;
  }

  /// 创建子节点 (Tab)
  Future<Note?> createChildNode({required String title}) async {
    if (_selectedNote == null || _selectedTopic == null) return null;
    final parentId = _selectedNote!.id;

    final childNote = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: title,
      parentId: parentId,
    );

    await _service.addChild(parentId: parentId, childId: childNote.id);
    await _loadNoteTree(_selectedTopic!.id);
    
    // 选中新节点
    selectNote(childNote);
    return childNote;
  }

  /// 创建同级节点 (Enter)
  Future<Note?> createSiblingNode({required String title}) async {
    if (_selectedNote == null || _selectedTopic == null) return null;
    final parentId = _selectedNote!.parentId; // 同级拥有相同的父 ID

    final siblingNote = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: title,
      parentId: parentId,
    );

    if (parentId == null) {
      await _service.addRootNote(
        topicId: _selectedTopic!.id,
        noteId: siblingNote.id,
      );
    } else {
      await _service.addChild(parentId: parentId, childId: siblingNote.id);
    }

    await _loadNoteTree(_selectedTopic!.id);
    
    // 选中新节点
    selectNote(siblingNote);
    return siblingNote;
  }

  /// 选择节点
  void selectNote(Note? note) {
    _selectedNote = note;
    if (note == null) {
      _selectedNoteIds.clear();
    } else if (_interactMode == CanvasInteractMode.drag) {
      _selectedNoteIds
        ..clear()
        ..add(note.id);
    } else if (_interactMode == CanvasInteractMode.lasso) {
      _selectedNoteIds.add(note.id);
    } else {
      _selectedNoteIds
        ..clear()
        ..add(note.id);
    }
    notifyListeners();
  }

  /// 更新节点标题
  Future<void> updateNoteTitle(String noteId, String newTitle) async {
    final note = await _service.getNote(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );
    await _service.updateNote(updatedNote);

    // 刷新节点树
    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  /// 切换节点折叠状态
  Future<void> toggleNodeCollapse(String noteId) async {
    final note = await _service.getNote(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(
      isCollapsed: !note.isCollapsed,
      updatedAt: DateTime.now(),
    );
    await _service.updateNote(updatedNote);

    // 刷新节点树
    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  /// 切换嵌套卡片组容器状态
  Future<void> toggleNestedCard(String noteId) async {
    final note = await _service.getNote(noteId);
    if (note == null) return;

    final isNested = note.highlightStyle == 'nestedCard';
    final updatedNote = note.copyWith(
      highlightStyle: isNested ? '' : 'nestedCard',
      updatedAt: DateTime.now(),
    );
    await _service.updateNote(updatedNote);

    // 刷新节点树
    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  /// 删除节点
  Future<void> deleteNote(String noteId) async {
    await _service.deleteNote(noteId);

    if (_selectedNote?.id == noteId) {
      _selectedNote = null;
    }

    // 刷新节点树
    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  // ==================== 视口操作 ====================

  /// 放大
  void zoomIn() {
    _viewportScale = (_viewportScale * zoomStep).clamp(minScale, maxScale);
    notifyListeners();
  }

  /// 缩小
  void zoomOut() {
    _viewportScale = (_viewportScale / zoomStep).clamp(minScale, maxScale);
    notifyListeners();
  }

  /// 设置缩放
  void setZoom(double scale) {
    _viewportScale = scale.clamp(minScale, maxScale);
    notifyListeners();
  }

  /// 平移
  void pan(Offset delta) {
    _viewportOffset = _viewportOffset + delta;
    notifyListeners();
  }

  /// 设置偏移
  void setOffset(Offset offset) {
    _viewportOffset = offset;
    notifyListeners();
  }

  /// 重置视口
  void resetViewport() {
    _viewportScale = 1.0;
    _viewportOffset = Offset.zero;
    notifyListeners();
  }

  /// 适应屏幕（根据边界框计算合适的缩放）
  void fitToScreen(Size screenSize, Rect contentBounds) {
    if (contentBounds.isEmpty) return;

    final scaleX = screenSize.width / contentBounds.width;
    final scaleY = screenSize.height / contentBounds.height;
    _viewportScale = min(scaleX, scaleY) * 0.9; // 留 10% 边距

    // 确保缩放比例在有效范围内
    _viewportScale = _viewportScale.clamp(minScale, maxScale);

    // 居中
    _viewportOffset = Offset(
      (screenSize.width - contentBounds.width * _viewportScale) / 2,
      (screenSize.height - contentBounds.height * _viewportScale) / 2,
    );

    notifyListeners();
  }

  void toggleSidebar(SidebarTab tab) {
    if (_isSidebarExpanded && _activeSidebarTab == tab) {
      _isSidebarExpanded = false;
    } else {
      _isSidebarExpanded = true;
      _activeSidebarTab = tab;
    }
    notifyListeners();
  }

  void setInteractMode(CanvasInteractMode mode) {
    _interactMode = mode;
    // Preserve selection when switching modes
    notifyListeners();
  }

  void toggleLock() {
    _isLocked = !_isLocked;
    notifyListeners();
  }

  /// 切换小地图显示
  void toggleMinimap() {
    _isMinimapVisible = !_isMinimapVisible;
    notifyListeners();
  }

  /// 切换彩虹分支颜色
  void toggleRainbowBranch() {
    _isRainbowBranch = !_isRainbowBranch;
    notifyListeners();
  }

  /// 设置导图线样式
  void setLineStyle(LineStyle style) {
    _lineStyle = style;
    notifyListeners();
  }

  void setSelectedNotes(Set<String> noteIds) {
    _selectedNoteIds.clear();
    _selectedNoteIds.addAll(noteIds);
    notifyListeners();
  }

  void loadThemeFromJson(String? jsonStr) {
    if (jsonStr == null || !jsonStr.startsWith('{"theme":')) return;
    try {
      final data = jsonDecode(jsonStr);
      final theme = data['theme'];
      if (theme != null) {
        if (theme['canvasBg'] != null) {
          _canvasBgColor = ColorUtils.parseColor(theme['canvasBg']);
        }
        if (theme['gridColor'] != null) {
          _gridColor = ColorUtils.parseColor(theme['gridColor']);
        }
        if (theme['gridShow'] != null) {
          _showGrid = theme['gridShow'] as bool;
        }
        if (theme['gridSize'] != null) {
          _gridSize = (theme['gridSize'] as num).toDouble();
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  String exportThemeToJson() {
    final themeData = {
      'theme': {
        'canvasBg': ColorUtils.toHex(_canvasBgColor),
        'gridColor': ColorUtils.toRgba(_gridColor),
        'gridShow': _showGrid,
        'gridSize': _gridSize,
      }
    };
    return jsonEncode(themeData);
  }

  Future<void> updateTheme({
    Color? canvasBgColor,
    Color? gridColor,
    bool? showGrid,
    double? gridSize,
  }) async {
    if (canvasBgColor != null) _canvasBgColor = canvasBgColor;
    if (gridColor != null) _gridColor = gridColor;
    if (showGrid != null) _showGrid = showGrid;
    if (gridSize != null) _gridSize = gridSize;

    notifyListeners();

    if (_selectedTopic != null) {
      final themeJson = exportThemeToJson();
      final updatedTopic = _selectedTopic!.copyWith(thumbnailPath: themeJson);
      _selectedTopic = updatedTopic;
      await _service.updateTopic(updatedTopic);

      // Also update the topic list if it exists
      final index = _topics.indexWhere((t) => t.id == updatedTopic.id);
      if (index != -1) {
        _topics[index] = updatedTopic;
      }
      notifyListeners();
    }
  }

  /// 更新节点笔记内容 (plainText)
  Future<void> updateNoteContent(String noteId, String newText) async {
    final note = await _service.getNote(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(
      content: NoteContent(segments: [
        Segment(type: SegmentType.text, text: newText),
      ]),
      updatedAt: DateTime.now(),
    );
    await _service.updateNote(updatedNote);

    // Update local _selectedNote if it is the one being updated
    if (_selectedNote?.id == noteId) {
      _selectedNote = updatedNote;
    }

    // Refresh tree
    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  /// 导航到同级节点
  void navigateSibling(String direction) {
    if (_selectedNote == null || _selectedTopic == null) return;
    final parentId = _selectedNote!.parentId;
    List<String> siblingIds = [];
    if (parentId == null) {
      siblingIds = _selectedTopic!.rootNoteIds;
    } else {
      // Find parent note in tree to get childIds
      final parentNode = findNoteTreeNode(_noteTree, parentId);
      if (parentNode != null) {
        siblingIds = parentNode.note.childIds;
      }
    }

    if (siblingIds.isEmpty) return;

    final currentIndex = siblingIds.indexOf(_selectedNote!.id);
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
    // Find the note object
    final nextNode = findNoteTreeNode(_noteTree, nextNoteId);
    if (nextNode != null) {
      selectNote(nextNode.note);
    }
  }

  /// 搜索节点
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

    traverse(_noteTree);
    return results;
  }
}
