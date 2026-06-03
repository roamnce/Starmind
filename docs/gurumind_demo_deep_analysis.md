# GuruMind 演示文档深度分析报告

> 分析日期：2026-05-31
> 分析对象：GuruMind `.gurumind` 演示文件
> 目标：验证PDF摘录、连线、子导图等高级功能的数据结构

---

## 1. 演示文件结构

### 1.1 文档组成

```
演示.gurumind (ZIP压缩包)
├── manifest.json          # 顶层元数据
├── documents/
│   ├── 0-6f73097d-.../   # 主导图
│   │   ├── meta.json      # 导图元数据
│   │   ├── doc_0-...hive  # 导图Hive数据 (34KB)
│   │   └── assets/        # 图片资源
│   │       ├── thumb.png         # 缩略图
│   │       ├── a201d4bf-...png   # PDF摘录截图 (1487x287)
│   │       ├── 1778226141...png
│   │       ├── 1778690550...png
│   │       └── 1778828880...png
│   ├── 2-248ed6bb-.../   # 笔记节点
│   │   ├── meta.json      # 节点元数据
│   │   └── doc_2-...hive  # 节点Hive数据 (693 bytes)
│   └── 270e30b3-.../     # 独立Markdown文档
│       └── 270e30b3-...md # 纯文本内容："你别管"
```

### 1.2 元数据结构

