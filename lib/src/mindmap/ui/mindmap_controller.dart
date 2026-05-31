// lib/src/mindmap/ui/mindmap_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../domain/topic.dart';
import '../domain/note.dart';
import '../service/mindmap_service.dart';

/// MindMap UI 状态管理 Controller。
///
/// 管理笔记本列表、当前选中笔记本、节点树等 UI 状态。
/// 同时管理视口变换（缩放、平移）。
/// 遵循项目现有的 WorkspaceController 模式。
class MindMapController extends ChangeNotifier {
  final MindMapService _service;

  MindMapController(this._service);

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

  // ==================== 视口状态 ====================

  /// 视口缩放比例
  double _viewportScale = 1.0;
  double get viewportScale => _viewportScale;

  /// 视口偏移
  Offset _viewportOffset = Offset.zero;
  Offset get viewportOffset => _viewportOffset;

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
      _loadNoteTree(topic.id);
    } else {
      _noteTree = [];
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
}

/// 辅助函数
double _min(double a, double b) => a < b ? a : b;