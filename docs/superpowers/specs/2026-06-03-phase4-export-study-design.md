# 阶段4：导出与刷题优化设计文档

> 版本：1.0
> 日期：2026-06-03
> 状态：设计中

---

## 1. 目标与范围

### 1.1 核心目标

1. **GuruMind 导出** - 将 Starmind 导图导出为 `.gurumind` 格式，实现双向兼容
2. **刷题工作流优化** - 优化节点笔记中的图片+手写组合，提升刷题体验

### 1.2 用户场景

**场景 1：导出兼容**
- 用户在 Starmind 中编辑导图后，导出为 `.gurumind` 文件
- 可以在 GuruMind 中打开并继续编辑

**场景 2：刷题练习**
- 用户在节点笔记中嵌入题目图片
- 在图片上直接手写答案
- 使用快捷键切换节点，快速刷题

### 1.3 成功标准

- ✅ 导出的 `.gurumind` 文件可在 GuruMind 中正确打开
- ✅ 节点笔记支持图片+手写叠加显示
- ✅ 刷题模式支持快捷键导航

---

## 2. GuruMind 导出设计

### 2.1 导出流程

```
┌─────────────────────────────────────────────────────────────────────┐
│                    用户点击导出按钮                                   │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    1. 收集导图数据                                   │
│                    Topic + Notes + InkLayers                        │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    2. 数据转换                                        │
│                    Starmind → GuruMind 数据模型映射                   │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    3. Hive 编码                                       │
│                    节点数据 → Hive 二进制格式                         │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    4. 资源复制                                        │
│                    图片资源复制到 assets 目录                         │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    5. 元数据生成                                      │
│                    创建 manifest.json 和 meta.json                   │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    6. ZIP 打包                                        │
│                    将所有文件打包为 .gurumind 文件                    │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    7. 保存文件                                        │
│                    用户选择保存位置                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### 2.2 核心组件

#### 2.2.1 GuruMindDataExporter（数据导出器）

```dart
/// GuruMind 数据导出器
class GuruMindDataExporter {
  final MindMapService _service;

  GuruMindDataExporter(this._service);

  /// 导出导图为 GuruMind 格式
  Future<String> export(String topicId, String outputPath) async {
    // 1. 收集数据
    final topic = await _service.getTopic(topicId);
    if (topic == null) throw Exception('Topic not found');

    final notes = await _service.getAllNotes(topicId);

    // 2. 创建临时目录
    final tempDir = await getTemporaryDirectory();
    final exportPath = path.join(
      tempDir.path,
      'gurumind_export_${DateTime.now().millisecondsSinceEpoch}',
    );
    await Directory(exportPath).create(recursive: true);

    try {
      // 3. 创建目录结构
      final documentsPath = path.join(exportPath, 'documents', topic.id);
      final assetsPath = path.join(documentsPath, 'assets');
      await Directory(assetsPath).create(recursive: true);

      // 4. 导出节点数据为 Hive
      await _exportNotesAsHive(notes, documentsPath);

      // 5. 复制资源文件
      await _exportAssets(notes, assetsPath);

      // 6. 生成元数据
      await _generateManifest(topic, exportPath);
      await _generateMetaJson(topic, documentsPath);

      // 7. 打包 ZIP
      final zipPath = await _zipDirectory(exportPath, outputPath);

      return zipPath;
    } finally {
      // 清理临时目录
      await Directory(exportPath).delete(recursive: true);
    }
  }

  /// 导出节点为 Hive 文件
  Future<void> _exportNotesAsHive(List<Note> notes, String documentsPath) async {
    final encoder = HiveEncoder();

    for (final note in notes) {
      // 创建节点目录
      final notePath = path.join(documentsPath, note.id);
      await Directory(notePath).create(recursive: true);

      // 编码为 Hive
      final hiveBytes = encoder.encodeNote(note);

      // 写入文件
      final hivePath = path.join(notePath, 'doc_${note.id}.hive');
      await File(hivePath).writeAsBytes(hiveBytes);
    }
  }

  /// 复制资源文件
  Future<void> _exportAssets(List<Note> notes, String assetsPath) async {
    for (final note in notes) {
      if (note.content == null) continue;

      for (final segment in note.content!.segments) {
        if (segment.type == SegmentType.image && segment.path != null) {
          final sourcePath = segment.path!;
          if (await File(sourcePath).exists()) {
            final targetPath = path.join(assetsPath, path.basename(sourcePath));
            await File(sourcePath).copy(targetPath);
          }
        }
      }
    }
  }

