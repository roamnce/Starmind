# 思维导图导入与刷题卡模式调研报告

> 版本：1.0
> 日期：2026-06-07
> 状态：调研完成

---

## 1. 思维导图导入流程分析

### 1.1 导入入口（UI层）

**文件位置**: `lib/src/mindmap/ui/mindmap_page.dart`

导入功能通过顶部面包屑导航栏的"更多操作"菜单触发：

```dart
// 第1172-1212行
Future<void> _showMoreActionsMenu(BuildContext context) async {
  final selected = await showMenu<_MindMapMoreAction>(
    ...
    items: [
      PopupMenuItem(
        value: _MindMapMoreAction.importGuruMind,
        child: _buildMoreActionItem(Icons.file_upload_outlined, '导入 GuruMind'),
      ),
      ...
    ],
  );
  ...
  switch (selected) {
    case _MindMapMoreAction.importGuruMind:
      await _importGuruMindFile();
    ...
  }
}
```

**文件选择器调用** (第1225-1246行)：
```dart
Future<void> _importGuruMindFile() async {
  final result = await FilePicker.pickFiles(
    dialogTitle: '选择 GuruMind 文件',
    type: FileType.custom,
    allowedExtensions: const ['gurumind'],  // 仅支持 .gurumind 扩展名
  );
  final filePath = result?.files.single.path;
  if (filePath == null) return;

  try {
    final topic = await widget.controller.importGuruMindFile(filePath);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入：${topic?.title ?? 'GuruMind 文件'}')),
    );
  } catch (error) {
    // 显示错误消息
  }
}
```

### 1.2 支持的数据格式

**唯一支持的格式**: `.gurumind` 文件

**GuruMind 文件结构**：
```
演示.gurumind (ZIP压缩包)
├── manifest.json          # 顶层元数据
├── documents/
│   ├── 0-{UUID}/          # 主导图目录
│   │   ├── meta.json      # 导图元数据
│   │   ├── doc_0-...hive  # 导图Hive数据（二进制）
│   │   └── assets/        # 图片资源
│   │       ├── thumb.png         # 缩略图
│   │       └── {UUID}.png        # PDF摘录截图
│   ├── 2-{UUID}/          # 笔记节点目录
│   │   ├── meta.json      # 节点元数据
│   │   └── doc_2-...hive  # 节点Hive数据
```

**核心数据格式**:
1. **manifest.json** - JSON格式的顶层元数据
2. **Hive二进制格式** - 用于存储节点数据的自定义二进制格式，具有以下特征:
   - 魔数: `FA 42 00 00`
   - 类型标识符编码
   - 字段索引 + 类型字节 + 长度 + 数据的结构

### 1.3 导入处理流程

**架构概览**：

```
用户选择 .gurumind 文件
    ↓
MindMapController.importGuruMindFile()
    ↓
MindMapService.importGuruMindFile()
    ↓
GuruMindImporter.importFile()
    ↓
┌─────────────────────────────────────────────────────────────┐
│  1. ZIP解压      → GuruMindZipExtractor                      │
│  2. manifest解析 → GuruMindManifestParser                    │
│  3. Hive解码     → HiveDecoder                               │
│  4. 数据转换     → GuruMindDataConverter                      │
│  5. 持久化       → MindMapRepository                          │
│  6. 资源复制     → _copyResources()                           │
└─────────────────────────────────────────────────────────────┘
```

#### 1.3.1 ZIP解压 (`GuruMindZipExtractor`)

**文件**: `lib/src/mindmap/import/gurumind_zip_extractor.dart`

```dart
class GuruMindZipExtractor {
  Future<GuruMindArchive> extract(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw ImportException('GuruMind file not found');
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final files = <String, Uint8List>{};
    for (final entry in archive.files) {
      if (entry.isFile) files[entry.name.replaceAll('\\', '/')] = Uint8List.fromList(entry.content);
    }
    return GuruMindArchive(files);  // 返回内存中的文件映射
  }
}
```

#### 1.3.2 Manifest解析 (`GuruMindManifestParser`)

**文件**: `lib/src/mindmap/import/gurumind_manifest_parser.dart`

