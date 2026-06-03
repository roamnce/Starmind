# 阶段3：GuruMind 导入设计文档

> 版本：1.0
> 日期：2026-06-03
> 状态：设计中

---

## 1. 目标与范围

### 1.1 核心目标

实现 `.gurumind` 文件的完整导入功能，支持：
- 节点树结构导入
- 节点内容导入（文本、图片）
- 布局坐标导入
- 缩略图与图片资源导入

### 1.2 GuruMind 文件格式分析

基于 `D:\个人文件\Downloads\演示.gurumind` 的逆向分析：

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
│   └── {UUID}/            # 独立文档目录
│       └── {UUID}.md      # Markdown 文件
```

### 1.3 导入范围

根据用户需求，需要导入：
- ✅ 节点树结构（父子关系）
- ✅ 节点内容（JSON segments 富文本）
- ✅ 布局坐标（tree 数据块）
- ✅ 缩略图与图片资源

### 1.4 成功标准

- ✅ 成功解析 `.gurumind` ZIP 文件
- ✅ 正确解码 Hive 二进制数据
- ✅ 节点树结构与原始文件一致
- ✅ 图片资源正确导入并显示

---

## 2. GuruMind 数据格式详解

### 2.1 manifest.json 结构

```json
{
  "version": 1,
  "exportedAt": "2026-05-31T12:21:19.191611",
  "documentCount": 1,
  "documents": [
    {
      "id": "0-6f73097d-26ad-4537-9cb2-156e22f17160",
      "type": "mindMap",
      "title": "演示"
    }
  ],
  "tags": [
    {
      "id": "tag-uuid",
      "name": "标签名",
      "color": "#FF5722"
    }
  ]
}
```

### 2.2 meta.json 结构

**导图元数据**：
```json
{
  "id": "0-6f73097d-26ad-4537-9cb2-156e22f17160",
  "title": "演示",
  "type": "mindMap",
  "createdAt": "2026-04-28T15:26:34.578",
  "updatedAt": "2026-05-31T12:21:08.375618",
  "thumbnailPath": "documents/0-.../assets/thumb.png",
  "linkedIds": []
}
```

**笔记节点元数据**：
```json
{
  "id": "2-248ed6bb-05c2-4094-9c49-32ed32225317",
  "title": "节点标题",
  "type": "note",
  "noteType": "node",
  "linkedIds": ["0-6f73097d-..."],  // 关联的导图ID
  "createdAt": "2026-05-11T08:16:30.292",
  "updatedAt": "2026-05-31T12:20:13.716370"
}
```

### 2.3 Hive 二进制格式

**文件头**：
```
FA 42 00 00              # Hive 魔数
01 08 "document"         # 类型标识符
```

**字段结构**：
```
[field_index] [type_byte] [length] [data]
```

**字段类型**：
| 类型字节 | 含义 |
|----------|------|
| 0x04 | 字符串 |
| 0x24 | 字符串数组 |
| 0xB6 | Float64 |
| 0x36 | 嵌套对象 |

**关键字段映射**：
| 索引 | 字段名 | 类型 |
|------|--------|------|
| 0x00 | id | String |
| 0x01 | title | String |
| 0x02 | createdAt | Float64 |
| 0x03 | updatedAt | Float64 |
| 0x04 | rootNodes | List<String> |
| 0x05 | contents | List<Object> |

### 2.4 JSON Segments 富文本格式

```json
{
  "segments": [
    {
      "type": "text",
      "text": "文本内容",
      "style": {
        "bold": false,
        "italic": false,
        "underline": false,
        "strikethrough": false,
        "cloze": false,
        "link": null,
        "textColor": null,
        "backgroundColor": null,
        "fontSize": null,
        "textAlign": null
      }
    },
    {
      "type": "image",
      "path": "assets/a201d4bf-...png",
      "width": 400.0,
      "height": 77.2,
      "fit": 1
    }
  ]
}
```

### 2.5 ID 前缀规则

| 前缀 | 类型 | 示例 |
|------|------|------|
| `0-` | 导图（mindMap） | `0-6f73097d-...` |
| `2-` | 笔记节点（note） | `2-248ed6bb-...` |
| 无前缀 | 导图节点 | `b9b32257-...` |

---

## 3. 架构设计

### 3.1 导入流程

```
┌─────────────────────────────────────────────────────────────────────┐
│                        用户选择 .gurumind 文件                       │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    1. ZIP 解压                                       │
│                    GuruMindZipExtractor                              │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    2. 元数据解析                                      │
│                    manifest.json → Topic 元数据                      │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    3. Hive 二进制解码                                 │
│                    HiveDecoder → 节点树数据                          │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    4. 数据转换                                        │
│                    GuruMind → Starmind 数据模型映射                   │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    5. 资源导入                                        │
│                    图片资源复制到本地 assets 目录                      │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    6. 数据持久化                                      │
│                    存储到 SQLite 数据库                               │
└───────────────────────────────┬─────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    7. UI 刷新                                         │
│                    更新 MindMapController，显示导入的导图             │
└─────────────────────────────────────────────────────────────────────┘
```

### 3.2 核心组件

#### 3.2.1 GuruMindZipExtractor（ZIP 解压器）

```dart
/// GuruMind ZIP 文件解压器
class GuruMindZipExtractor {
  /// 解压 ZIP 文件到临时目录
  Future<String> extract(String zipPath) async {
    final tempDir = await getTemporaryDirectory();
    final extractPath = path.join(tempDir.path, 'gurumind_import_${DateTime.now().millisecondsSinceEpoch}');

    // 使用 archive 库解压
    final bytes = await File(zipPath).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filePath = path.join(extractPath, file.name);
      if (file.isFile) {
        await File(filePath).writeAsBytes(file.content as List<int>);
      } else {
        await Directory(filePath).create(recursive: true);
      }
    }

