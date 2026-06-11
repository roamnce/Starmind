import 'dart:convert';

import '../domain/note.dart';
import '../domain/note_content.dart';
import '../domain/topic.dart';

class GuruMindDataConverter {
  Topic topicFromDocument(Map<String, dynamic> document) {
    return Topic.fromMap(_normalizeTopicMap(document));
  }

  Note noteFromDocument(
    Map<String, dynamic> document, {
    required String topicId,
  }) {
    final map = _normalizeNoteMap(document, topicId: topicId);
    return Note.fromMap(map);
  }

  Map<String, dynamic> topicToDocument(Topic topic) {
    final map = Map<String, dynamic>.from(topic.toMap());
    map['rootNodes'] = topic.rootNoteIds.map(_toGuruMindNodeId).toList();
    map['root_note_ids'] = map['rootNodes'];
    return map;
  }

  Map<String, dynamic> noteToDocument(Note note) {
    final map = Map<String, dynamic>.from(note.toMap());
    map['id'] = _toGuruMindNodeId(note.id);
    map['childIds'] = note.childIds.map(_toGuruMindNodeId).toList();
    map['child_ids'] = map['childIds'];
    return map;
  }

  Map<String, dynamic> _normalizeTopicMap(Map<String, dynamic> document) {
    final now = DateTime.now().toIso8601String();
    return {
      'id':
          document['id'] ??
          document['uuid'] ??
          '0-${DateTime.now().microsecondsSinceEpoch}',
      'title': document['title'] ?? document['name'] ?? 'Imported Mindmap',
      'author': document['author'],
      'pdf_ids': _join(document['pdf_ids'] ?? document['pdfIds']),
      'root_note_ids': _joinIds(
        document['root_note_ids'] ??
            document['rootNoteIds'] ??
            document['root_ids'] ??
            document['rootNodes'],
      ),
      'thumbnail_path': document['thumbnail_path'] ?? document['thumbnailPath'],
      'created_at': document['created_at'] ?? document['createdAt'] ?? now,
      'updated_at': document['updated_at'] ?? document['updatedAt'] ?? now,
      'last_visit_at': document['last_visit_at'] ?? document['lastVisitAt'],
      'is_trashed': document['is_trashed'] ?? 0,
      'sync_version': document['sync_version'] ?? 0,
    };
  }

  Map<String, dynamic> _normalizeNoteMap(
    Map<String, dynamic> document, {
    required String topicId,
  }) {
    final now = DateTime.now().toIso8601String();
    final title =
        document['title'] ??
        document['name'] ??
        document['text'] ??
        'Imported Note';
    final content =
        document['content_json'] ??
        (document['content'] is Map
            ? NoteContent.fromJson(
                Map<String, dynamic>.from(document['content'] as Map),
              ).toJson()
            : null);
    return {
      'id': _toStarmindNoteId(
        document['id'] ??
            document['uuid'] ??
            '${DateTime.now().microsecondsSinceEpoch}',
      ),
      'topic_id': document['topic_id'] ?? document['topicId'] ?? topicId,
      'parent_id': _normalizeOptionalNoteId(
        document['parent_id'] ?? document['parentId'],
      ),
      'title': title,
      'content_json': content is String
          ? content
          : content == null
          ? null
          : _json(content),
      'child_ids': _joinIds(
        document['child_ids'] ?? document['childIds'] ?? document['children'],
      ),
      'pdf_id': document['pdf_id'] ?? document['pdfId'],
      'start_page': document['start_page'] ?? document['startPage'],
      'end_page': document['end_page'] ?? document['endPage'],
      'start_pos': document['start_pos'] ?? document['startPos'],
      'end_pos': document['end_pos'] ?? document['endPos'],
      'highlight_text': document['highlight_text'] ?? document['highlightText'],
      'highlight_style':
          document['highlight_style'] ?? document['highlightStyle'],
      'media_ids': _join(document['media_ids'] ?? document['mediaIds']),
      'position_x': document['position_x'] ?? document['positionX'],
      'position_y': document['position_y'] ?? document['positionY'],
      'z_index': document['z_index'] ?? document['zIndex'] ?? 0,
      'is_collapsed': document['is_collapsed'] ?? 0,
      'created_at': document['created_at'] ?? document['createdAt'] ?? now,
      'updated_at': document['updated_at'] ?? document['updatedAt'] ?? now,
      'sync_version': document['sync_version'] ?? 0,
      'layout_style':
          document['layout_style'] ?? document['layoutStyle'] ?? 'normal',
    };
  }

