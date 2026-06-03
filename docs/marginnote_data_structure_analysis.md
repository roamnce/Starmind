# MarginNote 数据结构逆向分析报告

> 分析日期：2026-05-31
> 分析对象：MarginNote `.marginnotes` 文件格式
> 目标：为 Starmind (Flutter + Rust) 提供数据结构参考

---

## 1. 文件格式概述

### 1.1 文件本质

`.marginnotes` 文件本质上是一个 **SQLite 3 数据库**：

```
SQLite format 3.
Page size: 4096 bytes
Total pages: 3725 (约 15MB)
Schema version: 4
```

### 1.2 文件组织

MarginNote 的笔记本采用单文件存储模式：
- 一个 `.marginnotes` 文件 = 一个导图笔记本
- 包含该笔记本的所有笔记、导图结构、媒体资源
- 导出/分享时直接传输该文件（或压缩为 zip）

---

## 2. 核心数据表结构

### 2.1 表清单

| 表名 | 用途 | 记录数（样本） |
|------|------|----------------|
| ZBOOKNOTE | 笔记/导图节点 | 87 |
| ZTOPIC | 导图笔记本元数据 | 1 |
| ZBOOKCONFIG | PDF配置（页面信息、进度） | 1 |
| ZMEDIA | 图片媒体存储 | 89 |
| ZACTIVITY | 学习活动追踪 | - |
| ZBOOKCOMMENT | 评论系统 | - |
| ZBOOKTAG | 标签系统 | - |
| ZEPUBRANGE | EPUB阅读范围 | - |
| ZUSER | 用户信息 | - |

### 2.2 ZBOOKNOTE（核心笔记表）

这是 MarginNote 的核心表，存储所有笔记节点和导图结构。

#### 字段详解

```sql
CREATE TABLE ZBOOKNOTE (
  -- CoreCore Metadata
  Z_PK INTEGER PRIMARY KEY,
  Z_ENT INTEGER,          -- 实体类型（CoreData内部）
  Z_OPT INTEGER,          -- 优化标记

  -- 内容字段
  ZNOTEID VARCHAR,        -- UUID主键，如 "AE5C45F0-6EF5-4B74-B5D2-99E17B5D2C94"
  ZNOTETITLE VARCHAR,     -- 节点标题，如 "2021.25"、"绝对极端说法"
  ZHIGHLIGHT_TEXT VARCHAR,-- PDF摘录原文（可选）
  ZNOTES_TEXT VARCHAR,    -- 用户笔记内容（可选）
  ZTYPE INTEGER,          -- 类型: 256=笔记节点, 4=其他类型

  -- 关联字段
  ZBOOKMD5 VARCHAR,       -- 关联PDF的MD5标识
  ZTOPICID VARCHAR,       -- 所属导图ID

  -- 导图结构（关键！）
  ZMINDLINKS VARCHAR,     -- 子节点ID列表，管道分隔: "uuid1|uuid2|uuid3"
  ZCHILDMAPNOTEID VARCHAR,-- 子导图链接（嵌套导图）
  ZGROUPNOTEID VARCHAR,   -- 组链接（合并节点）

  -- PDF位置
  ZSTARTPAGE INTEGER,     -- 起始页码
  ZENDPAGE INTEGER,       -- 结束页码
  ZSTARTPOS VARCHAR,      -- 起始位置坐标
  ZENDPOS VARCHAR,        -- 结束位置坐标

  -- 样式
  ZHIGHLIGHT_STYLE VARCHAR,-- 高亮样式类名: "mbooks-annotation12"

  -- 媒体
  ZMEDIA_LIST VARCHAR,    -- 关联图片MD5列表: "md5a|md5b"
  ZHIGHLIGHT_PIC BLOB,    -- 高亮区域截图
  ZHIGHLIGHTS BLOB,       -- 高亮区域数据（bplist格式）
  ZNOTES BLOB,            -- 笔记附加数据（bplist格式）
  ZRECOGNIZE_MEDIA VARCHAR,-- OCR识别媒体
  ZRECOGNIZE_TEXT VARCHAR,-- OCR识别文本

  -- 时间戳
  ZHIGHLIGHT_DATE TIMESTAMP,
  ZNOTE_DATE TIMESTAMP,

  -- 同步
  ZEVERNOTEID VARCHAR,    -- Evernote同步ID
  ZUSNFTS INTEGER,        -- 文件同步版本号
  ZUSNPROPERTIES INTEGER, -- 属性同步版本号

  -- 其他
  ZZINDEX INTEGER,        -- Z排序索引
  ZMINDCLOSE INTEGER      -- 导图折叠状态
);
```