    return extractPath;
  }
}
```

#### 3.2.2 GuruMindManifestParser（元数据解析器）

```dart
/// GuruMind manifest 解析器
class GuruMindManifestParser {
  /// 解析 manifest.json
  Future<GuruMindManifest> parse(String extractPath) async {
    final manifestPath = path.join(extractPath, 'manifest.json');
    final manifestJson = jsonDecode(await File(manifestPath).readAsString());

    return GuruMindManifest.fromJson(manifestJson);
  }
}

/// manifest 数据模型
class GuruMindManifest {
  final int version;
  final DateTime exportedAt;
  final int documentCount;
  final List<GuruMindDocument> documents;
  final List<GuruMindTag> tags;

  factory GuruMindManifest.fromJson(Map<String, dynamic> json) {
    return GuruMindManifest(
      version: json['version'] as int,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      documentCount: json['documentCount'] as int,
      documents: (json['documents'] as List)
          .map((d) => GuruMindDocument.fromJson(d))
          .toList(),
      tags: (json['tags'] as List?)
          ?.map((t) => GuruMindTag.fromJson(t))
          .toList() ?? [],
    );
  }
}

/// 文档引用
class GuruMindDocument {
  final String id;
  final String type;  // 'mindMap', 'note'
  final String title;
}
```

#### 3.2.3 HiveDecoder（Hive 二进制解码器）

```dart
/// Hive 二进制解码器
class HiveDecoder {
  /// 解码 Hive 文件
  Future<HiveDocument> decode(String hivePath) async {
    final bytes = await File(hivePath).readAsBytes();
    return _decodeBytes(bytes);
  }

  HiveDocument _decodeBytes(Uint8List bytes) {
    final reader = ByteData.sublistView(bytes);

    // 检查魔数
    if (reader.getUint32(0, Endian.little) != 0x000042FA) {
      throw FormatException('Invalid Hive file: missing magic number');
    }

    int offset = 4;  // 跳过魔数

    // 解码类型标识符
    final typeInfo = _readString(reader, offset);
    offset = typeInfo.offset;

    // 解码字段
    final fields = <int, dynamic>{};

    while (offset < bytes.length - 1) {
      final fieldResult = _readField(reader, offset);
      if (fieldResult == null) break;

      fields[fieldResult.index] = fieldResult.value;
      offset = fieldResult.offset;
    }

    return HiveDocument(
      type: typeInfo.value,
      fields: fields,
    );
  }

  /// 读取字符串
  _StringResult _readString(ByteData reader, int offset) {
    final length = reader.getUint32(offset, Endian.little);
    offset += 4;

    final bytes = Uint8List.sublistView(
      reader.buffer,
      reader.offsetInBytes + offset,
      reader.offsetInBytes + offset + length,
    );
    final value = utf8.decode(bytes);

    return _StringResult(value: value, offset: offset + length);
  }

