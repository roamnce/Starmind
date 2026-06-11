import 'package:flutter/foundation.dart';
import '../../domain/topic.dart';
import '../../domain/note.dart';
import '../../domain/note_content.dart';
import '../../service/mindmap_service.dart';

/// Topic 和 Note CRUD 操作。
///
/// 管理笔记本和节点的创建、读取、更新、删除。
/// 深度模块：业务逻辑和状态同步隐藏在接口背后。
class MindMapCrudController extends ChangeNotifier {
  final MindMapService _service;

  MindMapCrudController({required MindMapService service}) : _service = service;

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

  /// 多选节点 ID
  final Set<String> selectedNoteIds = {};

  /// 加载状态
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  int _loadTreeSession = 0;

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

  /// 加载指定笔记本
  Future<void> loadTopic(String topicId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final topic = await _service.getTopic(topicId);
      if (topic != null) {
        _selectedTopic = topic;
        _topics = [topic];
        await _loadNoteTree(topic.id);
      }
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

  /// 更新笔记本
  Future<void> updateTopic(Topic topic) async {
    await _service.updateTopic(topic);
    _selectedTopic = topic;

    final index = _topics.indexWhere((t) => t.id == topic.id);
    if (index != -1) {
      _topics[index] = topic;
    }
    notifyListeners();
  }

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
    } finally {
      if (session == _loadTreeSession) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  /// 刷新当前笔记本的节点树
  Future<void> refreshNoteTree() async {
    if (_selectedTopic == null) return;
    await _loadNoteTree(_selectedTopic!.id);
  }

  /// 创建节点
  Future<Note> createNote({required String title, String? parentId}) async {
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
      await _service.addRootNote(topicId: _selectedTopic!.id, noteId: note.id);
    } else {
      await _service.addChild(parentId: parentId, childId: note.id);
    }

    await _loadNoteTree(_selectedTopic!.id);
    return note;
  }

  /// 创建子节点
  Future<Note?> createChildNode({String? title}) async {
    if (_selectedNote == null || _selectedTopic == null) return null;
    final parentId = _selectedNote!.id;
    final nodeTitle = title?.trim().isEmpty == true ? '新子节点' : title!.trim();

    final childNote = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: nodeTitle,
      parentId: parentId,
    );

    await _service.addChild(parentId: parentId, childId: childNote.id);
    await _loadNoteTree(_selectedTopic!.id);

    selectNote(childNote);
    return childNote;
  }

  /// 创建同级节点
  Future<Note?> createSiblingNode({String? title}) async {
    if (_selectedNote == null || _selectedTopic == null) return null;
    final parentId = _selectedNote!.parentId;
    final nodeTitle = title?.trim().isEmpty == true ? '新同级节点' : title!.trim();

    final siblingNote = await _service.createNote(
      topicId: _selectedTopic!.id,
      title: nodeTitle,
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

    selectNote(siblingNote);
    return siblingNote;
  }

  /// 选择节点
  void selectNote(Note? note) {
    _selectedNote = note;
    if (note != null) {
      selectedNoteIds.clear();
      selectedNoteIds.add(note.id);
    } else {
      selectedNoteIds.clear();
    }
    notifyListeners();
  }

  /// 设置多选节点
  void setSelectedNotes(Set<String> noteIds) {
    selectedNoteIds.clear();
    selectedNoteIds.addAll(noteIds);
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

    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  /// 更新节点笔记内容
  Future<void> updateNoteContent(String noteId, String newText) async {
    final note = await _service.getNote(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(
      content: NoteContent(
        segments: [Segment(type: SegmentType.text, text: newText)],
      ),
      updatedAt: DateTime.now(),
    );
    await _service.updateNote(updatedNote);

    if (_selectedNote?.id == noteId) {
      _selectedNote = updatedNote;
    }

    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  /// 切换节点折叠状态
  Future<void> toggleNoteCollapse(String noteId) async {
    final note = await _service.getNote(noteId);
    if (note == null) return;

    final updatedNote = note.copyWith(
      isCollapsed: !note.isCollapsed,
      updatedAt: DateTime.now(),
    );
    await _service.updateNote(updatedNote);

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

    if (_selectedTopic != null) {
      await _loadNoteTree(_selectedTopic!.id);
    }
  }

  /// 导出为 GuruMind 格式
  Future<void> exportGuruMind(String outputPath) async {
    if (_selectedTopic == null) {
      throw StateError('No topic selected');
    }
    await _service.exportGuruMindTopic(
      topicId: _selectedTopic!.id,
      outputPath: outputPath,
    );
  }
}