  /// 生成 manifest.json
  Future<void> _generateManifest(Topic topic, String exportPath) async {
    final manifest = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'documentCount': 1,
      'documents': [
        {
          'id': topic.id,
          'type': 'mindMap',
          'title': topic.title,
        }
      ],
      'tags': [],  // TODO: 导出标签
    };

    final manifestPath = path.join(exportPath, 'manifest.json');
    await File(manifestPath).writeAsString(jsonEncode(manifest));
  }

  /// 生成 meta.json
  Future<void> _generateMetaJson(Topic topic, String documentsPath) async {
    final meta = {
      'id': topic.id,
      'title': topic.title,
      'type': 'mindMap',
      'createdAt': topic.createdAt.toIso8601String(),
      'updatedAt': topic.updatedAt.toIso8601String(),
      'thumbnailPath': topic.thumbnailPath,
      'linkedIds': [],
    };

    final metaPath = path.join(documentsPath, 'meta.json');
    await File(metaPath).writeAsString(jsonEncode(meta));
  }

  /// 打包 ZIP
  Future<String> _zipDirectory(String sourcePath, String outputPath) async {
    final archive = Archive();

    await for (final entity in Directory(sourcePath).list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: sourcePath);
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    await File(outputPath).writeAsBytes(zipBytes!);

    return outputPath;
  }
}
```

#### 2.2.2 HiveEncoder（Hive 编码器）

```dart
/// Hive 二进制编码器
class HiveEncoder {
  /// 编码 Note 为 Hive 格式
  Uint8List encodeNote(Note note) {
    final builder = BytesBuilder();

    // 写入魔数
    builder.write(Uint8List.fromList([0xFA, 0x42, 0x00, 0x00]));

    // 写入类型标识符
    _writeString(builder, 'document');

    // 写入字段
    _writeStringField(builder, 0, _stripIdPrefix(note.id));  // ID（无前缀）
    _writeStringField(builder, 1, note.title);               // 标题
    _writeDoubleField(builder, 2, note.createdAt.millisecondsSinceEpoch / 1000);
    _writeDoubleField(builder, 3, note.updatedAt.millisecondsSinceEpoch / 1000);

    // 子节点 ID 列表
    if (note.childIds.isNotEmpty) {
      _writeStringListField(builder, 4, note.childIds.map(_stripIdPrefix).toList());
    }

    // 富文本内容（JSON）
    if (note.content != null) {
      _writeStringField(builder, 5, jsonEncode(note.content!.toJson()));
    }

    // 布局坐标
    if (note.positionX != null) {
      _writeDoubleField(builder, 6, note.positionX!);
    }
    if (note.positionY != null) {
      _writeDoubleField(builder, 7, note.positionY!);
    }

    // 结束标记
    builder.writeByte(0x14);

    return builder.toBytes();
  }

  /// 写入字符串
  void _writeString(BytesBuilder builder, String value) {
    final bytes = utf8.encode(value);
    builder.write(Uint8List(4)
      ..buffer.asByteData().setUint32(0, bytes.length, Endian.little));
    builder.write(bytes);
  }

  /// 写入字符串字段
  void _writeStringField(BytesBuilder builder, int index, String value) {
    builder.writeByte(index);
    builder.writeByte(0x04);  // 字符串类型
    _writeString(builder, value);
  }

  /// 写入双精度字段
  void _writeDoubleField(BytesBuilder builder, int index, double value) {
    builder.writeByte(index);
    builder.writeByte(0xB6);  // Float64 类型
    final bytes = ByteData(8)..setFloat64(0, value, Endian.little);
    builder.write(bytes.buffer.asUint8List());
  }

  /// 写入字符串列表字段
  void _writeStringListField(BytesBuilder builder, int index, List<String> values) {
    builder.writeByte(index);
    builder.writeByte(0x24);  // 字符串数组类型

    // 写入数组长度
    builder.write(Uint8List(4)
      ..buffer.asByteData().setUint32(0, values.length, Endian.little));

    // 写入每个字符串
    for (final value in values) {
      _writeString(builder, value);
    }
  }

