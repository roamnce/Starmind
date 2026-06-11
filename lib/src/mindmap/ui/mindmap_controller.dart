import 'dart:convert';
import 'dart:math' show min;
import 'package:flutter/material.dart';
import '../ink/ink_layer.dart' show InkTool;
import '../domain/topic.dart';
import '../domain/note.dart';
import '../domain/note_content.dart';
import '../domain/mindmap_relation.dart';
import '../domain/mindmap_summary.dart';
import '../service/mindmap_service.dart';
import '../utils/color_utils.dart';
import '../layout/layout_engine.dart';
import '../layout/tree_layout_engine.dart';
import '../layout/layout_config.dart';
import '../layout/layout_result.dart';
import '../rendering/connection_renderer.dart';
import '../study/study_mode_controller.dart';
import '../../rust/storage/tags.dart' show TagNode;
import 'tree_layout.dart';
import 'mixins/tree_traversal.dart';

enum SidebarTab { note, search, theme, config, icon }
enum CanvasInteractMode { drag, lasso, ink }
enum LineStyle { bezier, straight, ortho }
enum RelationCreationMode { idle, choosingTarget }

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

  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

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

  /// 派生 getter：是否在手写模式
  bool get isInkMode => _interactMode == CanvasInteractMode.ink;

  /// 手写工具状态（与 interactMode 正交，可独立存）
  InkTool _inkTool = InkTool.pen;
  InkTool get inkTool => _inkTool;

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
      case LayoutDirection.left:
        return LayoutStrategy.leftOnly;
      case LayoutDirection.horizontal:
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

  /// 布局样式 (tree / framework)
  String _layoutStyle = 'tree';
  String get layoutStyle => _layoutStyle;

  /// 切换布局方向
  Future<void> changeLayoutDirection(LayoutDirection dir) async {
    _layoutDirection = dir;
    await _persistTopicLayout(
      layoutDirection: _topicValueFromLayoutDirection(dir),
    );
    recalculateLayout(); // 内部已调用 notifyListeners()
  }

  /// 切换布局样式
  Future<void> changeLayoutStyle(String style) async {
    _layoutStyle = style == 'framework' ? 'framework' : 'tree';
    await _persistTopicLayout(layoutStyle: _layoutStyle);
    recalculateLayout(); // 内部已调用 notifyListeners()
  }

  /// 同时切换布局方向和样式，单次持久化 + 单次重算。
  Future<void> changeLayout(LayoutDirection dir, String style) async {
    _layoutDirection = dir;
    _layoutStyle = style == 'framework' ? 'framework' : 'tree';
    await _persistTopicLayout(
      layoutDirection: _topicValueFromLayoutDirection(dir),
      layoutStyle: _layoutStyle,
    );
    recalculateLayout(); // 内部已调用 notifyListeners()
  }

  /// 从 topic 值转换为 LayoutDirection
  LayoutDirection _layoutDirectionFromTopicValue(String value) {
    switch (value) {
      case 'left':
        return LayoutDirection.left;
      case 'right':
        return LayoutDirection.horizontal;
      case 'both':
      default:
        return LayoutDirection.bothSides;
    }
  }

  /// 从 LayoutDirection 转换为 topic 值
  String _topicValueFromLayoutDirection(LayoutDirection direction) {
    switch (direction) {
      case LayoutDirection.left:
        return 'left';
      case LayoutDirection.horizontal:
        return 'right';
      case LayoutDirection.bothSides:
      case LayoutDirection.vertical:
        return 'both';
    }
  }

  /// 持久化 topic 布局设置。
  ///
  /// 直接使用内存中的 [_selectedTopic]，避免冗余 FFI 查询。
  Future<void> _persistTopicLayout({String? layoutDirection, String? layoutStyle}) async {
    if (_selectedTopic == null) return;
    await _service.updateTopic(_selectedTopic!.copyWith(
      layoutDirection: layoutDirection ?? _selectedTopic!.layoutDirection,
      layoutStyle: layoutStyle ?? _selectedTopic!.layoutStyle,
      updatedAt: DateTime.now(),
    ));
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
        // 从 topic 读取布局设置
        _layoutDirection = _layoutDirectionFromTopicValue(topic.layoutDirection);
        _layoutStyle = topic.layoutStyle;
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
      // 从 topic 读取布局设置
      _layoutDirection = _layoutDirectionFromTopicValue(topic.layoutDirection);
      _layoutStyle = topic.layoutStyle;
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
    if (!_disposed) notifyListeners();

    try {
      final tree = await _service.getTopicTree(topicId);
      if (session == _loadTreeSession) {
        _noteTree = tree;
      }
      // 加载关联线、概要和标签
      if (session == _loadTreeSession) {
        await _reloadRelationsForTopic();
        await _reloadSummariesForTopic();
        await _reloadTagsForTopic();
      }
      // 重新计算布局
      if (session == _loadTreeSession && useNewLayoutEngine) {
        recalculateLayout();
      }
    } finally {
      if (session == _loadTreeSession && !_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 静默加载节点树（不触发 isLoading 状态，避免 UI 闪烁）
  Future<void> _loadNoteTreeSilent(String topicId) async {
    final session = ++_loadTreeSession;

    try {
      final tree = await _service.getTopicTree(topicId);
      if (session == _loadTreeSession) {
        _noteTree = tree;
      }
      // 加载关联线、概要和标签
      if (session == _loadTreeSession) {
        await _reloadRelationsForTopic();
        await _reloadSummariesForTopic();
        await _reloadTagsForTopic();
      }
      // 重新计算布局
      if (session == _loadTreeSession && useNewLayoutEngine) {
        recalculateLayout();
      }
      // 只在最后通知一次，不触发加载状态
      if (session == _loadTreeSession && !_disposed) {
        notifyListeners();
      }
    } catch (e) {
      // 静默加载失败也不影响用户体验
      rethrow;
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
  Future<Note?> createChildNode({String? title, bool enterEditing = false}) async {
    if (_selectedNote == null || _selectedTopic == null || _isLocked) return null;
    final parentId = _selectedNote!.id;
    final childTitle = (title != null && title.trim().isNotEmpty) ? title.trim() : defaultChildNodeTitle;

    final childNote = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: childTitle,
      parentId: parentId,
    );

    await _service.addChild(parentId: parentId, childId: childNote.id);
    // 静默刷新，不触发加载状态
    await _loadNoteTreeSilent(_selectedTopic!.id);

    // 选中新节点
    final created = findNodeById(childNote.id)?.note ?? childNote;
    selectNote(created);
    if (enterEditing) beginEditing(created.id);
    return created;
  }

  /// 创建同级节点 (Enter)
  Future<Note?> createSiblingNode({String? title, bool enterEditing = false}) async {
    if (_selectedNote == null || _selectedTopic == null || _isLocked) return null;
    final parentId = _selectedNote!.parentId;
    final siblingTitle = (title != null && title.trim().isNotEmpty) ? title.trim() : defaultSiblingNodeTitle;

    final siblingNote = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: siblingTitle,
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

    // 静默刷新，不触发加载状态
    await _loadNoteTreeSilent(_selectedTopic!.id);

    // 选中新节点
    final created = findNodeById(siblingNote.id)?.note ?? siblingNote;
    selectNote(created);
    if (enterEditing) beginEditing(created.id);
    return created;
  }

  /// 选择节点
  void selectNote(Note? note) {
    _selectedNote = note;
    // 选中节点时清除概要选中
    _selectedSummaryId = null;
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

  // ==================== 原地编辑状态 ====================

  /// 在当前节点树中查找指定 ID 的节点
  NoteTreeNode? findNodeById(String noteId) {
    return findNoteTreeNode(_noteTree, noteId);
  }

  static const fallbackNodeTitle = '新节点';
  static const defaultChildNodeTitle = '新子节点';
  static const defaultSiblingNodeTitle = '新同级节点';

  String? _editingNoteId;
  final Map<String, String> _editingFallbackTitles = {};

  /// 当前正在编辑的节点 ID
  String? get editingNoteId => _editingNoteId;

  /// 开始编辑节点
  void beginEditing(String noteId) {
    final node = findNodeById(noteId);
    if (node == null || _isLocked) return;
    _editingFallbackTitles[noteId] = node.note.title.trim().isEmpty
        ? fallbackNodeTitle
        : node.note.title;
    _editingNoteId = noteId;
    selectNote(node.note);
  }

  /// 提交编辑
  Future<void> commitEditing(String noteId, String title) async {
    final node = findNodeById(noteId);
    if (node == null) return;
    final fallback = _editingFallbackTitles[noteId] ??
        (node.note.title.trim().isEmpty ? fallbackNodeTitle : node.note.title);
    final normalizedTitle = title.trim().isEmpty ? fallback : title.trim();
    await updateNoteTitle(noteId, normalizedTitle);
    _editingFallbackTitles.remove(noteId);
    _editingNoteId = null;
    final updated = findNodeById(noteId)?.note;
    if (updated != null) selectNote(updated); // 内部已调用 notifyListeners()
  }

  /// 取消编辑
  void cancelEditing(String noteId) {
    if (_editingNoteId != noteId) return;
    final node = findNodeById(noteId);
    _editingFallbackTitles.remove(noteId);
    _editingNoteId = null;
    if (node != null) selectNote(node.note); // 内部已调用 notifyListeners()
  }

  // ==================== 关联线状态 ====================

  RelationCreationMode _relationCreationMode = RelationCreationMode.idle;
  RelationCreationMode get relationCreationMode => _relationCreationMode;

  String? _relationSourceNoteId;
  String? get relationSourceNoteId => _relationSourceNoteId;

  String? _selectedRelationId;
  String? get selectedRelationId => _selectedRelationId;

  String? _transientMessage;
  String? get transientMessage => _transientMessage;

  List<MindMapRelation> _relations = [];
  List<MindMapRelation> get relations => List.unmodifiable(_relations);

  /// 开始创建关联线
  Future<void> startRelationCreation() async {
    if (_selectedNote == null) {
      _transientMessage = '创建连线前需要先选择一个起始节点';
      _relationCreationMode = RelationCreationMode.idle;
      notifyListeners();
      return;
    }
    _relationSourceNoteId = _selectedNote!.id;
    _relationCreationMode = RelationCreationMode.choosingTarget;
    _transientMessage = null;
    notifyListeners();
  }

  /// 处理关联线目标节点点击
  Future<void> handleNodeTapForRelationTarget(String targetNoteId) async {
    if (_relationCreationMode != RelationCreationMode.choosingTarget) return;
    if (_relationSourceNoteId == null) return;

    if (_relationSourceNoteId == targetNoteId) {
      _transientMessage = '不能连接到同一个节点';
      notifyListeners();
      return;
    }

    final relation = await _service.createRelation(
      topicId: _selectedTopic!.id,
      sourceNoteId: _relationSourceNoteId!,
      targetNoteId: targetNoteId,
    );

    await _reloadRelationsForTopic();
    _selectedRelationId = relation.id;
    _relationCreationMode = RelationCreationMode.idle;
    _relationSourceNoteId = null;
    _transientMessage = null;
    notifyListeners();
  }

  /// 取消关联线创建
  void cancelRelationCreation() {
    _relationCreationMode = RelationCreationMode.idle;
    _relationSourceNoteId = null;
    _transientMessage = null;
    notifyListeners();
  }

  /// 更新关联线文本
  Future<void> updateRelationText(String relationId, String text) async {
    await _service.updateRelationText(relationId, text);
    await _reloadRelationsForTopic();
    notifyListeners();
  }

  /// 删除关联线
  Future<void> deleteRelation(String relationId) async {
    await _service.deleteRelation(relationId);
    if (_selectedRelationId == relationId) {
      _selectedRelationId = null;
    }
    await _reloadRelationsForTopic();
    notifyListeners();
  }

  /// 重新加载关联线
  Future<void> _reloadRelationsForTopic() async {
    if (_selectedTopic == null) return;
    _relations = await _service.listRelations(_selectedTopic!.id);
  }

  // ==================== 概要状态 ====================

  List<MindMapSummary> _summaries = [];
  List<MindMapSummary> get summaries => List.unmodifiable(_summaries);

  String? _selectedSummaryId;
  String? get selectedSummaryId => _selectedSummaryId;

  /// 选中概要
  void selectSummary(String? summaryId) {
    _selectedSummaryId = summaryId;
    // 选中概要时清除节点选中
    if (summaryId != null) {
      _selectedNote = null;
      _selectedNoteIds.clear();
    }
    notifyListeners();
  }

  /// 从选中节点创建概要
  Future<void> createSummariesFromSelection() async {
    if (_selectedTopic == null || _selectedNoteIds.isEmpty) return;
    await _service.createSummariesFromSelectedNoteIds(
      topicId: _selectedTopic!.id,
      selectedNoteIds: _selectedNoteIds,
    );
    await _reloadSummariesForTopic();
    notifyListeners();
  }

  /// 更新概要文本
  Future<void> updateSummaryText(String summaryId, String text) async {
    await _service.updateSummaryText(summaryId, text);
    await _reloadSummariesForTopic();
    notifyListeners();
  }

  /// 删除概要
  Future<void> deleteSummary(String summaryId) async {
    await _service.deleteSummary(summaryId);
    if (_selectedSummaryId == summaryId) {
      _selectedSummaryId = null;
    }
    await _reloadSummariesForTopic();
    notifyListeners();
  }

  /// 重新加载概要
  Future<void> _reloadSummariesForTopic() async {
    if (_selectedTopic == null) return;
    _summaries = await _service.listSummaries(_selectedTopic!.id);
  }

  // ==================== 节点标签状态 ====================

  final Map<String, List<String>> _tagIdsByNoteId = {};
  Map<String, List<String>> get tagIdsByNoteId => Map.unmodifiable(_tagIdsByNoteId);

  /// 节点绑定的完整标签信息（noteId -> List<TagNode>）
  final Map<String, List<TagNode>> _tagsByNoteId = {};
  Map<String, List<TagNode>> get tagsByNoteId => Map.unmodifiable(_tagsByNoteId);

  /// 全局 Tag 树（用于查找标签信息）
  TagNode? _tagTree;
  TagNode? get tagTree => _tagTree;

  /// 初始化 Tag 树
  Future<void> _initTagTree() async {
    try {
      _tagTree = await _service.getTagTree();
    } catch (_) {
      _tagTree = null;
    }
  }

  /// 在 Tag 树中查找指定 ID 的标签
  TagNode? _findTagById(String tagId, TagNode? root) {
    if (root == null) return null;
    if (root.id == tagId) return root;
    for (final child in root.children) {
      final found = _findTagById(tagId, child);
      if (found != null) return found;
    }
    return null;
  }

  /// 在 Tag 树中查找指定名称的标签
  TagNode? _findTagByName(String name, TagNode? root) {
    if (root == null) return null;
    if (root.name == name) return root;
    for (final child in root.children) {
      final found = _findTagByName(name, child);
      if (found != null) return found;
    }
    return null;
  }

  /// 绑定标签到选中节点
  ///
  /// 如果 tagName 不存在于全局 Tag 树，先创建新标签再绑定。
  Future<void> bindTagToSelectedNode(String tagName) async {
    final note = _selectedNote;
    if (note == null) {
      _transientMessage = '创建标签前需要先选择节点';
      notifyListeners();
      return;
    }

    // 确保已加载 Tag 树
    if (_tagTree == null) {
      await _initTagTree();
    }

    // 查找或创建标签
    var tag = _findTagByName(tagName, _tagTree);
    if (tag == null) {
      // 创建新标签（无父节点，颜色根据名称哈希生成）
      final colorHex = _generateColorFromName(tagName);
      final tagId = await _service.createTag(tagName, null, colorHex);
      // 重新加载 Tag 树
      await _initTagTree();
      tag = _findTagById(tagId, _tagTree);
    }

    if (tag == null) return;

    await _service.bindTagToNote(noteId: note.id, tagId: tag.id);
    await _reloadTagsForTopic();
    notifyListeners();
  }

  /// 根据名称生成颜色（简单哈希）
  String _generateColorFromName(String name) {
    final hash = name.hashCode;
    final colors = ['#FF6B6B', '#FF9F43', '#FFD93D', '#6BCB77', '#4D96FF', '#9B59B6'];
    final index = (hash.abs()) % colors.length;
    return colors[index];
  }

  /// 解绑节点标签
  Future<void> unbindTagFromNode(String noteId, String tagId) async {
    await _service.unbindTagFromNote(noteId: noteId, tagId: tagId);
    await _reloadTagsForTopic();
    notifyListeners();
  }

  /// 重新加载标签。
  ///
  /// 使用单次批量查询替代逐节点 N+1 查询。
  Future<void> _reloadTagsForTopic() async {
    if (_selectedTopic == null) return;

    if (_tagTree == null) {
      await _initTagTree();
    }

    // 单次 FFI 调用获取所有节点的标签绑定
    final allTagIds = await _service.listTagIdsForTopic(_selectedTopic!.id);
    _tagIdsByNoteId.clear();
    _tagsByNoteId.clear();

    for (final entry in allTagIds.entries) {
      _tagIdsByNoteId[entry.key] = entry.value;
      final tags = entry.value
          .map((tagId) => _findTagById(tagId, _tagTree))
          .whereType<TagNode>()
          .toList();
      if (tags.isNotEmpty) {
        _tagsByNoteId[entry.key] = tags;
      }
    }
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

  /// 设置手写工具
  void setInkTool(InkTool tool) {
    _inkTool = tool;
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