```dart
class GuruMindManifestParser {
  GuruMindManifest parse(GuruMindArchive archive) {
    final manifestBytes = archive['manifest.json'];
    if (manifestBytes == null) throw const ImportException('manifest.json missing');
    final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
    
    // 查找主导图ID (type == 'mindMap')
    final topicId = documents
        .where((document) => document['type'] == 'mindMap')
        .map((document) => document['id'] as String?)
        .firstOrNull;
    
    // 定位 Hive 文件路径
    final topicPath = _findHivePath(archive, 'documents/$topicId/');
    
    // 收集节点文件路径和资源路径
    final notePaths = ...;
    final assetPaths = archive.paths.where((path) => path.contains('/assets/'));
    
    return GuruMindManifest(topicPath: topicPath, notePaths: notePaths, assetPaths: assetPaths, meta: meta);
  }
}
```

#### 1.3.3 Hive二进制解码 (`HiveDecoder`)

**文件**: `lib/src/mindmap/import/hive_decoder.dart`

这是导入流程中最关键的部分，处理GuruMind特有的二进制格式：

```dart
class HiveDecoder {
  HiveDocument decodeBytes(Uint8List bytes) {
    // 首先检查是否有JSON魔数 (简化格式)
    if (_hasJsonMagic(bytes)) {
      // 如果是JSON格式，直接解析
      final decoded = jsonDecode(utf8.decode(bytes.sublist(payloadOffset)));
      return HiveDocument(Map<String, dynamic>.from(decoded));
    }
    
    // 否则使用GuruMind字段扫描算法
    return HiveDocument(_decodeGuruMindFields(bytes));
  }

  Map<String, dynamic> _decodeGuruMindFields(Uint8List bytes) {
    // 扫描字符串字段
    final strings = _scanStringFields(bytes);
    
    // 提取节点数据
    // 字段类型: 0x04 = 字符串, 0x24 = 字符串数组
    for (var offset = 0; offset < bytes.length - 6; offset++) {
      final fieldIndex = bytes[offset];
      final type = bytes[offset + 1];
      if (type == 0x04 || type == 0x24) {
        // 解码字符串内容
        final length = bytes[offset + 2] | (bytes[offset + 3] << 8) | ...
        final value = utf8.decode(bytes.sublist(offset + 6, offset + 6 + length));
      }
    }
    
    return {
      'id': firstId,
      'title': firstTitle,
      'nodes': nodes,  // 节点数组
      'rootNodes': rootIds,
    };
  }
}
```

#### 1.3.4 数据转换 (`GuruMindDataConverter`)

**文件**: `lib/src/mindmap/import/gurumind_data_converter.dart`

负责将GuruMind数据格式转换为Starmind内部数据模型：

**ID前缀规则对照**：
| GuruMind前缀 | Starmind处理 | 类型 |
|-------------|-------------|------|
| `0-{UUID}` | 保持不变 | 导图ID |
| `2-{UUID}` | 保持不变 | 笔记节点ID |
| `{UUID}`(无前缀) | 转换为 `1-{UUID}` | 导图节点 |

#### 1.3.5 主导入器 (`GuruMindImporter`)

**文件**: `lib/src/mindmap/import/gurumind_importer.dart`

```dart
class GuruMindImporter {
  Future<ImportResult> importFile(String filePath) async {
    try {
      // 1. ZIP解压
      final archive = await _zipExtractor.extract(filePath);
      
      // 2. 解析manifest
      final manifest = _manifestParser.parse(archive);
      
      // 3. 解码主导图Hive文件
      final topicBytes = archive[manifest.topicPath];
      final topicDocument = _hiveDecoder.decodeBytes(topicBytes).values;
      
      // 4. 转换Topic
      var topic = _converter.topicFromDocument(topicDocument);
      
      // 5. 解码并转换所有节点
      final notesById = <String, Note>{};
      
      // 处理主导图内嵌节点
      // 处理独立的笔记节点Hive文件
      
      // 6. 修复根节点引用（如果缺失）
      
      // 7. ersist化到数据库
      await _repository.updateTopic(topic);
      
      // 8. 复制资源文件（图片）
      await _copyResources(archive, manifest.assetPaths);
      
      return ImportResult(topic: topic, notes: notes);
    } on ImportException catch (error) {
      return ImportResult(error: error);
    }
  }
}
```

### 1.4 导入后数据模型

