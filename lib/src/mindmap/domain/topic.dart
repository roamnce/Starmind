// lib/src/mindmap/domain/topic.dart

/// 思维导图笔记本（对应 MarginNote ZTOPIC）。
///
/// 设计依据：
/// - MarginNote: 单文件笔记本模式
/// - 支持多 PDF 关联（pdfIds）
/// - ID前缀: "0-{UUID}" (GuruMind 风格)
class Topic {
  /// 笔记本 ID（格式: "0-{UUID}"）
  final String id;

  /// 笔记本标题
  final String title;

  /// 作者（可选）
  final String? author;

  /// 关联的 PDF 文档 MD5 列表（管道分隔存储）
  final List<String> pdfIds;

  /// 根节点 ID 列表（管道分隔存储）
  final List<String> rootNoteIds;

  /// 缩略图路径
  final String? thumbnailPath;

  /// 创建时间
  final DateTime createdAt;

  /// 更新时间
  final DateTime updatedAt;

  /// 最后访问时间
  final DateTime? lastVisitAt;

  /// 是否已删除
  final bool isTrashed;

  /// 同步版本号（USN 机制）
  final int syncVersion;

  const Topic({
    required this.id,
    required this.title,
    this.author,
    this.pdfIds = const [],
    this.rootNoteIds = const [],
    this.thumbnailPath,
    required this.createdAt,
    required this.updatedAt,
    this.lastVisitAt,
    this.isTrashed = false,
    this.syncVersion = 0,
  });

  /// 从数据库 Map 创建（支持管道分隔字段）
  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      pdfIds: _parsePipedList(map['pdf_ids'] as String?),
      rootNoteIds: _parsePipedList(map['root_note_ids'] as String?),
      thumbnailPath: map['thumbnail_path'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      lastVisitAt: map['last_visit_at'] != null
          ? DateTime.parse(map['last_visit_at'] as String)
          : null,
      isTrashed: (map['is_trashed'] as int?) == 1,
      syncVersion: (map['sync_version'] as int?) ?? 0,
    );
  }

  /// 转为数据库 Map（管道分隔字段）
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'pdf_ids': pdfIds.isEmpty ? null : pdfIds.join('|'),
        'root_note_ids': rootNoteIds.isEmpty ? null : rootNoteIds.join('|'),
        'thumbnail_path': thumbnailPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_visit_at': lastVisitAt?.toIso8601String(),
        'is_trashed': isTrashed ? 1 : 0,
        'sync_version': syncVersion,
      };

  /// 解析管道分隔字符串
  static List<String> _parsePipedList(String? value) {
    if (value == null || value.isEmpty) return [];
    return value.split('|').where((s) => s.isNotEmpty).toList();
  }

  /// 复制并更新字段
  Topic copyWith({
    String? title,
    List<String>? pdfIds,
    List<String>? rootNoteIds,
    DateTime? updatedAt,
    DateTime? lastVisitAt,
    int? syncVersion,
  }) {
    return Topic(
      id: id,
      title: title ?? this.title,
      author: author,
      pdfIds: pdfIds ?? this.pdfIds,
      rootNoteIds: rootNoteIds ?? this.rootNoteIds,
      thumbnailPath: thumbnailPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      isTrashed: isTrashed,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }
}