#### 数据样本

```
ZNOTEID: AE5C45F0-6EF5-4B74-B5D2-99E17B5D2C94
ZNOTETITLE: 2021.25
ZHIGHLIGHT_TEXT: (空)
ZNOTES_TEXT: D提高就业质量和失业率保持合理区间无关
             这里谈论的是质量问题，而不是就业数量问题
             排除D，选ABC
ZTYPE: 256
ZMINDLINKS: (空)
ZBOOKMD5: 2e837b2a8dc16e19d500f1ea6cc4d1bd
ZTOPICID: AB546107-3A20-4336-93F8-81E3E349A59D
ZHIGHLIGHT_STYLE: mbooks-annotation12
```

#### 导图结构示例

```
父节点 ZNOTEID: 281B9218-7D1C-4A32-8DC1-BE72F70126B4
ZNOTETITLE: 绝对极端说法
ZMINDLINKS: 878E12F4-7B33-4514-A5C5-9E84AB511B51|2AA80A5D-C188-4098-977C-82F847C9CA2E|A07B5595-710B-4A76-83D1-F1AFD9B1D42F|...

子节点:
- 878E12F4... → 标题: 2020.31
- 2AA80A5D... → 标题: 2020.18
- A07B5595... → 标题: 2021.3
```

### 2.3 ZTOPIC（导图笔记本表）

```sql
CREATE TABLE ZTOPIC (
  Z_PK INTEGER PRIMARY KEY,
  ZTOPICID VARCHAR,       -- 导图UUID
  ZTITLE VARCHAR,         -- 导图标题: "政治解题方法一页纸（含答案和解析）"
  ZAUTHOR VARCHAR,        -- 作者
  ZDATE TIMESTAMP,        -- 创建时间
  ZLASTVISIT TIMESTAMP,   -- 最后访问
  ZMINDLINKS VARCHAR,     -- 根节点ID列表（管道分隔）
  ZBOOKLIST VARCHAR,      -- 关联PDF列表（管道分隔）
  ZTAGLIST VARCHAR,       -- 标签列表
  ZHASHTAGS VARCHAR,      -- JSON格式的标签配置
  ZTHUMBNAILS BLOB,       -- 缩略图
  ZDELNOTES BLOB,         -- 已删除笔记记录
  ZFORUMID VARCHAR,       -- 论坛分享ID
  ZPRIVATEFORUM INTEGER,  -- 私有论坛标记
  ZISLINK INTEGER,        -- 链接导图标记
  ZSYNCDIRTY INTEGER,     -- 同步脏标记
  ZSYNCMODE INTEGER,      -- 同步模式
  ZTOPICFLAGS INTEGER,    -- 导图标志位
  ZUSNFTS INTEGER,
  ZUSNPROPERTIES INTEGER,
  ZHISTORYDATE TIMESTAMP,
  ZEVERNOTEID VARCHAR,
  ZEXPORTEVERNOTEID VARCHAR,
  ZLOCALBOOKMD5 VARCHAR,
  ZISCHINA INTEGER
);
```

### 2.4 ZMEDIA（媒体表）

```sql
CREATE TABLE ZMEDIA (
  Z_PK INTEGER PRIMARY KEY,
  ZMD5 VARCHAR,           -- 图片MD5（主键）
  ZDATA BLOB,             -- 图片数据（PNG/JPEG）
  ZTHUMBNAIL BLOB         -- 缩略图数据
);
```

样本数据：
- 89张图片，平均大小约 200KB
- 最大图片：500KB
- 最小图片：3KB

### 2.5 ZBOOKCONFIG（PDF配置表）

存储PDF阅读状态和页面信息：