**Topic** (`lib/src/mindmap/domain/topic.dart`):
```dart
class Topic {
  final String id;              // 格式: "0-{UUID}"
  final String title;           // 笔记本标题
  final List<String> pdfIds;    // 关联的PDF文档MD5列表
  final List<String> rootNoteIds; // 根节点ID列表
  final String? thumbnailPath;  // 缩略图路径
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

**Note** (`lib/src/mindmap/domain/note.dart`):
```dart
class Note {
  final String id;              // 格式: "1-{UUID}" 或 "2-{UUID}"
  final String topicId;         // 所属导图ID
  final String? parentId;       // 父节点ID
  final String title;           // 节点标题
  final NoteContent? content;   // 富文本内容 (JSON segments)
  final List<String> childIds;  // 子节点ID列表
  final String? pdfId;          // 关联的PDF ID
  final double? positionX;      // 画布X坐标
  final double? positionY;      // 画布Y坐标
  final String? highlightStyle; // 高亮样式
  final String layoutStyle;     // 布局样式
}
```

### 1.5 关键文件清单

| 文件路径 | 功能 |
|---------|------|
| `lib/src/mindmap/ui/mindmap_page.dart` | UI入口，文件选择器调用 |
| `lib/src/mindmap/ui/mindmap_controller.dart` | Controller层，调用Service导入 |
| `lib/src/mindmap/service/mindmap_service.dart` | Service层，创建Importer实例 |
| `lib/src/mindmap/import/gurumind_importer.dart` | 主导入器，协调各组件 |
| `lib/src/mindmap/import/gurumind_zip_extractor.dart` | ZIP解压 |
| `lib/src/mindmap/import/gurumind_manifest_parser.dart` | manifest.json解析 |
| `lib/src/mindmap/import/hive_decoder.dart` | Hive二进制解码 |
| `lib/src/mindmap/import/gurumind_data_converter.dart` | 数据模型转换 |
| `lib/src/mindmap/domain/topic.dart` | Topic数据模型 |
| `lib/src/mindmap/domain/note.dart` | Note数据模型 |

---

## 2. 刷题卡模式实现分析

### 2.1 刷题卡模式的入口和触发方式

**菜单入口**:
- 路径：`lib/src/mindmap/ui/mindmap_page.dart`
- 在 `_showMoreActionsMenu` 方法中（第1172-1212行）
- 选择"进入刷题模式"菜单项

**快捷键入口**:
- 快捷键：`Ctrl + Alt + T`
- 代码逻辑（mindmap_page.dart 第222-228行）：
```dart
if (isCtrl && isAlt && event.logicalKey == LogicalKeyboardKey.keyT) {
  final topicId = widget.controller.selectedTopic?.id;
  if (topicId != null) {
    widget.controller.studyModeController.enterStudyMode(topicId);
  }
  return KeyEventResult.handled;
}
```

### 2.2 刷题卡的数据结构和模型

**核心数据模型**:

路径：`lib/src/mindmap/study/study_mode_controller.dart`

```dart
// 题目数据封装
class StudyQuestion {
  final Note note;      // 题目对应的节点
  final int index;      // 当前索引
  final int total;      // 总题目数
}

// 控制器状态
class StudyModeController extends ChangeNotifier {
  final MindMapService _service;
  final List<Note> _questions = [];   // 题目列表
  bool _isStudyMode = false;           // 是否在刷题模式
  int _currentIndex = 0;               // 当前题目索引
}
```

**刷题候选节点判断逻辑**:

路径：`study_mode_controller.dart` 第76-87行

```dart
bool _isStudyCandidate(Note note) {
  // 有高亮摘录文本
  if (note.highlightText?.trim().isNotEmpty ?? false) return true;
  // 有关联媒体
  if (note.mediaIds.isNotEmpty) return true;
  
  final content = note.content;
  if (content == null) return false;
  
  return content.segments.any((segment) {
    // 有图片内容
    if (segment.type == SegmentType.image) return true;
    // 有填空标记
    if (segment.style?.cloze ?? false) return true;
    // 有文本内容
    return segment.text?.trim().isNotEmpty ?? false;
  });
}
```

**NoteContent 数据模型**:

路径：`lib/src/mindmap/domain/note_content.dart`

```dart
class NoteContent {
  final List<Segment> segments;
}

class Segment {
  final SegmentType type;  // text 或 image
  final String? text;
  final TextStyle? style;  // 包含 cloze（填空）标记
  final String? path;      // 图片路径
}

