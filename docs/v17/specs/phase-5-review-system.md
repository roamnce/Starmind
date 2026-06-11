# Phase 5: 复习系统

> **目标：** 基于思维导图的间隔重复复习，完成知识管理闭环

## 背景

MarginNote 的学习闭环：
1. 阅读 PDF → 摘录 → 思维导图
2. 选择节点 → 生成复习卡片
3. FSRS 算法复习 → 强化记忆

复习系统是知识管理的最后一环，让思维导图不仅是组织工具，更是学习工具。

---

## 功能规格

### 5.1 复习入口

**位置：** 底部操作栏添加"复习"按钮

```
[拖动] [套索] ... [复习] [锁定]
                        ↓
              弹出节点选择面板
```

### 5.2 节点选择面板

进入复习模式前，弹出节点选择面板：

```
┌─────────────────────────────────────┐
│   选择复习节点                       │
├─────────────────────────────────────┤
│   ☑ 节点1 (标题)                    │
│   ☐ 节点2 (标题)                    │
│   ☑ 节点3 (标题)                    │
│   ...                               │
├─────────────────────────────────────┤
│   [全选] [取消]  [开始复习 (2张)]   │
└─────────────────────────────────────┘
```

**功能：**
- 显示当前思维导图所有节点列表
- 用户可勾选要复习的节点
- 显示已选数量

### 5.3 卡片结构

从节点生成复习卡片：

```
节点
├── 标题 → 问题面（始终可见）
├── Markdown 内容 → 答案面（遮罩）
├── 手写笔记 → 答案补充（随答案显示）
└── PDF 来源 → 可选跳转
```

### 5.4 复习流程

**遮罩模式：**

```
┌─────────────────────────────────────┐
│                                     │
│   [节点标题]                        │  ← 问题面，始终可见
│                                     │
│   ██████████████████████████████    │  ← 答案遮罩
│   ██████████████████████████████    │
│   ██████████████████████████████    │
│                                     │
│   [揭示答案]                        │  ← 未揭示时
└─────────────────────────────────────┘

              ↓ 点击揭示

┌─────────────────────────────────────┐
│                                     │
│   [节点标题]                        │
│                                     │
│   Markdown 内容...                  │  ← 答案显示
│   手写笔记...                       │  ← 手写随答案显示
│                                     │
│   [再来] [困难] [良好] [简单]       │  ← 难度按钮
└─────────────────────────────────────┘
```

**流程：**
1. 显示节点标题（问题）
2. 答案区域遮罩
3. 点击"揭示答案"
4. 显示 Markdown 内容 + 手写笔记
5. 用户选择难度
6. FSRS 算法更新复习计划
7. 进入下一张卡片

### 5.5 FSRS 算法

使用 Free Spaced Repetition Scheduler (FSRS) 算法：

```dart
class ReviewCard {
  final String id;
  final String noteId;
  final double stability;      // 记忆稳定性
  final double difficulty;     // 难度评估
  final double retrievability; // 可提取性
  final DateTime nextReview;   // 下次复习日期
  final int reviews;           // 复习次数
}

enum ReviewQuality {
  again,   // 再来：完全忘记
  hard,    // 困难：有些困难
  good,    // 良好：正常掌握
  easy,    // 简单：非常熟悉
}
```

**FSRS 核心公式：**
- 根据用户反馈更新 stability 和 difficulty
- 计算下次复习时间：`nextReview = now + stability * ln(desired_retention)`

### 5.6 复习统计

统计面板显示：

```
┌─────────────────────────────────────┐
│  今日复习：12 张                     │
│  待复习：45 张                       │
│  已掌握：120 张                      │
│  连续复习：7 天                      │
├─────────────────────────────────────┤
│  记忆曲线                           │
│    ∧                                │
│    │  ╲                             │
│    │   ╲___                         │
│    │       ╲___                     │
│    └──────────────→ 时间            │
├─────────────────────────────────────┤
│  难度分布                           │
│  [再来: 5%] [困难: 15%]             │
│  [良好: 60%] [简单: 20%]            │
└─────────────────────────────────────┘
```

### 5.7 复习完成

当所有卡片复习完毕：

```
┌─────────────────────────────────────┐
│                                     │
│         🎉 太棒了！                 │
│                                     │
│   今日复习 12 张卡片                │
│   掌握率 85%                        │
│                                     │
│   [返回思维导图]                    │
│                                     │
└─────────────────────────────────────┘
```

---

## 技术方案

### Plan 5-A：复习卡片模型

**目标：** 定义复习卡片数据结构

**新建文件：**
- `lib/src/review/domain/review_card.dart`

```dart
class ReviewCard {
  final String id;
  final String noteId;
  final String topicId;
  
  // FSRS 参数
  double stability;
  double difficulty;
  DateTime nextReview;
  int reviews;
  
  // 关联数据
  String question;  // 节点标题
  String? answer;   // Markdown 内容
  String? inkLayerId;  // 手写笔记
}
```

### Plan 5-B：FSRS 算法实现

**目标：** 实现间隔重复算法

**新建文件：**
- `lib/src/review/services/fsrs_service.dart`

```dart
class FSRSService {
  /// 计算下次复习时间
  ReviewCard review(ReviewCard card, ReviewQuality quality);
  
  /// 初始化新卡片
  ReviewCard createCard(String noteId, String topicId);
  
  /// 计算记忆可提取性
  double getRetrievability(ReviewCard card);
}
```

### Plan 5-C：复习服务

**目标：** 管理复习队列和统计

**新建文件：**
- `lib/src/review/services/review_service.dart`