```sql
CREATE TABLE ZBOOKCONFIG (
  ZCURRPAGE INTEGER,      -- 当前页码
  ZCURRPAGEOFF INTEGER,   -- 页面偏移
  ZCURRPAGEPERCENT FLOAT, -- 阅读进度百分比
  ZFONTSCALE FLOAT,       -- 字体缩放
  ZFONTNAME VARCHAR,      -- 字体名称
  ZMD5 VARCHAR,           -- PDF MD5短版本
  ZMD5LONG VARCHAR,       -- PDF MD5完整版本
  ZTITLE VARCHAR,         -- PDF标题
  ZOPTIONS VARCHAR,       -- JSON格式的页面尺寸信息
  ZTAGLIST VARCHAR,
  ZCLOUDURL VARCHAR,
  ZSYNCMODE INTEGER,
  ZUSNFTS INTEGER,
  ZUSNPROPERTIES INTEGER
);
```

OPTIONS 字段存储页面尺寸（JSON格式）：
```json
{
  "originalPagesInfo2": [
    {"mediaRect": {"h": 841.89, "w": 595.28, "x": 0, "y": 0}, "rotation": 0},
    ...
  ]
}
```

---

## 3. 导图结构设计分析

### 3.1 核心设计模式

MarginNote 采用 **扁平化存储 + 引用链接** 模式：

```
┌─────────────────────────────────────────────────────────┐
│                    ZBOOKNOTE 表                          │
│  (所有节点存储在同一张表中)                               │
├─────────────────────────────────────────────────────────┤
│  节点A: ZMINDLINKS = "节点B|节点C|节点D"                  │
│  节点B: ZMINDLINKS = "节点E|节点F"                        │
│  节点C: ZMINDLINKS = ""                                  │
│  节点D: ZMINDLINKS = "节点G"                             │
│  ...                                                     │
└─────────────────────────────────────────────────────────┘
```

**特点：**
- 没有单独的"边表"或"关系表"
- 父子关系通过管道符分隔的 UUID 列表存储
- 一个节点可以被多个父节点引用（多父节点）
- 支持嵌套导图（ZCHILDMAPNOTEID）

### 3.2 UUID 选择分析

MarginNote 使用 **UUID 格式**：
```
AE5C45F0-6EF5-4B74-B5D2-99E17B5D2C94
```

**优点：**
- 全局唯一，便于跨设备同步
- 无需服务器分配，客户端生成
- 合并冲突时不会ID冲突

**缺点：**
- 36字符，占用空间较大
- 无序，不利于排序查询

### 3.3 管道符分隔格式

```
ZMINDLINKS = "uuid1|uuid2|uuid3|uuid4"
```

**优点：**
- 简单直观，易于解析
- 单字段存储，减少JOIN查询
- 支持有序存储（顺序即子节点顺序）

**缺点：**
- 更新子节点需修改父节点记录
- 查找某节点的所有父节点需全表扫描

---

## 4. 高亮样式系统

### 4.1 样式命名规则

MarginNote 使用 CSS 类名风格的样式标识：

| 样式名 | 用途推测 |
|--------|----------|
| mbooks-annotation1 | 黄色高亮 |
| mbooks-annotation1c | 某种颜色（样本中出现） |
| mbooks-annotation2 | 另一种颜色 |
| mbooks-annotation12 | 第12种样式 |

### 4.2 高亮数据存储

`ZHIGHLIGHTS` 字段存储高亮区域数据，使用 **Apple bplist** 格式：
```
bplist00...X$versionY$archiverT$topX$objects...
```

这是 Apple 的二进制 plist 格式，用于存储精确的高亮坐标区域。

---

## 5. PDF摘录机制

### 5.1 位置信息存储

MarginNote 存储两种位置信息：

**页码范围：**
- ZSTARTPAGE / ZENDPAGE：跨页摘录支持

**坐标位置：**
- ZSTARTPOS / ZENDPOS：页面内精确坐标
- 格式示例：`11974.710938,14507.926758`（可能为PDF坐标）

### 5.2 PDF识别

通过 MD5 唯一标识 PDF：
- ZMD5：短MD5（32字符）
- ZMD5LONG：完整MD5（64字符）

---

## 6. 同步与版本控制

MarginNote 使用 **USN (Update Sequence Number)** 机制：

```sql
ZUSNFTS INTEGER,        -- 文件同步版本号
ZUSNPROPERTIES INTEGER, -- 属性同步版本号
```

类似 Evernote 的同步机制：
- 每次修改递增版本号
- 同步时比较版本号决定上传/下载
- 支持增量同步