  /// 移除 ID 前缀
  String _stripIdPrefix(String id) {
    if (id.startsWith('1-')) return id.substring(2);
    return id;
  }
}
```

### 2.3 数据模型逆向映射

#### 2.3.1 Starmind → GuruMind ID 映射

| Starmind | GuruMind | 转换逻辑 |
|----------|----------|----------|
| `0-{UUID}` | `0-{UUID}` | 导图 ID，保持不变 |
| `2-{UUID}` | `2-{UUID}` | 笔记节点 ID，保持不变 |
| `1-{UUID}` | `{UUID}` | 导图节点，移除 `1-` 前缀 |

#### 2.3.2 字段映射

**Topic → GuruMind**：

| Starmind 字段 | GuruMind 字段 | 转换逻辑 |
|---------------|---------------|----------|
| id | id | 直接映射 |
| title | title | 直接映射 |
| createdAt | createdAt | DateTime → Float64 秒数 |
| updatedAt | updatedAt | DateTime → Float64 秒数 |
| thumbnailPath | thumbnailPath | 复制到 assets 目录 |
| rootNoteIds | rootNodes | 移除 `1-` 前缀 |

**Note → GuruMind**：

| Starmind 字段 | GuruMind 字段 | 转换逻辑 |
|---------------|---------------|----------|
| id | id | 移除 `1-` 前缀 |
| title | title | 直接映射 |
| content | contents | NoteContent → JSON segments |
| positionX, positionY | tree 坐标 | 合并到 tree 数据块 |
| childIds | childIds | 移除 `1-` 前缀 |

---

## 3. 刷题工作流优化

### 3.1 节点笔记图片+手写叠加

#### 3.1.1 StudyNoteWidget（刷题笔记组件）

```dart
/// 刷题笔记组件
///
/// 支持图片 + 手写叠加，用于刷题练习
class StudyNoteWidget extends StatefulWidget {
  final Note note;
  final InkLayerController inkController;
  final bool isStudyMode;

  const StudyNoteWidget({
    super.key,
    required this.note,
    required this.inkController,
    this.isStudyMode = false,
  });

  @override
  State<StudyNoteWidget> createState() => _StudyNoteWidgetState();
}

class _StudyNoteWidgetState extends State<StudyNoteWidget> {
  final TransformationController _transformController = TransformationController();
  double _baseScale = 1.0;

