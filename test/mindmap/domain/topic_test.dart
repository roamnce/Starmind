// test/mindmap/domain/topic_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';

void main() {
  group('Topic', () {
    test('fromMap creates valid Topic with pipe-separated fields', () {
      final map = {
        'id': '0-6f73097d-26ad-4537-9cb2-156e22f17160',
        'title': 'MarginNote导图',
        'pdf_ids': 'pdf1|pdf2|pdf3', // 管道分隔
        'root_note_ids': 'note1|note2', // 管道分隔
        'is_trashed': 0,
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
        'last_visit_at': '2026-05-30T11:00:00Z',
        'sync_version': 42,
      };

      final topic = Topic.fromMap(map);

      expect(topic.id, '0-6f73097d-26ad-4537-9cb2-156e22f17160');
      expect(topic.title, 'MarginNote导图');
      expect(topic.pdfIds, ['pdf1', 'pdf2', 'pdf3']);
      expect(topic.rootNoteIds, ['note1', 'note2']);
      expect(topic.isTrashed, false);
      expect(topic.syncVersion, 42);
    });

    test('toMap produces valid map with pipe-separated fields', () {
      final topic = Topic(
        id: '0-xxx',
        title: 'Test Topic',
        pdfIds: ['pdf1', 'pdf2'],
        rootNoteIds: ['note1'],
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-30T12:00:00Z'),
      );

      final map = topic.toMap();

      expect(map['pdf_ids'], 'pdf1|pdf2');
      expect(map['root_note_ids'], 'note1');
      expect(map['layout_direction'], 'both');
      expect(map['layout_style'], 'tree');
    });

    test('handles empty pipe-separated fields', () {
      final map = {
        'id': '0-xxx',
        'title': 'Empty Topic',
        'pdf_ids': null,
        'root_note_ids': '',
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
      };

      final topic = Topic.fromMap(map);

      expect(topic.pdfIds, []);
      expect(topic.rootNoteIds, []);
    });

    test('layout fields default to both/tree', () {
      final map = {
        'id': '0-xxx',
        'title': 'Test',
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
      };

      final topic = Topic.fromMap(map);

      expect(topic.layoutDirection, 'both');
      expect(topic.layoutStyle, 'tree');
    });

    test('layout fields can be set from map', () {
      final map = {
        'id': '0-xxx',
        'title': 'Test',
        'created_at': '2026-05-30T10:00:00Z',
        'updated_at': '2026-05-30T12:00:00Z',
        'layout_direction': 'left',
        'layout_style': 'framework',
      };

      final topic = Topic.fromMap(map);

      expect(topic.layoutDirection, 'left');
      expect(topic.layoutStyle, 'framework');
    });

    test('copyWith can update layout fields', () {
      final topic = Topic(
        id: '0-xxx',
        title: 'Test',
        createdAt: DateTime.parse('2026-05-30T10:00:00Z'),
        updatedAt: DateTime.parse('2026-05-30T12:00:00Z'),
      );

      final updated = topic.copyWith(
        layoutDirection: 'right',
        layoutStyle: 'framework',
      );

      expect(updated.layoutDirection, 'right');
      expect(updated.layoutStyle, 'framework');
      expect(updated.id, topic.id);
      expect(updated.title, topic.title);
    });
  });
}