---

## 7. 对 Starmind 的设计建议

### 7.1 推荐数据结构

基于 MarginNote 的成功模式，推荐 Starmind 采用类似设计：

#### Rust 数据模型

```rust
// mindmap_node.rs
use serde::{Deserialize, Serialize};
use sqlx::FromRow;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct MindMapNode {
    // 核心标识
    pub id: String,              // UUID v4
    pub title: String,           // 标题

    // 内容
    pub highlight_text: Option<String>,  // PDF摘录原文
    pub note_text: Option<String>,       // 用户笔记
    pub node_type: i32,                  // 类型: 256=笔记

    // 关联
    pub pdf_id: Option<String>,  // PDF MD5
    pub topic_id: String,        // 所属导图

    // 导图结构
    pub child_ids: Option<String>, // 管道分隔: "id1|id2|id3"
    pub parent_id: Option<String>, // 主父节点（优化查询）

    // PDF位置
    pub start_page: Option<i32>,
    pub end_page: Option<i32>,
    pub position_json: Option<String>, // JSON格式坐标

    // 样式
    pub highlight_style: Option<String>, // 样式类名

    // 媒体
    pub media_ids: Option<String>,  // 管道分隔的媒体ID

    // 元数据
    pub created_at: i64,  // Unix timestamp
    pub updated_at: i64,
    pub is_collapsed: bool,
    pub z_index: i32,
}
```

#### SQLite 表定义

```sql
CREATE TABLE mindmap_nodes (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    highlight_text TEXT,
    note_text TEXT,
    node_type INTEGER DEFAULT 256,
    pdf_id TEXT,
    topic_id TEXT NOT NULL,
    child_ids TEXT,
    parent_id TEXT,
    start_page INTEGER,
    end_page INTEGER,
    position_json TEXT,
    highlight_style TEXT DEFAULT 'highlight-yellow',
    media_ids TEXT,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    is_collapsed INTEGER DEFAULT 0,
    z_index INTEGER DEFAULT 0
);

CREATE INDEX idx_nodes_topic ON mindmap_nodes(topic_id);
CREATE INDEX idx_nodes_pdf ON mindmap_nodes(pdf_id);
CREATE INDEX idx_nodes_parent ON mindmap_nodes(parent_id);
CREATE INDEX idx_nodes_created ON mindmap_nodes(created_at);
```

### 7.2 Flutter 端适配

```dart
// mindmap_node.dart
class MindMapNode extends TreeNode {
  final String id;
  final String title;
  final String? highlightText;
  final String? noteText;
  final String? pdfId;
  final String topicId;
  final String? childIdsRaw;
  final String? parentId;
  final int? startPage;
  final int? endPage;
  final String? positionJson;
  final String? highlightStyle;
  final String? mediaIdsRaw;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isCollapsed;
  final int zIndex;

  MindMapNode({
    required this.id,
    required this.title,
    this.highlightText,
    this.noteText,
    this.pdfId,
    required this.topicId,
    this.childIdsRaw,
    this.parentId,
    this.startPage,
    this.endPage,
    this.positionJson,
    this.highlightStyle,
    this.mediaIdsRaw,
    required this.createdAt,
    required this.updatedAt,
    this.isCollapsed = false,
    this.zIndex = 0,
  });

  // 解析子节点ID列表
  List<String> get childIds {
    if (childIdsRaw == null || childIdsRaw!.isEmpty) return [];
    return childIdsRaw!.split('|').where((s) => s.isNotEmpty).toList();
  }

  // TreeNode 接口实现
  @override
  String get name => title;

  @override
  List<TreeNode> get children {
    // 需要从 repository 加载实际节点
    return _cachedChildren ?? [];
  }

  @override
  int get documentCount => 0;

  List<MindMapNode>? _cachedChildren;

  void loadChildren(List<MindMapNode> nodes) {
    _cachedChildren = nodes;
  }
}
```

### 7.3 FFI 接口设计