  @override
  Widget build(BuildContext context) {
    final content = widget.note.content;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D21),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x30FFFFFF)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // 基础内容层
            _buildContentLayer(content),

            // 手写叠加层
            if (widget.isStudyMode)
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: NodeInkOverlay(
                    layer: widget.inkController.getOrCreateNodeLayer(widget.note.id),
                    inkController: widget.inkController,
                    isInkMode: true,
                  ),
                ),
              ),

            // 工具栏（学习模式下）
            if (widget.isStudyMode)
              Positioned(
                top: 8,
                right: 8,
                child: _buildStudyToolbar(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentLayer(NoteContent? content) {
    if (content == null || content.segments.isEmpty) {
      return Center(
        child: Text(
          '暂无内容',
          style: TextStyle(color: Colors.white.withOpacity(0.5)),
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: content.segments.map((segment) {
            if (segment.type == SegmentType.image) {
              return _buildImageSegment(segment);
            } else if (segment.type == SegmentType.text) {
              return _buildTextSegment(segment);
            }
            return const SizedBox.shrink();
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildImageSegment(Segment segment) {
    final imagePath = segment.path;
    if (imagePath == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => _showImagePreview(imagePath),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        constraints: BoxConstraints(
          maxWidth: double.infinity,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(imagePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              height: 100,
              color: Colors.grey.withOpacity(0.2),
              child: const Center(child: Icon(Icons.broken_image)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextSegment(Segment segment) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        segment.text ?? '',
        style: TextStyle(
          fontSize: 14,
          color: Colors.white.withOpacity(0.9),
        ),
      ),
    );
  }

  Widget _buildStudyToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0x80242930),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 缩放控制
          IconButton(
            icon: const Icon(Icons.zoom_out, size: 20),
            onPressed: () => _zoomOut(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.zoom_in, size: 20),
            onPressed: () => _zoomIn(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          const SizedBox(width: 8),
          // 工具切换
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () => widget.inkController.setTool(InkTool.pen),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          IconButton(
            icon: const Icon(Icons.cleaning_services, size: 20),
            onPressed: () => widget.inkController.setTool(InkTool.eraser),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  void _zoomIn() {
    final matrix = _transformController.value.clone();
    matrix.scale(1.2, 1.2, 1.0);
    _transformController.value = matrix;
  }

  void _zoomOut() {
    final matrix = _transformController.value.clone();
    matrix.scale(0.8, 0.8, 1.0);
    _transformController.value = matrix;
  }

  void _showImagePreview(String imagePath) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            child: Image.file(File(imagePath)),
          ),
        ),
      ),
    );
  }
}
```

### 3.2 刷题模式控制器

```dart
/// 刷题模式控制器
class StudyModeController extends ChangeNotifier {
  final MindMapController _mindMapController;

  /// 是否处于刷题模式
  bool _isStudyMode = false;
  bool get isStudyMode => _isStudyMode;

  /// 当前节点索引
  int _currentIndex = 0;

  /// 刷题节点列表
  List<Note> _studyNotes = [];

  StudyModeController(this._mindMapController);

  /// 进入刷题模式
  void enterStudyMode() {
    _isStudyMode = true;
    _studyNotes = _collectStudyNotes();
    _currentIndex = 0;
    _selectCurrentNote();
    notifyListeners();
  }

  /// 退出刷题模式
  void exitStudyMode() {
    _isStudyMode = false;
    _studyNotes.clear();
    notifyListeners();
  }

  /// 收集所有可刷题的节点
  List<Note> _collectStudyNotes() {
    final notes = <Note>[];

    void traverse(List<NoteTreeNode> nodes) {
      for (final node in nodes) {
        // 如果节点有图片内容，加入刷题列表
        if (_hasImageContent(node.note)) {
          notes.add(node.note);
        }
        traverse(node.children);
      }
    }

    traverse(_mindMapController.noteTree);
    return notes;
  }

  /// 检查节点是否有图片内容
  bool _hasImageContent(Note note) {
    if (note.content == null) return false;
    return note.content!.segments.any((s) => s.type == SegmentType.image);
  }

  /// 下一个题目
  void nextQuestion() {
    if (_studyNotes.isEmpty) return;

    _currentIndex = (_currentIndex + 1) % _studyNotes.length;
    _selectCurrentNote();
    notifyListeners();
  }

  /// 上一个题目
  void previousQuestion() {
    if (_studyNotes.isEmpty) return;

    _currentIndex = (_currentIndex - 1 + _studyNotes.length) % _studyNotes.length;
    _selectCurrentNote();
    notifyListeners();
  }

  /// 跳转到指定题目
  void jumpToQuestion(int index) {
    if (index < 0 || index >= _studyNotes.length) return;

    _currentIndex = index;
    _selectCurrentNote();
    notifyListeners();
  }

  /// 选中当前节点
  void _selectCurrentNote() {
    if (_studyNotes.isEmpty) return;

    final note = _studyNotes[_currentIndex];
    _mindMapController.selectNote(note);

    // 导航到节点位置
    if (note.positionX != null && note.positionY != null) {
      _mindMapController.setOffset(
        Offset(-note.positionX!, -note.positionY!),
      );
    }
  }

  /// 获取刷题进度
  String get progressText {
    if (_studyNotes.isEmpty) return '0/0';
    return '${_currentIndex + 1}/${_studyNotes.length}';
  }

  /// 获取当前题目节点
  Note? get currentQuestion {
    if (_studyNotes.isEmpty || _currentIndex >= _studyNotes.length) return null;
    return _studyNotes[_currentIndex];
  }
}
```

### 3.3 快捷键支持

```dart
/// 刷题模式快捷键处理器
class StudyModeShortcutHandler {
  final StudyModeController _controller;
  final FocusNode _focusNode;

  StudyModeShortcutHandler(this._controller)
      : _focusNode = FocusNode();

  Widget wrap(Widget child) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: child,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_controller.isStudyMode) return KeyEventResult.ignored;

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      // 左箭头/上箭头：上一题
      if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
          event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _controller.previousQuestion();
        return KeyEventResult.handled;
      }

      // 右箭头/下箭头：下一题
      if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _controller.nextQuestion();
        return KeyEventResult.handled;
      }

      // 数字键：跳转到第 N 题
      final digit = _getDigitKey(event.logicalKey);
      if (digit != null) {
        _controller.jumpToQuestion(digit - 1);
        return KeyEventResult.handled;
      }

      // Escape：退出刷题模式
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _controller.exitStudyMode();
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  int? _getDigitKey(LogicalKeyboardKey key) {
    const digitKeys = [
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];

    final index = digitKeys.indexOf(key);
    return index >= 0 ? index + 1 : null;
  }

  void dispose() {
    _focusNode.dispose();
  }
}
```

### 3.4 刷题模式 UI

```dart
/// 刷题模式面板
class StudyModePanel extends StatelessWidget {
  final StudyModeController controller;

  const StudyModePanel({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        if (!controller.isStudyMode) return const SizedBox.shrink();

        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xCC242930),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 上一题
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: controller.previousQuestion,
              ),

              // 进度显示
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0x20FFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  controller.progressText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 下一题
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: controller.nextQuestion,
              ),

              const SizedBox(width: 16),

              // 分隔线
              Container(
                width: 1,
                height: 24,
                color: Colors.white.withOpacity(0.2),
              ),

              const SizedBox(width: 16),

              // 退出按钮
              TextButton.icon(
                icon: const Icon(Icons.close, size: 18),
                label: const Text('退出'),
                onPressed: controller.exitStudyMode,
              ),
            ],
          ),
        );
      },
    );
  }
}
```

---

## 4. 重构计划

### 4.1 Phase 4.1：GuruMind 导出核心（3-4天）

**任务**：
1. 实现 `HiveEncoder`
2. 实现 `GuruMindDataExporter`
3. 测试导出功能

**验收**：
- 导出的 `.gurumind` 文件可在 GuruMind 中打开

### 4.2 Phase 4.2：资源导出（2-3天）

**任务**：
1. 实现图片资源复制
2. 实现缩略图生成
3. ZIP 打包

**验收**：
- 图片资源正确导出
- 缩略图正确显示

### 4.3 Phase 4.3：刷题模式核心（3-4天）

**任务**：
1. 实现 `StudyModeController`
2. 实现 `StudyNoteWidget`
3. 快捷键支持

**验收**：
- 可进入刷题模式
- 快捷键正常工作

### 4.4 Phase 4.4：UI 完善（1-2天）

**任务**：
1. 实现 `StudyModePanel`
2. 进度显示
3. 交互优化

**验收**：
- 刷题体验流畅

---

## 5. 文件结构

```
lib/src/mindmap/
├── export/
│   ├── gurumind_exporter.dart           # 主导出器
│   ├── hive_encoder.dart                # Hive 编码器
│   └── export_exception.dart            # 异常定义
├── study/
│   ├── study_mode_controller.dart       # 刷题模式控制器
│   ├── study_note_widget.dart           # 刷题笔记组件
│   ├── study_mode_panel.dart            # 刷题模式面板
│   └── study_mode_shortcut_handler.dart # 快捷键处理器
└── test/
    ├── export/
    │   ├── hive_encoder_test.dart
    │   └── gurumind_exporter_test.dart
    └── study/
        └── study_mode_controller_test.dart