  /// 读取字段
  _FieldResult? _readField(ByteData reader, int offset) {
    if (offset >= reader.lengthInBytes - 1) return null;

    final fieldIndex = reader.getUint8(offset);
    offset += 1;

    if (fieldIndex == 0x14) return null;  // 结束标记

    final typeByte = reader.getUint8(offset);
    offset += 1;

    dynamic value;
    switch (typeByte) {
      case 0x04:  // 字符串
        final result = _readString(reader, offset);
        value = result.value;
        offset = result.offset;
        break;
      case 0x24:  // 字符串数组
        final result = _readStringArray(reader, offset);
        value = result.value;
        offset = result.offset;
        break;
      case 0xB6:  // Float64
        value = reader.getFloat64(offset, Endian.little);
        offset += 8;
        break;
      case 0x03:  // 嵌套对象长度
        final length = reader.getUint32(offset, Endian.little);
        offset += 4;
        // 递归解码嵌套对象
        break;
      default:
        // 未知类型，尝试跳过
        break;
    }

    return _FieldResult(index: fieldIndex, value: value, offset: offset);
  }
}

/// Hive 文档数据
class HiveDocument {
  final String type;
  final Map<int, dynamic> fields;

  /// 获取字符串字段
  String? getString(int index) => fields[index] as String?;

  /// 获取浮点数字段
  double? getDouble(int index) => fields[index] as double?;