```rust
// ffi.rs
use flutter_rust_bridge::*;

#[frb]
pub async fn create_node(
    title: String,
    topic_id: String,
    highlight_text: Option<String>,
    note_text: Option<String>,
    pdf_id: Option<String>,
) -> Result<String, String> {
    let id = uuid::Uuid::new_v4().to_string();
    let now = chrono::Utc::now().timestamp();

    sqlx::query!(
        "INSERT INTO mindmap_nodes (id, title, topic_id, highlight_text, note_text, pdf_id, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
        id, title, topic_id, highlight_text, note_text, pdf_id, now, now
    )
    .execute(&*POOL)
    .await?;

    Ok(id)
}

#[frb]
pub async fn get_node_children(parent_id: String) -> Result<Vec<MindMapNode>, String> {
    let parent = sqlx::query_as!(
        MindMapNode,
        "SELECT * FROM mindmap_nodes WHERE id = ?",
        parent_id
    )
    .fetch_one(&*POOL)
    .await?;

    let child_ids = parent.child_ids.unwrap_or_default();
    let ids: Vec<&str> = child_ids.split('|').filter(|s| !s.is_empty()).collect();

    if ids.is_empty() {
        return Ok(vec![]);
    }

    let children = sqlx::query_as!(
        MindMapNode,
        "SELECT * FROM mindmap_nodes WHERE id IN (?) ORDER BY z_index",
        ids.join(",")
    )
    .fetch_all(&*POOL)
    .await?;

    Ok(children)
}

#[frb]
pub async fn add_child_to_node(parent_id: String, child_id: String) -> Result<(), String> {
    let parent = sqlx::query_as!(
        MindMapNode,
        "SELECT * FROM mindmap_nodes WHERE id = ?",
        parent_id
    )
    .fetch_one(&*POOL)
    .await?;

    let mut child_ids = parent.child_ids.unwrap_or_default();
    if !child_ids.is_empty() {
        child_ids.push('|');
    }
    child_ids.push_str(&child_id);

    let now = chrono::Utc::now().timestamp();

    sqlx::query!(
        "UPDATE mindmap_nodes SET child_ids = ?, updated_at = ? WHERE id = ?",
        child_ids, now, parent_id
    )
    .execute(&*POOL)
    .await?;

    sqlx::query!(
        "UPDATE mindmap_nodes SET parent_id = ?, updated_at = ? WHERE id = ?",
        parent_id, now, child_id
    )
    .execute(&*POOL)
    .await?;

    Ok(())
}
```

---

## 8. 实现可行性评估

### 8.1 Flutter + Rust 架构优势

| 方面 | 评估 | 说明 |
|------|------|------|
| 数据存储 | ✅ 极易实现 | SQLite 是 Rust 常用方案，Flutter 也有良好支持 |
| FFI通信 | ✅ 已有方案 | flutter_rust_bridge 已成熟，支持异步 |
| PDF渲染 | ⚠️ 需引入库 | Flutter: pdfx / Rust: pdfium |
| 导图绘制 | ⚠️ 需自实现 | Flutter CustomPaint / InteractiveViewer |
| OCR识别 | ⚠️ 需集成 | Rust: tesseract / 云服务API |
| 同步机制 | ⚠️ 中等难度 | 需设计USN机制 + 云存储 |

### 8.2 核心功能实现难度

| 功能 | 难度 | 工作量估算 | 技术方案 |
|------|------|------------|----------|
| 数据库CRUD | ★☆☆ | 1-2天 | sqlx + SQLite |
| 导图树结构 | ★★☆ | 3-5天 | TreeNode模式 + 懒加载 |
| PDF摘录 | ★★★ | 5-7天 | pdfium + 坐标转换 |
| 高亮渲染 | ★★★ | 3-5天 | CustomPaint + PDF坐标映射 |
| 导图可视化 | ★★★★ | 10-15天 | InteractiveViewer + 拖拽 |
| 媒体管理 | ★★☆ | 2-3天 | BLOB存储或文件系统 |
| 跨设备同步 | ★★★★★ | 15-20天 | 云存储 + USN机制 |

### 8.3 与 MarginNote 的差距

**MarginNote 核心优势（需要重点攻克）：**

1. **PDF摘录体验**
   - MarginNote: 选中文本 → 自动创建节点 → 拖拽到导图
   - 实现: 需要精确的PDF文本选区 + 坐标映射 + 实时预览

2. **导图交互**
   - MarginNote: 自由布局、拖拽连接、双击编辑、手势缩放
   - 实现: Flutter InteractiveViewer + GestureDetector + 状态管理