**manifest.json**
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
  "tags": [...] // 标签列表
}
```

**主导图 meta.json**
```json
{
  "id": "0-6f73097d-26ad-4537-9cb2-156e22f17160",
  "title": "演示",
  "type": "mindMap",
  "createdAt": "2026-04-28T15:26:34.578",
  "updatedAt": "2026-05-31T12:21:08.375618",
  "thumbnailPath": "documents/0-.../assets/thumb.png",
  "linkedIds": []  // 空数组
}
```

**笔记节点 meta.json**
```json
{
  "id": "2-248ed6bb-05c2-4094-9c49-32ed32225317",
  "title": "分享了几个比较有代表性的实际案例，还准备了一个所有",
  "type": "note",
  "noteType": "node",
  "linkedIds": ["0-6f73097d-26ad-4537-9cb2-156e22f17160"],  // 关联主导图！
  "createdAt": "2026-05-11T08:16:30.292",
  "updatedAt": "2026-05-31T12:20:13.716370"
}
```

---

## 2. Hive二进制数据结构

### 2.1 导图Hive文件分析

**文件头 (0x00-0x40)**
```
fa42 0000              # Hive文件头魔数
01 08 "document"       # 类型标识: document对象
20 11 00 04            # 字段定义开始
26 00 00 00            # 长度: 38 bytes (ID字符串)
"0-6f73097d-26ad-4537-9cb2-156e22f17160"  # 导图ID
01 04 06 00 00 00      # 字段索引: title
"演示"                 # UTF-8编码标题 (e6 bc 94 e7 a4 ba)
02 b6 00 ...           # 字段索引: createdAt (Float64时间戳)
03 b6 00 ...           # 字段索引: updatedAt
```

**节点ID数组 (0x80-0x180)**
```
04 24 00 00 00         # 字段索引: rootNodes (数组开始)
"b9b32257-0868-45a1-9dd2-05a15f09b34a"  # 第1个节点ID (无前缀!)
15 0b 12 00 00 00      # 数组长度: 18个节点
04 24 00 00 00         # 重复节点ID (冗余存储?)
"b9b32257-0868-45a1-9dd2-05a15f09b34a"
...
```

**发现的节点ID (28个UUID)**
- `b9b32257-0868-45a1-9dd2-05a15f09b34a`
- `ef437f71-d462-4ddc-ac87-8850af949dfa`
- `16ee3d66-d830-49f1-8737-6eefa6089a7f`
- `36b58511-833d-4846-873e-292eb88a5628`
- ... (共28个)

**重要发现：节点ID格式**
- GuruMind的节点ID **没有前缀** (`b9b32257-...`)，而非 `1-xxx`
- 只有文档ID有前缀 (`0-xxx` 导图, `2-xxx` 笔记)

### 2.2 树结构数据 (Tree Layout)

**"tree" 标记位置 (offset: 0x1C0)**
```
"tree"                 # 树结构标识
01 36 10 00            # 树数据长度
e8 00 00 40 43 43 e3 ef 41   # 坐标数据 (Float64)
01 e8 00 00 40 da 2e e3 ef 41 # x/y坐标对
02 e8 00 00 20 5f 19 f2 ef 41
03 e8 00 00 40 45 45 e5 ef 41
04 e8 00 00 a0 ae ae ee ef 41
05 e8 00 00 00 1c 1c fc ef 41
06 03 01 07 e8 00 00 40 45 45 e5 ef 41
```

**坐标解析尝试**
- `e8 00 00 40 43 43 e3 ef 41` → 可能是 Float64: ~280.0
- `e8 00 00 40 da 2e e3 ef 41` → 可能是 Float64: ~280.5
- 看起来是 **节点布局坐标** (x/y位置)

### 2.3 富文本内容 (JSON Segments)

**文本摘录示例**
```json
{
  "segments": [
    {
      "type": "text",
      "text": "Currently, herbicides, as the main means of weed control, are commonly usedfor their low cost and effectiveness [4]. However, overuse not only affects crop yields butalso causes ecological issues such as",
      "style": {
        "bold": false,
        "italic": false,
        "underline": false,
        "strikethrough": false,
        "cloze": false,  // 填空标记!
        "link": null,
        "textColor": null,
        "backgroundColor": null,
        "fontSize": null,
        "textAlign": null
      }
    }
  ]
}
```

**图片摘录示例 (PDF截图)**
```json
{
  "segments": [
    {
      "type": "image",
      "path": "assets/a201d4bf-e167-4c6b-b2c9-052611cd0b59.png",
      "base64": null,
      "url": null,
      "width": 400.0,
      "height": 77.20242098184264,
      "fit": 1  // 图片适配模式
    }
  ]
}
```

---

## 3. 关键发现：PDF摘录支持

### 3.1 PDF摘录截图

**图片文件分析**
```
a201d4bf-e167-4c6b-b2c9-052611cd0b59.png
格式: PNG RGBA
尺寸: 1487 x 287 pixels
用途: PDF文本摘录截图
```

**JSON segments中的引用**
```json
{
  "type": "image",
  "path": "assets/a201d4bf-...png",
  "width": 400.0,
  "height": 77.2...,
  "fit": 1
}
```

### 3.2 摘录机制推断

**GuruMind的PDF摘录流程**
1. 用户在PDF中选中文本
2. 系统截取高亮区域 **生成PNG图片**
3. 图片保存到 `assets/` 目录
4. JSON segments记录:
   - `type: "image"` (图片类型)
   - `path: "assets/xxx.png"` (相对路径)
   - `width/height` (显示尺寸)
   - `fit: 1` (适配模式)

**关键差异：GuruMind vs MarginNote**

| 特性 | MarginNote | GuruMind |
|------|------------|----------|
| **摘录存储** | 高亮坐标+文本 | 截图PNG图片 |
| **位置信息** | 页码+坐标 | ❌ 无页码字段 |
| **文本存储** | `ZHIGHLIGHT_TEXT` | JSON segments |
| **图片格式** | BLOB缩略图 | PNG RGBA全尺寸 |
| **OCR支持** | ✅ `ZRECOGNIZE_TEXT` | ❌ 未发现 |
| **回溯定位** | ✅ 可返回PDF位置 | ❌ 无法定位原文 |

---

## 4. 连线与子导图

### 4.1 连线数据

**搜索结果：未找到明确的连线字段**

尝试的关键词搜索：
- `link`, `Link`, `connection`, `Connection`
- `edge`, `Edge`, `line`, `Line`
- `sourceId`, `targetId`, `fromId`, `toId`

**推断：连线可能隐含在树结构中**
- `tree` 数据块可能包含连线布局信息
- 节点间的父子关系通过 **节点ID嵌套** 表示

### 4.2 子导图

**搜索结果：未找到子导图字段**

关键词搜索：
- `childMap`, `subMap`, `nestedMap`
- `childTopic`, `subTopic`

**推断：子导图可能通过节点嵌套实现**
- 未发现独立的子导图实体
- 可能只是节点的层级嵌套

---

## 5. 节点笔记功能

### 5.1 笔记节点结构

**节点hive数据**
```
e7 00 00 00            # 文件头
01 08 "document"       # 类型: document
86 0b 00 04            # 字段定义
26 00 00 00            # ID长度
"2-248ed6bb-05c2-4094-9c49-32ed32225317"  # 节点ID
01 04 4b 00 00 00      # title字段
"分享了几个比较有代表性的实际案例..."  # 标题 (UTF-8)
02 b6 00 40 c5 47 46 e1 79 42  # createdAt
03 b6 00 40 c5 47 46 e1 79 42  # updatedAt
04 03 00 05 00 06 00 07        # 字段索引数组
09 00 00 00 00         # linkedIds长度: 0
09 09 01 00 00 00      # linkedIds数组长度: 1
26 00 00 00            # ID长度
"0-6f73097d-26ad-4537-9cb2-156e22f17160"  # 关联导图ID
14 00                  # 字段结束标记
```

### 5.2 关联机制

**linkedIds字段**
```json
{
  "linkedIds": ["0-6f73097d-26ad-4537-9cb2-156e22f17160"]
}
```

**双向关联**
- 笔记节点知道它属于哪个导图 (`linkedIds`)
- 导图知道它有哪些节点 (`rootNodes` 数组)

---

## 6. 核心数据模型总结

### 6.1 GuruMind完整数据结构

**导图实体 (MindMap)**
```dart
class MindMapDocument {
  String id;                    // "0-{UUID}"
  String title;                 // 导图标题
  DateTime createdAt;
  DateTime updatedAt;
  String thumbnailPath;         // 缩略图路径
  List<String> linkedIds;       // 空数组
  