```

---

## 6. 测试策略

### 6.1 单元测试

```dart
test('HiveEncoder encodes Note correctly', () {
  final encoder = HiveEncoder();
  final note = Note(
    id: '1-test-uuid',
    title: '测试节点',
    topicId: 'topic-1',
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  final bytes = encoder.encodeNote(note);

  // 验证魔数
  expect(bytes[0], equals(0xFA));
  expect(bytes[1], equals(0x42));

  // 解码并验证
  final decoder = HiveDecoder();
  final doc = decoder.decodeBytes(bytes);
  expect(doc.getString(1), equals('测试节点'));
});

test('StudyModeController navigates questions', () {
  final mindMapController = MindMapController(/* ... */);
  final studyController = StudyModeController(mindMapController);

  studyController.enterStudyMode();

  expect(studyController.isStudyMode, isTrue);
  expect(studyController.currentQuestion, isNotNull);

  studyController.nextQuestion();
  // 验证索引变化
});
```

### 6.2 集成测试

```dart
testWidgets('Export and re-import preserves data', (tester) async {
  // 创建测试导图
  // 导出
  // 重新导入
  // 验证数据一致
});

testWidgets('Study mode navigation works', (tester) async {
  await tester.pumpWidget(TestMindMapApp());

  // 进入刷题模式
  // 模拟按键
  // 验证节点切换
});
```

---

## 7. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| 导出格式不兼容 | 高 | 严格遵循 GuruMind 格式，测试验证 |
| 资源路径错误 | 中 | 使用相对路径，路径映射表 |
| 刷题性能 | 低 | 虚拟列表，懒加载 |

---

## 8. 验收标准

### 8.1 功能验收

- [ ] 导出 `.gurumind` 文件成功
- [ ] 导出文件可在 GuruMind 中打开
- [ ] 刷题模式正常工作
- [ ] 快捷键响应正确

### 8.2 质量验收

- [ ] 单元测试覆盖率 > 70%
- [ ] 无数据丢失
- [ ] 性能达标

---

## 9. 总结

完成阶段 4 后，整个项目将具备以下能力：

1. **完整的 GuruMind 双向兼容**
   - 导入 `.gurumind` 文件
   - 导出 `.gurumind` 文件

2. **双层手写功能**
   - 画布级手写批注
   - 节点级手写笔记

3. **刷题工作流**
   - 图片+手写组合
   - 快捷键导航
   - 学习模式

4. **高质量布局引擎**
   - 正确的连线渲染
   - 多种布局策略

---

*设计者：Claude Code*
