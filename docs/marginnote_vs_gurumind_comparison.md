# MarginNote vs GuruMind 数据结构对比分析

> 分析日期：2026-05-31
> 目标：为 Starmind (Flutter + Rust) 设计最优数据模型

---

## 1. 核心架构对比

| 维度 | MarginNote | GuruMind |
|------|------------|----------|
| **存储格式** | SQLite 单文件 | ZIP包 + Hive二进制 |
| **文件扩展名** | `.marginnotes` | `.gurumind` |
| **导图结构** | 单表扁平化 | 多文档分片 |
| **ID格式** | UUID (36字符) | UUID + 类型前缀 (`0-xxx`/`2-xxx`) |
| **技术栈** | CoreData + SQLite | Flutter Hive |
| **子节点存储** | 管道分隔 (`uuid1|uuid2`) | Hive嵌套结构 |
| **富文本格式** | bplist (Apple私有) | JSON segments |

---

## 2. 数据模型详解

### 2.1 MarginNote 设计模式

**核心表：ZBOOKNOTE**
```sql
ZNOTEID: UUID主键
ZNOTETITLE: 节点标题
ZHIGHLIGHT_TEXT: PDF摘录原文
ZNOTES_TEXT: 用户笔记内容
ZMINDLINKS: 子节点ID列表（管道分隔: "uuid1|uuid2|uuid3"）
ZBOOKMD5: 关联PDF的MD5
ZTOPICID: 所属导图ID
ZSTARTPAGE/ZENDPAGE: PDF页码范围
ZHIGHLIGHT_STYLE: 高亮样式
ZMEDIA_LIST: 图片MD5列表（管道分隔）
ZHIGHLIGHT_DATE/ZNOTE_DATE: 时间戳
```

**特点：**
- ✅ 单表存储，查询简单
- ✅ 管道分隔子节点，顺序存储
- ✅ 跨PDF引用（通过MD5）
- ⚠️ 无层级索引，查找父节点需全表扫描
- ⚠️ 子节点更新需修改父记录

### 2.2 GuruMind 设计模式

**文档分层结构：**
```json
// manifest.json
{
  "version": 1,
  "documents": [{"id": "0-xxx", "type": "mindMap", "title": "导图名"}],
  "tags": [{"id": "xxx", "name": "标签名", "color": 4287532691}]
}

// documents/0-xxx/meta.json (导图)
{
  "id": "0-xxx",
  "title": "MarginNote导图",
  "type": "mindMap",
  "createdAt": "ISO时间",
  "updatedAt": "ISO时间",
  "thumbnailPath": "assets/thumb.png",
  "linkedIds": []
}

// documents/2-xxx/meta.json (节点)
{
  "id": "2-xxx",
  "title": "节点标题",
  "type": "note",
  "noteType": "node",
  "linkedIds": ["0-xxx"],  // 关联到导图
  "thumbnailPath": null
}
```

**Hive二进制数据：**
```
Header: 0x83 03 00 00 01 08 "document"
Fields:
  - id: UUID string
  - title: UTF-8 string
  - createdAt/updatedAt: Float64 timestamp
  - children: 嵌套 HiveObject 列表
  - content: JSON segments {"segments":[{"type":"text","text":"...","style":{...}}]}
  - position: {x, y} Float64 坐标
```

**特点：**
- ✅ 文档分片，独立管理
- ✅ 原生支持富文本样式
- ✅ ID前缀区分类型
- ✅ Hive高性能二进制序列化
- ⚠️ 需解析多个文件加载完整导图
- ⚠️ ZIP导出/导入复杂度高

---

## 3. 关键差异分析

### 3.1 子节点关系存储

**MarginNote：**
```
父节点记录:
ZMINDLINKS = "child1|child2|child3|child4"
```
- 简单管道分隔字符串
- 查询子节点：拆分字符串 → 批量查询
- 添加子节点：字符串追加
- 查找父节点：全表扫描 `WHERE ZMINDLINKS LIKE '%child_id%'`

**GuruMind：**
```
Hive嵌套对象:
children: [HiveObject(child1), HiveObject(child2), ...]
```
- 对象嵌套存储
- 子节点作为独立文档存在
- 通过 `linkedIds` 关联
- 双向索引：节点知道属于哪个导图

### 3.2 PDF摘录支持

**MarginNote：**
- ✅ 完整PDF位置信息（页码、坐标）
- ✅ 高亮区域截图存储
- ✅ OCR识别文本/媒体字段
- ✅ 高亮样式系统

**GuruMind：**
- ⚠️ 无PDF关联字段
- ⚠️ 无页码/坐标存储
- ⚠️ 仅Markdown图片引用
- ❌ 不支持PDF摘录流程

### 3.3 媒体管理

