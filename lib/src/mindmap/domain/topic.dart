// lib/src/mindmap/domain/topic.dart

/// ˼ά��ͼ�ʼǱ�����Ӧ MarginNote ZTOPIC����
///
/// ������ݣ�
/// - MarginNote: ���ļ��ʼǱ�ģʽ
/// - ֧�ֶ� PDF ������pdfIds��
/// - IDǰ׺: "0-{UUID}" (GuruMind ���)
class Topic {
  /// �ʼǱ� ID����ʽ "0-{UUID}"��
  final String id;

  /// �ʼǱ�����
  final String title;

  /// ���ߣ���ѡ��
  final String? author;

  /// ������ PDF �ĵ� MD5 �б��������ָ��洢��
  final List<String> pdfIds;

  /// ���ڵ� ID �б��������ָ��洢��
  final List<String> rootNoteIds;

  /// ���ַ���: 'both', 'left', 'right' (Ĭ�� 'both')
  final String layoutDirection;

  /// ������ʽ: 'tree', 'framework' (Ĭ�� 'tree')
  final String layoutStyle;

  /// ����ͼ·��
  final String? thumbnailPath;

  /// ����ʱ��
  final DateTime createdAt;

  /// ����ʱ��
  final DateTime updatedAt;

  /// ������ʱ��
  final DateTime? lastVisitAt;

  /// �Ƿ���ɾ��
  final bool isTrashed;

  /// ͬ���汾�ţ�USN ���ƣ�
  final int syncVersion;

  const Topic({
    required this.id,
    required this.title,
    this.author,
    this.pdfIds = const [],
    this.rootNoteIds = const [],
    this.layoutDirection = 'both',
    this.layoutStyle = 'tree',
    this.thumbnailPath,
    required this.createdAt,
    required this.updatedAt,
    this.lastVisitAt,
    this.isTrashed = false,
    this.syncVersion = 0,
  });

  /// �����ݿ� Map ������֧�������ָ��ֶΣ�
  factory Topic.fromMap(Map<String, dynamic> map) {
    return Topic(
      id: map['id'] as String,
      title: map['title'] as String,
      author: map['author'] as String?,
      pdfIds: _parsePipedList(map['pdf_ids'] as String?),
      rootNoteIds: _parsePipedList(map['root_note_ids'] as String?),
      layoutDirection: map['layout_direction'] as String? ?? 'both',
      layoutStyle: map['layout_style'] as String? ?? 'tree',
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

  /// ת��Ϊ���ݿ� Map�������ָ��ֶΣ�
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'author': author,
        'pdf_ids': pdfIds.isEmpty ? null : pdfIds.join('|'),
        'root_note_ids': rootNoteIds.isEmpty ? null : rootNoteIds.join('|'),
        'layout_direction': layoutDirection,
        'layout_style': layoutStyle,
        'thumbnail_path': thumbnailPath,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
        'last_visit_at': lastVisitAt?.toIso8601String(),
        'is_trashed': isTrashed ? 1 : 0,
        'sync_version': syncVersion,
      };

  /// �����ܵ��ָ��ַ���Ϊ�б�
  static List<String> _parsePipedList(String? value) {
    if (value == null || value.isEmpty) return [];
    return value.split('|').where((s) => s.isNotEmpty).toList();
  }

  /// ���Ʋ������ֶ�
  Topic copyWith({
    String? title,
    List<String>? pdfIds,
    List<String>? rootNoteIds,
    String? layoutDirection,
    String? layoutStyle,
    String? thumbnailPath,
    DateTime? updatedAt,
    DateTime? lastVisitAt,
    int? syncVersion,
    bool? isTrashed,
  }) {
    return Topic(
      id: id,
      title: title ?? this.title,
      author: author,
      pdfIds: pdfIds ?? this.pdfIds,
      rootNoteIds: rootNoteIds ?? this.rootNoteIds,
      layoutDirection: layoutDirection ?? this.layoutDirection,
      layoutStyle: layoutStyle ?? this.layoutStyle,
      thumbnailPath: thumbnailPath ?? this.thumbnailPath,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastVisitAt: lastVisitAt ?? this.lastVisitAt,
      isTrashed: isTrashed ?? this.isTrashed,
      syncVersion: syncVersion ?? this.syncVersion,
    );
  }
}