class TextStyle {
  final bool cloze;  // 填空标记，用于刷题
}
```

### 2.3 刷题卡的UI组件和交互逻辑

**StudyModePanel - 进度面板**:

路径：`lib/src/mindmap/study/study_mode_panel.dart`

显示在画布顶部（mindmap_page.dart 第596-602行集成）：
- 进度条
- 题目计数（如 "1/10"）
- 上一题/下一题按钮
- 退出按钮

**StudyNoteWidget - 题卡组件**:

路径：`lib/src/mindmap/study/study_note_widget.dart`

显示在画布右侧，宽度420像素（mindmap_page.dart 第603-614行）：
- 显示题目编号和标题
- 内嵌 `NodeNoteContent` 组件渲染富文本内容
- 支持手写叠加层

**NodeNoteContent - 节点内容渲染**:

路径：`lib/src/mindmap/ink/node_note_content.dart`

- 渲染富文本内容（文本、图片）
- 叠加手写层

### 2.4 刷题卡与思维导图节点的关联关系

**节点筛选逻辑**:

通过 `_isStudyCandidate` 方法筛选符合条件的节点：
1. 有 `highlightText`（PDF摘录文本）
2. 有 `mediaIds`（关联媒体）
3. 有图片类型的 Segment
4. 有填空标记的 Segment
5. 有非空文本内容

**数据流**:

```
MindMapService.getNotesByTopic(topicId)
    ↓
筛选符合条件的 Note 列表
    ↓
StudyModeController._questions 列表
    ↓
根据 currentIndex 获取当前题目
    ↓
StudyNoteWidget 渲染题卡
```

### 2.5 刷题过程中的状态管理和答题逻辑

**状态管理**:

路径：`lib/src/mindmap/study/study_mode_controller.dart`

| 方法 | 功能 |
|------|------|
| `enterStudyMode(topicId)` | 进入刷题模式，加载所有候选题目 |
| `enterWithQuestions(notes)` | 直接传入题目列表（用于测试） |
| `exitStudyMode()` | 退出刷题模式 |
| `nextQuestion()` | 下一题 |
| `previousQuestion()` | 上一题 |
| `jumpTo(index)` | 跳转到指定题目 |

**快捷键处理**:

路径：`lib/src/mindmap/study/study_mode_shortcut_handler.dart`

| 快捷键 | 功能 |
|--------|------|
| `→` 或 `Space` | 下一题 |
| `←` | 上一题 |
| `Escape` | 退出刷题模式 |

**手写层持久化**:

路径：`lib/src/mindmap/ink/ink_layer.dart`

- `InkLayer` - 手写层数据结构，包含多个 `InkStroke`
- `InkStroke` - 笔画，包含多个 `InkPoint`
- `InkLayerOwnerType` - 所有权类型：`canvas`（画布级）或 `node`（节点级）

刷题时使用 `node` 类型的手写层，每个节点可以有独立的手写批注。

### 2.6 完整架构总结

```
mindmap_page.dart (UI入口)
    │
    ├── 更多操作菜单 → studyModeController.enterStudyMode()
    ├── 快捷键 Ctrl+Alt+T → studyModeController.enterStudyMode()
    │
    ├── StudyModePanel (顶部进度条)
    │       └── StudyModeController (状态管理)
    │
    └── StudyNoteWidget (右侧题卡)
            │
            ├── NodeNoteContent (内容渲染)
            │       ├── _NoteRichText (富文本/图片)
            │       └── NodeInkOverlay (手写叠加层)
            │
            └── InkLayerController (手写控制)
                    └── InkLayerRepository (持久化)