  String _toStarmindNoteId(Object? value) {
    final id = value?.toString() ?? '';
    if (id.startsWith('0-') || id.startsWith('1-') || id.startsWith('2-')) {
      return id;
    }
    return '1-$id';
  }

  String? _normalizeOptionalNoteId(Object? value) {
    if (value == null) return null;
    final id = value.toString();
    if (id.isEmpty) return null;
    return _toStarmindNoteId(id);
  }

  String _toGuruMindNodeId(String id) =>
      id.startsWith('1-') ? id.substring(2) : id;

  String? _joinIds(Object? value) {
    if (value == null) return null;
    if (value is String) {
      return value
          .split('|')
          .where((id) => id.isNotEmpty)
          .map(_toStarmindNoteId)
          .join('|');
    }
    if (value is Iterable) {
      return value.whereType<Object>().map(_toStarmindNoteId).join('|');
    }
    return _toStarmindNoteId(value);
  }

  String? _join(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Iterable) {
      return value.whereType<Object>().map((item) => item.toString()).join('|');
    }
    return value.toString();
  }

  String _json(Object value) => jsonEncode(value);

  // ==================== Relation 导入 ====================

  /// 从文档解析关联线列表
  List<Map<String, dynamic>> relationsFromDocument(
    Map<String, dynamic> document, {
    required String topicId,
  }) {
    final raw = document['relations'] as List<dynamic>?;
    if (raw == null || raw.isEmpty) return [];

    return raw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return {
        'id': map['id']?.toString() ?? 'rel-${DateTime.now().microsecondsSinceEpoch}',
        'topic_id': topicId,
        'source_note_id': _toStarmindNoteId(map['source_note_id'] ?? map['sourceNoteId']),
        'target_note_id': _toStarmindNoteId(map['target_note_id'] ?? map['targetNoteId']),
        'text': map['text']?.toString() ?? '关联',
        'control_points_json': map['control_points_json'] ?? map['controlPointsJson'],
        'style': map['style']?.toString() ?? 'solid',
        'created_at': map['created_at'] ?? map['createdAt'] ?? DateTime.now().toIso8601String(),
        'updated_at': map['updated_at'] ?? map['updatedAt'] ?? DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  // ==================== Summary 导入 ====================

  /// 从文档解析概要列表
  List<Map<String, dynamic>> summariesFromDocument(
    Map<String, dynamic> document, {
    required String topicId,
  }) {
    final raw = document['summaries'] as List<dynamic>?;
    if (raw == null || raw.isEmpty) return [];

    return raw.map((item) {
      final map = Map<String, dynamic>.from(item as Map);
      return {
        'id': map['id']?.toString() ?? 'sum-${DateTime.now().microsecondsSinceEpoch}',
        'topic_id': topicId,
        'parent_id': _toStarmindNoteId(map['parent_id'] ?? map['parentId']),
        'start_index': map['start_index'] ?? map['startIndex'] ?? 0,
        'end_index': map['end_index'] ?? map['endIndex'] ?? 0,
        'text': map['text']?.toString() ?? '概要',
        'created_at': map['created_at'] ?? map['createdAt'] ?? DateTime.now().toIso8601String(),
        'updated_at': map['updated_at'] ?? map['updatedAt'] ?? DateTime.now().toIso8601String(),
      };
    }).toList();
  }

  // ==================== Node Tags 导入 ====================

  /// 从文档解析节点标签绑定
  Map<String, List<String>> noteTagNamesFromDocument(
    Map<String, dynamic> document,
  ) {
    final raw = document['nodeTags'] as Map<String, dynamic>?;
    if (raw == null || raw.isEmpty) return {};

    final result = <String, List<String>>{};
    for (final entry in raw.entries) {
      final noteId = _toStarmindNoteId(entry.key);
      final tagIds = (entry.value as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (tagIds.isNotEmpty) {
        result[noteId] = tagIds;
      }
    }
    return result;
  }
}