3. **多文档整合**
   - MarginNote: 一个导图关联多个PDF，跨PDF引用
   - 实现: topic_id + pdf_id 的多对多关系

4. **OCR识别**
   - MarginNote: 图片摘录自动OCR
   - 实现: Tesseract集成或云服务

### 8.4 快速复刻路线图

#### Phase 1: 基础架构（1周）

```
✅ SQLite数据库设计
✅ Rust数据模型 + FFI接口
✅ Flutter基础UI框架
✅ TreeNode树结构实现
```

#### Phase 2: 核心功能（2周）

```
✅ 导图节点CRUD
✅ 导图可视化（InteractiveViewer）
✅ 笔记编辑界面
✅ 媒体上传/显示
```

#### Phase 3: PDF集成（2周）

```
⚠️ PDF渲染器选型
⚠️ 文本选区实现
⚠️ 高亮渲染
⚠️ 摘录→导图节点流程
```

#### Phase 4: 高级功能（3周）

```
⚠️ 导图布局算法
⚠️ 拖拽连接
⚠️ 跨PDF引用
⚠️ 搜索功能
```

#### Phase 5: 同步与优化（2周）

```
⚠️ 云同步机制
⚠️ 性能优化
⚠️ 缓存策略
```

---

## 9. 结论

### 9.1 数据结构复刻可行性：**高**

MarginNote 的数据结构设计简洁高效，完全可以快速复刻：

- ✅ SQLite 单文件存储模式成熟可靠
- ✅ UUID + 管道分隔格式易于实现
- ✅ Rust sqlx + Flutter sqflite 完美适配

### 9.2 全功能复刻可行性：**中等**

完整复刻 MarginNote 需要攻克几个难点：

1. **PDF摘录体验**（最大难点）
   - 需要高质量的PDF文本选区
   - 需要精确的坐标映射
   - 建议：先用 pdfx 快速原型，后期换 pdfium 优化

2. **导图交互**
   - Flutter 有良好的手势支持
   - 但需要大量细节打磨

3. **跨设备同步**
   - USN机制相对简单
   - 但云存储需要后端支持

### 9.3 建议：分阶段迭代

**第一阶段目标：**
做一个能用的"笔记导图工具"，暂不追求PDF摘录完美。

- 实现导图节点CRUD
- 实现导图可视化
- 支持手动创建节点、编辑笔记
- 支持图片上传

**第二阶段目标：**
加入PDF摘录功能。

**第三阶段目标：**
完善交互体验、同步功能。

---

## 附录：MarginNote 数据样本

### A. 完整节点示例

```json
{
  "ZNOTEID": "AE5C45F0-6EF5-4B74-B5D2-99E17B5D2C94",
  "ZNOTETITLE": "2021.25",
  "ZHIGHLIGHT_TEXT": null,
  "ZNOTES_TEXT": "D提高就业质量和失业率保持合理区间无关\n这里谈论的是质量问题，而不是就业数量问题\n排除D，选ABC",
  "ZTYPE": 256,
  "ZMINDLINKS": null,
  "ZBOOKMD5": "2e837b2a8dc16e19d500f1ea6cc4d1bd",
  "ZTOPICID": "AB546107-3A20-4336-93F8-81E3E349A59D",
  "ZHIGHLIGHT_STYLE": "mbooks-annotation12",
  "ZMEDIA_LIST": "8fbd82bfc432a3a9e02b90447d2883e7-",
  "ZNOTE_DATE": 784034888.766797,
  "ZHIGHLIGHT_DATE": 783645831.201362
}
```

### B. 导图结构示例

```json
{
  "父节点": {
    "id": "281B9218-7D1C-4A32-8DC1-BE72F70126B4",
    "title": "绝对极端说法",
    "children": [
      "878E12F4-7B33-4514-A5C5-9E84AB511B51",
      "2AA80A5D-C188-4098-977C-82F847C9CA2E",
      "A07B5595-710B-4A76-83D1-F1AFD9B1D42F",
      "..."
    ]
  },
  "子节点": [
    {"id": "878E12F4...", "title": "2020.31"},
    {"id": "2AA80A5D...", "title": "2020.18"},
    {"id": "A07B5595...", "title": "2021.3"}
  ]
}
```

---

*文档生成工具：Claude Code*
*分析对象：MarginNote 3 (iOS/macOS)*