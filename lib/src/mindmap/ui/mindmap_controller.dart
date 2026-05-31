import 'dart:convert';
import 'package:flutter/material.dart';
import '../domain/topic.dart';
import '../domain/note.dart';
import '../service/mindmap_service.dart';
import 'tree_layout.dart';

enum SidebarTab { note, style, icon }
enum CanvasInteractMode { drag, lasso }

/// MindMap UI 状态管理 Controller。
///
/// 管理笔记本列表、当前选中笔记本、节点树等 UI 状态。
/// 同时管理视口变换（缩放、平移）。
/// 遵循项目现有的 WorkspaceController 模式。
class MindMapController extends ChangeNotifier {
  final MindMapService _service;
  final String? _initialTopicId;

  MindMapController(this._service, [this._initialTopicId]);

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

  void _resetThemeToDefaults() {
    _canvasBgColor = const Color(0xFF0C0A07);
    _gridColor = const Color(0x05FAD278);
    _showGrid = true;
    _gridSize = 40.0;
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
    _isLoading = true;
    notifyListeners();

    try {
      _noteTree = await _service.getTopicTree(topicId);
    } finally {
      _isLoading = false;
      notifyListeners();
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
    _viewportScale = _min(scaleX, scaleY) * 0.9; // 留 10% 边距

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
    if (mode == CanvasInteractMode.drag) {
      _selectedNoteIds.clear();
    }
    notifyListeners();
  }

  void toggleLock() {
    _isLocked = !_isLocked;
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
          _canvasBgColor = _parseColor(theme['canvasBg']);
        }
        if (theme['gridColor'] != null) {
          _gridColor = _parseColor(theme['gridColor']);
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
        'canvasBg': _colorToHex(_canvasBgColor),
        'gridColor': _colorToRgba(_gridColor),
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

  Color _parseColor(String colorStr) {
    if (colorStr.startsWith('#')) {
      final hex = colorStr.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } else if (colorStr.startsWith('rgba')) {
      final matches = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)').firstMatch(colorStr);
      if (matches != null) {
        final r = int.parse(matches.group(1)!);
        final g = int.parse(matches.group(2)!);
        final b = int.parse(matches.group(3)!);
        final a = (double.parse(matches.group(4)!) * 255).toInt();
        return Color.fromARGB(a, r, g, b);
      }
    }
    return Colors.transparent;
  }

  String _colorToHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, "0")}';
  }

  String _colorToRgba(Color color) {
    return 'rgba(${color.red}, ${color.green}, ${color.blue}, ${(color.alpha / 255).toStringAsFixed(2)})';
  }
}

/// 辅助函数
double _min(double a, double b) => a < b ? a : b;