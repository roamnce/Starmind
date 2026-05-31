// test/mindmap/domain/note_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/domain/note_content.dart';

void main() {
  group('Note', () {
    test('fromMap creates valid Note with all fields', () {
      final map = {
        'id': '1-abc123',
        'topic_id': '0-xxx',
        'parent_id': '1-parent',
        'title': 'Test Note',
        'child_ids': 'child1|child2|child3',
        'content_json': '{"segments":[{"type":"text","text":"Hello","style":{"bold":false}}]}',
        'pdf_id': 'pdf-md5',
        'start_page': 5,
        'end_page': 6,
        'start_pos': '{"x":100.0,"y":200.0}',
        'end_pos': '{"x":300.0,"y":400.0}',
        'highlight_text': 'Original PDF text',
        'highlight_style': 'mbooks-annotation12',
        'media_ids': 'media1|media2',
        'position_x': 50.0,
        'position_y': 100.0,
        'z_index': 10,
        'is_collapsed': 1,
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
        'sync_version': 5,
      };

      final note = Note.fromMap(map);

      expect(note.id, '1-abc123');
      expect(note.topicId, '0-xxx');
      expect(note.parentId, '1-parent');
      expect(note.childIds, ['child1', 'child2', 'child3']);
      expect(note.pdfId, 'pdf-md5');
      expect(note.startPage, 5);
      expect(note.endPage, 6);
      expect(note.highlightText, 'Original PDF text');
      expect(note.positionX, 50.0);
      expect(note.positionY, 100.0);
      expect(note.isCollapsed, true);
    });

    test('toMap produces valid map with pipe-separated child_ids', () {
      final note = Note(
        id: '1-xxx',
        topicId: '0-xxx',
        title: 'Test',
        childIds: ['a', 'b', 'c'],
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-30T12:00:00Z'),
      );

      final map = note.toMap();

      expect(map['child_ids'], 'a|b|c');
    });

    test('parses JSON content correctly', () {
      final map = {
        'id': '1-xxx',
        'topic_id': '0-xxx',
        'title': 'Test',
        'content_json': '{"segments":[{"type":"text","text":"Hello","style":{"bold":true}}]}',
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
      };

      final note = Note.fromMap(map);

      expect(note.content, isNotNull);
      expect(note.content!.segments.length, 1);
      expect(note.content!.segments[0].text, 'Hello');
      expect(note.content!.segments[0].style?.bold, true);
    });
  });
}