**MarginNote：**
```sql
ZMEDIA表:
ZMD5: 图片MD5（主键）
ZDATA: BLOB原始数据
ZTHUMBNAIL: BLOB缩略图
```
- 单表BLOB存储
- MD5去重
- 缩略图自动生成

**GuruMind：**
```
documents/xxx/assets/xxx.png
Markdown: ![](assets/xxx.png)
```
- 文件系统存储
- Markdown引用
- 无去重机制

---

## 4. 性能与扩展性对比

| 场景 | MarginNote | GuruMind |
|------|------------|----------|
| **单导图加载** | 1次SQL查询 | 多文件解析 |
| **节点CRUD** | 单表UPDATE | Hive增量写入 |
| **子节点遍历** | 拆分字符串+批量查询 | 嵌套对象遍历 |
| **反向查父** | 全表扫描 | linkedIds索引 |
| **跨设备同步** | USN版本号 | 整包交换 |
| **导出分享** | 单文件传输 | ZIP打包 |
| **大数据量** | SQLite索引优化 | Hive内存限制 |
| **PDF集成** | 完整支持 | 不支持 |

---

## 5. Starmind 最优设计方案

综合 MarginNote 和 GuruMind 的优点，推荐以下设计：

### 5.1 核心原则

1. **采用 MarginNote 的单文件SQLite模式** - 简化存储、同步、分享
2. **采用 GuruMind 的富文本JSON格式** - 标准化、易解析
3. **融合两者的ID前缀设计** - 类型识别 + UUID唯一性
4. **保留 MarginNote 的PDF摘录完整支持** - 核心功能差异点
5. **优化子节点查询** - 增加反向索引

### 5.2 推荐数据模型

#### Rust 实体定义

```rust
/// 思维导图笔记本（Topic）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct MindMapTopic {
    pub id: String,              // "0-{UUID}"
    pub title: String,
    pub created_at: i64,
    pub updated_at: i64,
    pub pdf_ids: Option<String>, // 管道分隔: "pdf1|pdf2|pdf3"
    pub root_node_ids: Option<String>, // 管道分隔根节点
    pub thumbnail_path: Option<String>,
    pub is_collapsed: bool,
    pub sync_version: i64,       // USN同步版本号
}

/// 导图节点（Note）
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct MindMapNode {
    pub id: String,              // "1-{UUID}" (导图节点) 或 "2-{UUID}" (笔记节点)
    pub topic_id: String,        // 所属导图 "0-{UUID}"
    pub parent_id: Option<String>, // 主父节点（优化反向查询）
    pub title: String,
    
    // 富文本内容（GuruMind JSON segments格式）
    pub content_json: Option<String>, // {"segments":[{"type":"text","text":"...","style":{...}}]}
    
    // 子节点（MarginNote管道分隔）
    pub child_ids: Option<String>, // "id1|id2|id3"
    
    // PDF摘录（MarginNote完整支持）
    pub pdf_id: Option<String>,
    pub start_page: Option<i32>,
    pub end_page: Option<i32>,
    pub start_pos: Option<String>, // JSON: {"x":..., "y":...}
    pub end_pos: Option<String>,
    pub highlight_text: Option<String>, // 摘录原文
    pub highlight_style: Option<String>,
    
    // 媒体
    pub media_ids: Option<String>, // 管道分隔
    
    // 布局
    pub position_x: Option<f64>,
    pub position_y: Option<f64>,
    pub z_index: i32,
    pub is_collapsed: bool,
    
    // 元数据
    pub created_at: i64,
    pub updated_at: i64,
    pub sync_version: i64,
}

/// PDF文档配置
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct PdfConfig {
    pub md5: String,             // PDF唯一标识
    pub title: Option<String>,
    pub page_count: i32,
    pub pages_json: Option<String>, // 页面尺寸信息
    pub current_page: i32,
    pub created_at: i64,
}

/// 媒体资源
#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct MediaAsset {
    pub id: String,              // MD5或UUID
    pub data: Vec<u8>,           // BLOB
    pub thumbnail: Option<Vec<u8>>,
    pub media_type: String,      // "image/png", "image/jpeg"
    pub created_at: i64,
}
```

#### SQLite 表定义