```

### 2.7 关键文件清单

| 文件路径 | 功能 |
|----------|------|
| `lib/src/mindmap/study/study_mode_controller.dart` | 刷题模式核心控制器 |
| `lib/src/mindmap/study/study_mode_panel.dart` | 进度面板UI |
| `lib/src/mindmap/study/study_note_widget.dart` | 题卡组件 |
| `lib/src/mindmap/study/study_mode_shortcut_handler.dart` | 快捷键处理 |
| `lib/src/mindmap/ink/ink_layer.dart` | 手写层数据模型 |
| `lib/src/mindmap/ink/ink_layer_controller.dart` | 手写控制器 |
| `lib/src/mindmap/ink/canvas_ink_layer.dart` | 手写渲染组件 |
| `lib/src/mindmap/ink/node_note_content.dart` | 节点内容+手写叠加 |
| `lib/src/mindmap/domain/note.dart` | 节点数据模型 |
| `lib/src/mindmap/domain/note_content.dart` | 富文本内容模型 |
| `lib/src/mindmap/ui/mindmap_page.dart` | 主页面集成 |

---

## 3. 设计意图与实现对比

### 3.1 导入流程的设计意图

**设计文档**：`docs/superpowers/specs/2026-06-03-phase3-gurumind-import-design.md`

**设计意图**：
1. 实现与 GuruMind 的单向兼容（导入）
2. 解析 GuruMind 特有的 Hive 二进制格式
3. 保留富文本内容（JSON Segments）
4. 正确处理 ID 前缀转换

**实际实现**：
- ✅ ZIP解压流程完整
- ✅ Manifest解析正确
- ✅ Hive解码器支持两种格式（JSON简化格式 + 二进制格式）
- ✅ ID前缀转换规则正确应用
- ✅ 资源文件复制到本地

### 3.2 刷题模式的设计意图

**设计文档**：`docs/superpowers/specs/2026-06-03-phase4-export-study-design.md`

**设计意图**：
1. 图片+手写叠加显示
2. 快捷键导航（←/→/Space/Escape）
3. 进度显示（1/10）
4. 手写层持久化（节点级）

**实际实现**：
- ✅ StudyNoteWidget 支持图片+手写叠加
- ✅ 快捷键处理完整
- ✅ 进度面板显示
- ✅ 手写层独立存储

---

## 4. 潜在问题与改进建议

### 4.1 导入流程

**问题1**：仅支持 `.gurumind` 格式，不支持其他思维导图格式（如 XMind、MindManager）

**建议**：可考虑添加其他格式的导入支持，扩展用户群体

**问题2**：Hive二进制解码依赖逆向分析，可能存在边界情况未覆盖

**建议**：增加更多测试用例，覆盖各种边界情况

### 4.2 刷题模式

**问题1**：刷题候选筛选逻辑过于宽松

当前筛选条件：
- 有 highlightText
- 有 mediaIds
- 有图片
- 有填空标记
- 有非空文本

**潜在问题**：几乎所有节点都会被纳入刷题列表，可能不符合用户预期

**建议**：增加更严格的筛选条件，或让用户手动标记刷题节点

**问题2**：缺少题目难度分级

**建议**：可添加标签系统，支持按难度筛选

**问题3**：缺少答题记录和统计

**建议**：可添加答题状态追踪（已答/未答/正确/错误）

---

## 5. 相关设计文档

| 文档路径 | 内容 |
|----------|------|
| `docs/superpowers/specs/2026-06-03-phase3-gurumind-import-design.md` | GuruMind导入详细设计 |
| `docs/superpowers/specs/2026-06-03-phase4-export-study-design.md` | 导出与刷题优化设计 |

---

## 6. 实际问题诊断与根因分析

### 6.1 导入后"原节点丢失"问题

**用户反馈**：导入 GuruMind 文件后，原来的节点没了，也没有新的 gurumind 文件，出现 "No nodes" 页面。

**根本原因分析**：

查看 `mindmap_controller.dart` 第 285-293 行的 `importGuruMindFile` 方法：

```dart
Future<Topic?> importGuruMindFile(String filePath) async {
  final result = await _service.importGuruMindFile(filePath);
  if (!result.isSuccess || result.topic == null) {
    throw result.error ?? StateError('GuruMind import failed');
  }
  await loadTopics();        // 重新加载所有笔记本列表
  selectTopic(result.topic); // 切换到新导入的笔记本
  return result.topic;
}
```

**关键发现**：

1. **导入行为是"创建新笔记本"，而非"合并到当前笔记本"**
   - 导入会创建一个新的 Topic，并在数据库中存储
   - 导入后会自动切换到新创建的笔记本
   - **原来的笔记本仍然存在**，只是视图切换到了新导入的笔记本

2. **出现 "No nodes" 的原因**：
   - 导入成功创建了 Topic，但节点解析可能失败
   - 查看 `gurumind_importer.dart` 第 55-58 行：
   ```dart
   for (final node in topicDocument['nodes'] as List<dynamic>? ?? const []) {
     final note = _converter.noteFromDocument(Map<String, dynamic>.from(node as Map), topicId: topic.id);
     notesById[note.id] = note;
   }
   ```
   - 如果 `topicDocument['nodes']` 为空或解析失败，会导致 `notes` 为空
   - 第 66-69 行会尝试修复根节点：
   ```dart
   if (topic.rootNoteIds.isEmpty) {
     final rootIds = notes.where((note) => note.parentId == null).map((note) => note.id).toList();
     topic = topic.copyWith(rootNoteIds: rootIds);
   }
   ```
   - 如果 `notes` 为空，`rootNoteIds` 也为空，最终显示 "No nodes"

3. **可能的问题点**：
   - Hive 解码失败（二进制格式不兼容）
   - `nodes` 字段解析为空
   - ID 前缀转换导致节点 ID 不匹配

**预期行为 vs 实际行为**：

| 维度 | 用户预期 | 实际实现 |
|------|---------|---------|
| 导入位置 | 合并到当前笔记本 | 创建新笔记本并切换 |
| 原数据 | 保留 | 保留（但视图切换走了） |
| 导入后视图 | 显示导入的节点 | 显示 "No nodes"（节点解析失败） |

**建议修复方向**：

1. **短期修复**：检查 Hive 解码逻辑，确保节点正确解析
2. **中期优化**：导入时提供选项——"创建新笔记本" 或 "合并到当前笔记本"
3. **长期优化**：导入失败时提供详细错误信息，而非静默创建空笔记本

### 6.2 刷题模式"点击无反应"问题

**用户反馈**：点击"进入刷题模式"后没有反应。

**根本原因分析**：

查看 `study_mode_controller.dart` 第 34-42 行：

```dart
Future<void> enterStudyMode(String topicId) async {
  final notes = await _service.getNotesByTopic(topicId);
  _questions
    ..clear()
    ..addAll(notes.where(_isStudyCandidate));
  _currentIndex = 0;
  _isStudyMode = _questions.isNotEmpty;  // 关键：只有当有候选题目时才进入刷题模式
  notifyListeners();
}
```

**关键发现**：

1. **刷题模式只有在 `_questions.isNotEmpty` 时才会激活**
   - 如果筛选后 `_questions` 为空，`_isStudyMode` 会被设为 `false`
   - UI 层面不会显示任何刷题界面

2. **筛选条件 `_isStudyCandidate`**（第 76-87 行）：
   ```dart
   bool _isStudyCandidate(Note note) {
     if (note.highlightText?.trim().isNotEmpty ?? false) return true;  // 有PDF摘录
     if (note.mediaIds.isNotEmpty) return true;                         // 有关联媒体
     
     final content = note.content;
     if (content == null) return false;
     
     return content.segments.any((segment) {
       if (segment.type == SegmentType.image) return true;      // 有图片
       if (segment.style?.cloze ?? false) return true;          // 有填空标记
       return segment.text?.trim().isNotEmpty ?? false;         // 有文本内容
     });
   }
   ```

3. **问题分析**：
   - 如果节点只有标题（`title`），但 `content` 为 `null`，且没有 `highlightText` 和 `mediaIds`
   - 这个节点会被排除在刷题列表之外
   - 当所有节点都不满足条件时，`_questions` 为空，刷题模式无法进入

4. **UI 层面的静默处理**：
   - 查看 `mindmap_page.dart` 第 596-614 行：
   ```dart
   if (widget.controller.studyModeController.isStudyMode)
     Positioned(..., child: StudyModePanel(...)),
   if (widget.controller.studyModeController.currentQuestion != null)
     Positioned(..., child: StudyNoteWidget(...)),
   ```
   - 只有当 `isStudyMode` 为 `true` 时才显示刷题 UI
   - 没有候选题目时，用户点击菜单项后没有任何反馈

**预期行为 vs 实际行为**：

| 维度 | 用户预期 | 实际实现 |
|------|---------|---------|
| 点击后的反馈 | 显示刷题界面或提示"无可用题目" | 静默失败，无任何提示 |
| 刷题候选条件 | 有图片的节点 | 有图片/PDF摘录/媒体/填空/文本内容的节点 |
| 仅标题的节点 | 可能期望能刷题 | 被排除在外 |

**建议修复方向**：

1. **短期修复**：当 `_questions` 为空时，显示提示信息（如"当前笔记本没有可刷题的节点"）
2. **中期优化**：让用户可以手动标记节点为"刷题候选"
3. **长期优化**：提供刷题候选预览，让用户在进入前知道有哪些题目

---

*调研者：Claude Code*