  /// 获取字符串列表字段
  List<String>? getStringList(int index) => fields[index] as List<String>?;
}
```

#### 3.2.4 GuruMindDataConverter（数据转换器）

```dart
/// GuruMind → Starmind 数据转换器
class GuruMindDataConverter {
  /// 转换导图数据
  Future<Topic> convertTopic({
    required GuruMindManifest manifest,
    required HiveDocument hiveDoc,
    required String extractPath,
  }) async {
    final docInfo = manifest.documents.first;

    // 从 Hive 字段提取数据
    final id = hiveDoc.getString(0) ?? docInfo.id;
    final title = hiveDoc.getString(1) ?? docInfo.title;

    // 时间戳转换（Float64 秒数 → DateTime）
    final createdAtSeconds = hiveDoc.getDouble(2) ?? 0;
    final updatedAtSeconds = hiveDoc.getDouble(3) ?? 0;

    // 节点 ID 列表
    final rootNodeIds = hiveDoc.getStringList(4) ?? [];

    // 复制缩略图
    final thumbnailPath = await _copyThumbnail(extractPath, id);

    return Topic(
      id: id,
      title: title,
      pdfIds: [],  // GuruMind 暂无 PDF 关联
      rootNoteIds: rootNodeIds,
      thumbnailPath: thumbnailPath,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (createdAtSeconds * 1000).toInt(),
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (updatedAtSeconds * 1000).toInt(),
      ),
    );
  }

  /// 转换节点数据
  Future<Note> convertNote({
    required HiveDocument hiveDoc,
    required String topicId,
    required String? parentId,
    required String extractPath,
    required String targetAssetsPath,
  }) async {
    final id = hiveDoc.getString(0) ?? '';
    final title = hiveDoc.getString(1) ?? '';

    // 解析富文本内容
    final contentJson = hiveDoc.getString(5);  // contents JSON
    NoteContent? content;
    if (contentJson != null) {
      content = await _parseContent(contentJson, extractPath, targetAssetsPath);
    }

    // 布局坐标
    final positionX = hiveDoc.getDouble(6);
    final positionY = hiveDoc.getDouble(7);

    return Note(
      id: '1-$id',  // 添加前缀
      topicId: topicId,
      parentId: parentId != null ? '1-$parentId' : null,
      title: title,
      content: content,
      positionX: positionX,
      positionY: positionY,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// 解析富文本内容
  Future<NoteContent> _parseContent(
    String contentJson,
    String extractPath,
    String targetAssetsPath,
  ) async {
    final segments = <Segment>[];

    try {
      final data = jsonDecode(contentJson);
      final segmentsList = data['segments'] as List;

      for (final seg in segmentsList) {
        final type = seg['type'] as String;

        if (type == 'text') {
          segments.add(Segment(
            type: SegmentType.text,
            text: seg['text'] as String?,
            style: _parseStyle(seg['style']),
          ));
        } else if (type == 'image') {
          // 复制图片资源
          final imagePath = seg['path'] as String?;
          if (imagePath != null) {
            final targetPath = await _copyImage(
              path.join(extractPath, imagePath),
              targetAssetsPath,
            );
            segments.add(Segment(
              type: SegmentType.image,
              path: targetPath,
              width: (seg['width'] as num?)?.toDouble(),
              height: (seg['height'] as num?)?.toDouble(),
            ));
          }
        }
      }
    } catch (e) {
      // 解析失败时返回空内容
    }

    return NoteContent(segments: segments);
  }
}
```

#### 3.2.5 GuruMindImporter（导入器主类）

```dart
/// GuruMind 导入器
class GuruMindImporter {
  final MindMapService _mindMapService;
  final GuruMindZipExtractor _zipExtractor;
  final GuruMindManifestParser _manifestParser;
  final HiveDecoder _hiveDecoder;
  final GuruMindDataConverter _dataConverter;

  GuruMindImporter(this._mindMapService)
      : _zipExtractor = GuruMindZipExtractor(),
        _manifestParser = GuruMindManifestParser(),
        _hiveDecoder = HiveDecoder(),
        _dataConverter = GuruMindDataConverter();

  /// 导入 .gurumind 文件
  Future<Topic> import(String zipPath) async {
    // 1. 解压 ZIP
    final extractPath = await _zipExtractor.extract(zipPath);

    try {
      // 2. 解析 manifest
      final manifest = await _manifestParser.parse(extractPath);

      // 3. 查找主导图
      final mindMapDoc = manifest.documents.firstWhere(
        (d) => d.type == 'mindMap',
        orElse: () => manifest.documents.first,
      );

      // 4. 解码 Hive 文件
      final hivePath = path.join(
        extractPath,
        'documents',
        mindMapDoc.id,
        'doc_${mindMapDoc.id}.hive',
      );
      final hiveDoc = await _hiveDecoder.decode(hivePath);

      // 5. 转换并保存 Topic
      final topic = await _dataConverter.convertTopic(
        manifest: manifest,
        hiveDoc: hiveDoc,
        extractPath: extractPath,
      );
      await _mindMapService.createTopicWithId(topic);

      // 6. 转换并保存所有节点
      await _importNodes(
        hiveDoc: hiveDoc,
        topicId: topic.id,
        extractPath: extractPath,
      );

      // 7. 导入标签
      await _importTags(manifest.tags, topic.id);

      return topic;
    } finally {
      // 清理临时目录
      await Directory(extractPath).delete(recursive: true);
    }
  }

  /// 导入节点树
  Future<void> _importNodes({
    required HiveDocument hiveDoc,
    required String topicId,
    required String extractPath,
  }) async {
    final rootNodeIds = hiveDoc.getStringList(4) ?? [];
    final targetAssetsPath = await _getAssetsPath(topicId);

    // 递归导入节点
    for (final nodeId in rootNodeIds) {
      await _importNodeRecursive(
        nodeId: nodeId,
        topicId: topicId,
        parentId: null,
        extractPath: extractPath,
        targetAssetsPath: targetAssetsPath,
      );
    }
  }

  /// 递归导入节点
  Future<void> _importNodeRecursive({
    required String nodeId,
    required String topicId,
    required String? parentId,
    required String extractPath,
    required String targetAssetsPath,
  }) async {
    // 解码节点 Hive 文件
    final nodeHivePath = path.join(
      extractPath,
      'documents',
      nodeId,
      'doc_$nodeId.hive',
    );

    if (!await File(nodeHivePath).exists()) return;

    final hiveDoc = await _hiveDecoder.decode(nodeHivePath);

    // 转换节点
    final note = await _dataConverter.convertNote(
      hiveDoc: hiveDoc,
      topicId: topicId,
      parentId: parentId,
      extractPath: extractPath,
      targetAssetsPath: targetAssetsPath,
    );

    // 保存节点
    await _mindMapService.createNoteWithId(note);

    // 递归导入子节点
    final childIds = hiveDoc.getStringList(4) ?? [];
    for (final childId in childIds) {
      await _importNodeRecursive(
        nodeId: childId,
        topicId: topicId,
        parentId: nodeId,
        extractPath: extractPath,
        targetAssetsPath: targetAssetsPath,
      );
    }
  }
}
```

### 3.3 数据模型映射

#### 3.3.1 GuruMind → Starmind ID 映射

| GuruMind | Starmind | 说明 |
|----------|----------|------|
| `0-{UUID}` | `0-{UUID}` | 导图 ID，保持不变 |
| `2-{UUID}` | `2-{UUID}` | 笔记节点 ID，保持不变 |
| `{UUID}` (无前缀) | `1-{UUID}` | 导图节点，添加 `1-` 前缀 |

#### 3.3.2 字段映射

**Topic 映射**：

| GuruMind 字段 | Starmind 字段 | 转换逻辑 |
|---------------|---------------|----------|
| id | id | 直接映射 |
| title | title | 直接映射 |
| createdAt | createdAt | Float64 秒数 → DateTime |
| updatedAt | updatedAt | Float64 秒数 → DateTime |
| thumbnailPath | thumbnailPath | 复制图片，更新路径 |
| - | pdfIds | 设为空数组 |
| rootNodes | rootNoteIds | 添加 `1-` 前缀 |

**Note 映射**：

| GuruMind 字段 | Starmind 字段 | 转换逻辑 |
|---------------|---------------|----------|
| id | id | 添加 `1-` 前缀 |
| - | topicId | 从导图上下文获取 |
| - | parentId | 父节点 ID 添加 `1-` 前缀 |
| title | title | 直接映射 |
| contents | content | JSON segments → NoteContent |
| position (tree) | positionX, positionY | 从 tree 数据块提取 |
| childIds | childIds | 添加 `1-` 前缀 |

---

## 4. 资源处理

### 4.1 图片资源导入

```dart
/// 图片资源处理器
class AssetImporter {
  /// 导入图片资源
  Future<String> importImage({
    required String sourcePath,
    required String targetDir,
    String? customName,
  }) async {
    final fileName = customName ?? path.basename(sourcePath);
    final targetPath = path.join(targetDir, fileName);

    // 复制图片
    await File(sourcePath).copy(targetPath);

    return targetPath;
  }

  /// 批量导入 assets 目录
  Future<Map<String, String>> importAssets({
    required String sourceAssetsPath,
    required String targetAssetsPath,
  }) async {
    final mapping = <String, String>{};

    final sourceDir = Directory(sourceAssetsPath);
    if (!await sourceDir.exists()) return mapping;

    await for (final entity in sourceDir.list(recursive: true)) {
      if (entity is File && entity.path.endsWith('.png')) {
        final relativePath = path.relative(entity.path, from: sourceAssetsPath);
        final targetPath = path.join(targetAssetsPath, relativePath);

        // 确保目标目录存在
        await Directory(path.dirname(targetPath)).create(recursive: true);

        // 复制文件
        await entity.copy(targetPath);

        // 记录映射
        mapping['assets/$relativePath'] = targetPath;
      }
    }

    return mapping;
  }
}
```

### 4.2 缩略图处理

```dart
/// 缩略图处理器
class ThumbnailProcessor {
  /// 复制并优化缩略图
  Future<String?> processThumbnail({
    required String sourcePath,
    required String targetDir,
    int maxWidth = 256,
    int maxHeight = 256,
  }) async {
    if (!await File(sourcePath).exists()) return null;

    // 读取图片
    final bytes = await File(sourcePath).readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) return null;

    // 调整大小
    final thumbnail = img.copyResize(
      image,
      width: maxWidth,
      height: maxHeight,
      interpolation: img.Interpolation.average,
    );

    // 保存
    final targetPath = path.join(targetDir, 'thumb.png');
    await File(targetPath).writeAsBytes(img.encodePng(thumbnail));

    return targetPath;
  }
}
```

---

## 5. 错误处理

### 5.1 错误类型

```dart
/// 导入错误类型
enum ImportErrorType {
  invalidZip,        // 无效的 ZIP 文件
  missingManifest,   // 缺少 manifest.json
  invalidHive,       // 无效的 Hive 文件
  missingAssets,     // 缺少资源文件
  dataCorruption,    // 数据损坏
  unsupportedVersion, // 不支持的版本
}