```sql
-- 导图笔记本表
CREATE TABLE mindmap_topics (
    id TEXT PRIMARY KEY,           -- "0-{UUID}"
    title TEXT NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    pdf_ids TEXT,                  -- 管道分隔
    root_node_ids TEXT,            -- 管道分隔
    thumbnail_path TEXT,
    is_collapsed INTEGER DEFAULT 0,
    sync_version INTEGER DEFAULT 0
);

CREATE INDEX idx_topics_created ON mindmap_topics(created_at);
CREATE INDEX idx_topics_sync ON mindmap_topics(sync_version);

-- 导图节点表
CREATE TABLE mindmap_nodes (
    id TEXT PRIMARY KEY,           -- "1-{UUID}" 或 "2-{UUID}"
    topic_id TEXT NOT NULL,        -- 外键关联导图
    parent_id TEXT,                -- 主父节点（优化反向查询）
    title TEXT NOT NULL,
    content_json TEXT,             -- JSON segments 富文本
    child_ids TEXT,                -- 管道分隔子节点
    pdf_id TEXT,
    start_page INTEGER,
    end_page INTEGER,
    start_pos TEXT,
    end_pos TEXT,
    highlight_text TEXT,
    highlight_style TEXT,
    media_ids TEXT,
    position_x REAL,
    position_y REAL,
    z_index INTEGER DEFAULT 0,
    is_collapsed INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    sync_version INTEGER DEFAULT 0,
    
    FOREIGN KEY (topic_id) REFERENCES mindmap_topics(id)
);

CREATE INDEX idx_nodes_topic ON mindmap_nodes(topic_id);
CREATE INDEX idx_nodes_parent ON mindmap_nodes(parent_id);  -- 关键：反向查询优化
CREATE INDEX idx_nodes_pdf ON mindmap_nodes(pdf_id);
CREATE INDEX idx_nodes_created ON mindmap_nodes(created_at);
CREATE INDEX idx_nodes_sync ON mindmap_nodes(sync_version);

-- PDF配置表
CREATE TABLE pdf_configs (
    md5 TEXT PRIMARY KEY,
    title TEXT,
    page_count INTEGER,
    pages_json TEXT,
    current_page INTEGER DEFAULT 0,
    created_at INTEGER NOT NULL
);

-- 媒体表
CREATE TABLE media_assets (
    id TEXT PRIMARY KEY,
    data BLOB NOT NULL,
    thumbnail BLOB,
    media_type TEXT DEFAULT 'image/png',
    created_at INTEGER NOT NULL
);
```

### 5.3 设计优势总结

| 设计点 | 来源 | 优势 |
|--------|------|------|
| **SQLite单文件** | MarginNote | 简化存储、同步、备份 |
| **管道分隔childIds** | MarginNote | 有序存储、简单直观 |
| **parent_id反向索引** | 优化设计 | 解决全表扫描问题 |
| **ID前缀类型区分** | GuruMind | 类型识别、快速过滤 |
| **JSON segments富文本** | GuruMind | 标准格式、样式完整 |
| **完整PDF摘录支持** | MarginNote | 页码、坐标、高亮、OCR |
| **USN同步版本** | MarginNote | 增量同步机制 |
| **Media BLOB存储** | MarginNote | 去重、缩略图 |

---

## 6. 实现建议

### 6.1 Rust 数据层（推荐 sqlx）

```rust
// 基础CRUD
pub async fn create_topic(title: String) -> Result<String, Error>;
pub async fn create_node(topic_id: String, title: String, parent_id: Option<String>) -> Result<String, Error>;
pub async fn add_child(parent_id: String, child_id: String) -> Result<(), Error>;
pub async fn get_node_children(node_id: String) -> Result<Vec<MindMapNode>, Error>;
pub async fn get_topic_nodes(topic_id: String) -> Result<Vec<MindMapNode>, Error>;

// PDF摘录
pub async fn create_node_from_excerpt(
    topic_id: String,
    pdf_id: String,
    page: i32,
    highlight_text: String,
    position: PdfPosition,
) -> Result<String, Error>;

// 同步
pub async fn get_dirty_nodes(sync_version: i64) -> Result<Vec<MindMapNode>, Error>;
pub async fn mark_synced(node_id: String, sync_version: i64) -> Result<(), Error>;
```

### 6.2 Flutter FFI 接口（flutter_rust_bridge）

```dart
// mindmap_repository.dart
class MindMapRepository {
  Future<String> createTopic(String title);
  Future<String> createNode(String topicId, String title, String? parentId);
  Future<void> addChild(String parentId, String childId);
  Future<List<MindMapNode>> getChildren(String nodeId);
  Future<String> createFromPdfExcerpt(PdfExcerpt excerpt);
}
```

### 6.3 性能优化要点

1. **parent_id 索引** - 查找父节点 O(1)
2. **child_ids 管道分隔** - 批量查询子节点，避免N+1
3. **topic_id 分区** - 按导图分区查询
4. **sync_version USN** - 增量同步，避免全量传输
5. **JSON content懒加载** - 大内容按需解析

---

## 7. 结论

**最优方案 = MarginNote架构 + GuruMind富文本 + 优化索引**

- **存储层：SQLite单文件**（MarginNote模式）
- **关系层：管道分隔childIds + parent_id索引**（融合优化）
- **内容层：JSON segments富文本**（GuruMind模式）
- **PDF层：完整摘录支持**（MarginNote模式）
- **同步层：USN版本号**（MarginNote模式）

这是兼顾性能、功能完整性和实现复杂度的最优设计。