  // Hive二进制数据
  List<String> rootNodes;       // 节点ID数组 (无前缀UUID)
  TreeLayout tree;              // 布局坐标数据
  List<NodeContent> contents;   // 节点内容 (JSON segments)
}
```

**节点内容 (NodeContent)**
```dart
class NodeContent {
  String nodeId;                // 无前缀UUID
  String title;                 // 节点标题
  
  // JSON segments 富文本
  List<Segment> segments;
}

class Segment {
  String type;                  // "text" | "image"
  
  // 文本类型
  String? text;
  TextStyle? style;
  
  // 图片类型 (PDF摘录)
  String? path;                 // "assets/xxx.png"
  double? width;
  double? height;
  int? fit;                     // 适配模式
}
```

**笔记节点实体 (Note)**
```dart
class NoteDocument {
  String id;                    // "2-{UUID}"
  String title;
  String noteType;              // "node"
  List<String> linkedIds;       // ["0-{导图ID}"]
  DateTime createdAt;
  DateTime updatedAt;
  
  // Hive二进制数据
  String content;               // 笔记内容
}
```

### 6.2 与MarginNote对比更新

| 特性 | MarginNote | GuruMind (验证后) |
|------|------------|-------------------|
| **PDF摘录** | ✅ 页码+坐标+文本 | ⚠️ 仅截图PNG |
| **位置回溯** | ✅ 可返回PDF | ❌ 无页码字段 |
| **文本存储** | `ZHIGHLIGHT_TEXT` | JSON `segments.text` |
| **图片存储** | BLOB缩略图 | PNG RGBA全尺寸 |
| **连线** | 管道分隔 `childIds` | ⚠️ 未找到明确字段 |
| **子导图** | `ZCHILDMAPNOTEID` | ⚠️ 未找到明确字段 |
| **节点笔记** | `ZNOTES_TEXT` | ✅ 独立笔记节点 |
| **富文本** | Apple bplist | ✅ JSON segments |
| **反向索引** | ❌ 无parent_id | ✅ `linkedIds` |

---

## 7. 结论与建议

### 7.1 GuruMind的PDF摘录缺陷

**核心问题：无法回溯PDF原文**
- ✅ 支持摘录截图
- ❌ 无页码字段
- ❌ 无坐标信息
- ❌ 无法定位原文位置

**影响**
- 用户无法从导图节点跳回PDF原文
- 无法支持跨设备同步PDF位置
- 无法实现MarginNote的核心交互体验

### 7.2 GuruMind的优势

1. **JSON segments富文本** - 标准化、易解析
2. **linkedIds反向索引** - 节点知道属于哪个导图
3. **ID前缀设计** - 类型识别 (`0-xxx`/`2-xxx`)
4. **Hive高性能** - Flutter原生二进制序列化
5. **cloze填空标记** - 学习卡片功能

### 7.3 Starmind最优方案（最终版）

**保留MarginNote核心**
- ✅ PDF摘录页码+坐标
- ✅ 管道分隔childIds
- ✅ USN同步版本号

**采纳GuruMind优势**
- ✅ JSON segments富文本
- ✅ linkedIds反向索引
- ✅ ID前缀类型区分

**新增优化**
- ✅ parent_id反向索引（解决全表扫描）
- ✅ 标准化富文本格式
- ✅ 填空cloze标记

**最终推荐数据模型：保持之前的对比分析方案不变**

---

*分析工具：二进制解析、UTF-8解码、JSON提取*
*分析对象：GuruMind演示文档 (含PDF摘录、连线、子导图)*