/// 导入异常
class ImportException implements Exception {
  final ImportErrorType type;
  final String message;
  final String? details;

  ImportException(this.type, this.message, {this.details});

  @override
  String toString() => 'ImportException: $message';
}
```

### 5.2 错误处理策略

```dart
/// 安全导入包装器
Future<ImportResult> safeImport(String zipPath) async {
  try {
    final importer = GuruMindImporter(_service);
    final topic = await importer.import(zipPath);

    return ImportResult.success(topic);
  } on ImportException catch (e) {
    return ImportResult.failure(e);
  } catch (e) {
    return ImportResult.failure(
      ImportException(ImportErrorType.dataCorruption, '导入失败', details: e.toString()),
    );
  }
}

/// 导入结果
class ImportResult {
  final bool success;
  final Topic? topic;
  final ImportException? error;

  ImportResult.success(this.topic)
      : success = true, error = null;

  ImportResult.failure(this.error)
      : success = false, topic = null;
}
```

---

## 6. 重构计划

### 6.1 Phase 3.1：ZIP 解析与元数据（2-3天）

**任务**：
1. 实现 `GuruMindZipExtractor`
2. 实现 `GuruMindManifestParser`
3. 测试 ZIP 解压和元数据解析

**验收**：
- 成功解压 `.gurumind` 文件
- 正确解析 `manifest.json`

### 6.2 Phase 3.2：Hive 解码器（3-4天）

**任务**：
1. 实现 `HiveDecoder` 核心逻辑
2. 支持字符串、数组、Float64 类型
3. 测试二进制解码

**验收**：
- 成功解码 Hive 文件
- 提取节点 ID 列表

### 6.3 Phase 3.3：数据转换与导入（3-4天）

**任务**：
1. 实现 `GuruMindDataConverter`
2. 实现 `GuruMindImporter`
3. 集成到 UI

**验收**：
- 导入的导图结构与原始一致
- 图片正确显示

### 6.4 Phase 3.4：测试与优化（1-2天）

**任务**：
1. 编写单元测试
2. 编写集成测试
3. 性能优化

---

## 7. 文件结构

```
lib/src/mindmap/
├── import/
│   ├── gurumind_importer.dart           # 主导入器
│   ├── gurumind_zip_extractor.dart      # ZIP 解压器
│   ├── gurumind_manifest_parser.dart    # 元数据解析器
│   ├── hive_decoder.dart                # Hive 解码器
│   ├── gurumind_data_converter.dart     # 数据转换器
│   ├── asset_importer.dart              # 资源导入器
│   └── import_exception.dart            # 异常定义
├── domain/
│   ├── gurumind_manifest.dart           # manifest 数据模型
│   └── hive_document.dart               # Hive 文档模型
└── test/
    └── import/
        ├── hive_decoder_test.dart
        └── gurumind_importer_test.dart