```dart
class ReviewService {
  /// 获取待复习卡片
  Future<List<ReviewCard>> getDueCards(String topicId);
  
  /// 提交复习结果
  Future<void> submitReview(ReviewCard card, ReviewQuality quality);
  
  /// 获取统计数据
  Future<ReviewStats> getStats(String topicId);
  
  /// 创建复习卡片
  Future<ReviewCard> createCardFromNote(Note note);
}
```

### Plan 5-D：节点选择面板

**目标：** 复习前选择节点

**新建文件：**
- `lib/src/review/ui/node_selection_panel.dart`

```dart
class NodeSelectionPanel extends StatefulWidget {
  final String topicId;
  final void Function(List<Note> selectedNodes) onStartReview;
}
```

### Plan 5-E：复习页面

**目标：** 复习主界面

**新建文件：**
- `lib/src/review/ui/review_page.dart`

```dart
class ReviewPage extends StatefulWidget {
  final List<ReviewCard> cards;
}
```

### Plan 5-F：卡片视图

**目标：** 显示问题和答案（含遮罩）

**新建文件：**
- `lib/src/review/ui/review_card_view.dart`

```dart
class ReviewCardView extends StatelessWidget {
  final ReviewCard card;
  final bool revealed;
  final VoidCallback onReveal;
}
```

### Plan 5-G：难度操作栏

**目标：** 四个难度按钮

**新建文件：**
- `lib/src/review/ui/review_action_bar.dart`

```dart
class ReviewActionBar extends StatelessWidget {
  final void Function(ReviewQuality) onReview;
  final bool enabled;  // 揭示答案后启用
}
```

### Plan 5-H：统计面板

**目标：** 显示复习统计

**新建文件：**
- `lib/src/review/ui/review_stats_panel.dart`

```dart
class ReviewStatsPanel extends StatelessWidget {
  final ReviewStats stats;
}
```

### Plan 5-I：完成界面

**目标：** 复习完成祝贺页面

**新建文件：**
- `lib/src/review/ui/review_complete_page.dart`

```dart
class ReviewCompletePage extends StatelessWidget {
  final int cardsReviewed;
  final double masteryRate;
  final VoidCallback onReturnToMindMap;
}
```

### Plan 5-J：底部操作栏集成

**目标：** 添加复习按钮

**修改文件：**
- `lib/src/mindmap/ui/bottom_action_bar.dart`

**变更：**
1. 添加"复习"按钮
2. 点击后弹出 NodeSelectionPanel

### Plan 5-K：存储层

**目标：** 持久化复习卡片

**修改文件：**
- `rust/src/storage/db.rs`
- `rust/src/storage/mod.rs`
- `lib/src/rust/api/storage.dart`

**新增表：**
```sql
CREATE TABLE review_cards (
  id TEXT PRIMARY KEY,
  note_id TEXT NOT NULL,
  topic_id TEXT NOT NULL,
  stability REAL NOT NULL,
  difficulty REAL NOT NULL,
  next_review INTEGER NOT NULL,
  reviews INTEGER NOT NULL DEFAULT 0
);
```

---

## 交付物清单

| 文件路径 | 说明 |
|----------|------|
| `lib/src/review/domain/review_card.dart` | 复习卡片模型 |
| `lib/src/review/services/fsrs_service.dart` | FSRS 算法 |
| `lib/src/review/services/review_service.dart` | 复习服务 |
| `lib/src/review/ui/node_selection_panel.dart` | 节点选择面板 |
| `lib/src/review/ui/review_page.dart` | 复习页面 |
| `lib/src/review/ui/review_card_view.dart` | 卡片视图（含遮罩） |
| `lib/src/review/ui/review_action_bar.dart` | 难度操作栏 |
| `lib/src/review/ui/review_stats_panel.dart` | 统计面板 |
| `lib/src/review/ui/review_complete_page.dart` | 完成界面 |
| `lib/src/mindmap/ui/bottom_action_bar.dart` | 添加复习按钮 |
| `rust/src/storage/review.rs` | Rust 存储层 |

---

## 验收标准

- [ ] 底部操作栏显示"复习"按钮
- [ ] 点击后弹出节点选择面板
- [ ] 可勾选要复习的节点
- [ ] 开始复习后显示卡片
- [ ] 问题面可见，答案面遮罩
- [ ] 点击"揭示答案"显示内容 + 手写
- [ ] 四个难度按钮：再来/困难/良好/简单
- [ ] 选择难度后更新复习计划（FSRS）
- [ ] 统计面板显示：基础统计 + 记忆曲线 + 难度分布 + 连续天数
- [ ] 复习完成显示祝贺界面
- [ ] 复习数据持久化存储

---

## 依赖

- Phase 1（手写画布层）
- Phase 2（节点手写笔记）
- v15 Phase 4-6（关联线、概要、标签）

---

## 设计决策（已锁定）

| 决策项 | 选择 | 说明 |
|--------|------|------|
| 复习入口 | 底部操作栏按钮 | 点击弹出节点选择面板 |
| 卡片范围 | 选择节点 | 用户可勾选特定节点 |
| 节点选择 | 弹出选择面板 | 显示节点列表，支持勾选 |
| 遮罩样式 | 纯色遮罩 | 灰色矩形，点击揭开 |
| 难度按钮 | 4 个 | 再来、困难、良好、简单 |
| 复习算法 | FSRS | 比 SM-2 更智能 |
| 手写内容 | 随答案显示 | 揭示答案时一并显示 |
| 统计面板 | 4 项 | 基础统计、记忆曲线、难度分布、连续天数 |
| 完成处理 | 显示祝贺 | 恭喜界面 + 返回按钮 |

---

## 待澄清问题

无