```

---

## 8. 测试策略

### 8.1 单元测试

```dart
test('HiveDecoder decodes string fields', () async {
  final decoder = HiveDecoder();
  final hiveBytes = await File('test/fixtures/sample.hive').readAsBytes();

  final doc = decoder.decodeBytes(hiveBytes);

  expect(doc.getString(0), equals('0-6f73097d-26ad-4537-9cb2-156e22f17160'));
  expect(doc.getString(1), equals('演示'));
});

test('GuruMindDataConverter converts Topic correctly', () async {
  final converter = GuruMindDataConverter();
  final manifest = GuruMindManifest(/* ... */);
  final hiveDoc = HiveDocument(/* ... */);

  final topic = await converter.convertTopic(
    manifest: manifest,
    hiveDoc: hiveDoc,
    extractPath: 'test/fixtures',
  );

  expect(topic.id, startsWith('0-'));
  expect(topic.title, equals('演示'));
});
```

### 8.2 集成测试

```dart
testWidgets('Import GuruMind file end-to-end', (tester) async {
  await tester.pumpWidget(TestMindMapApp());

  // 点击导入按钮
  await tester.tap(find.byIcon(Icons.file_upload));
  await tester.pumpAndSettle();

  // 选择测试文件
  // (需要 mock file picker)

  // 等待导入完成
  await tester.pumpAndSettle(Duration(seconds: 2));

  // 验证导图显示
  expect(find.text('演示'), findsOneWidget);
});
```

---

## 9. 风险与缓解

| 风险 | 影响 | 缓解措施 |
|------|------|----------|
| Hive 格式变化 | 高 | 版本检测，兼容性处理 |
| 图片资源缺失 | 中 | 跳过缺失资源，记录警告 |
| 大文件性能 | 中 | 流式解码，异步处理 |
| 内存占用 | 中 | 分批处理，及时释放 |

---

## 10. 验收标准

### 10.1 功能验收

- [ ] 成功导入 `.gurumind` 文件
- [ ] 节点树结构正确
- [ ] 图片资源正确显示
- [ ] 缩略图正确生成

### 10.2 质量验收

- [ ] 单元测试覆盖率 > 70%
- [ ] 无致命错误崩溃
- [ ] 导入进度显示

---

## 11. 下一步

完成阶段 3 后，进入**阶段 4：导出与刷题优化**。

---

*设计者：Claude Code*