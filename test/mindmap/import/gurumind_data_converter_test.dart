import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/import/gurumind_data_converter.dart';

void main() {
  test('normalizes GuruMind note relationship ids to Starmind note ids', () {
    final converter = GuruMindDataConverter();

    final note = converter.noteFromDocument({
      'id': 'child-uuid',
      'topic_id': '0-topic',
      'parentId': 'parent-uuid',
      'title': 'Child',
      'childIds': ['grandchild-uuid'],
      'createdAt': '2026-06-07T00:00:00.000Z',
      'updatedAt': '2026-06-07T00:00:00.000Z',
    }, topicId: '0-topic');

    expect(note.id, equals('1-child-uuid'));
    expect(note.parentId, equals('1-parent-uuid'));
    expect(note.childIds, equals(['1-grandchild-uuid']));
  });

  test('normalizes GuruMind root node ids to Starmind note ids', () {
    final converter = GuruMindDataConverter();

    final topic = converter.topicFromDocument({
      'id': '0-topic',
      'title': 'Topic',
      'rootNodes': ['root-uuid'],
      'createdAt': '2026-06-07T00:00:00.000Z',
      'updatedAt': '2026-06-07T00:00:00.000Z',
    });

    expect(topic.rootNoteIds, equals(['1-root-uuid']));
  });

  group('relationsFromDocument', () {
    test('parses relations with snake_case keys', () {
      final converter = GuruMindDataConverter();
      final result = converter.relationsFromDocument({
        'relations': [
          {
            'id': 'rel-1',
            'source_note_id': '1-a',
            'target_note_id': '1-b',
            'text': 'linked',
            'style': 'solid',
            'created_at': '2026-06-10T00:00:00.000Z',
            'updated_at': '2026-06-10T00:00:00.000Z',
          },
        ],
      }, topicId: '0-t');

      expect(result, hasLength(1));
      expect(result[0]['source_note_id'], '1-a');
      expect(result[0]['target_note_id'], '1-b');
      expect(result[0]['text'], 'linked');
      expect(result[0]['topic_id'], '0-t');
    });

    test('parses relations with camelCase keys', () {
      final converter = GuruMindDataConverter();
      final result = converter.relationsFromDocument({
        'relations': [
          {
            'id': 'rel-1',
            'sourceNoteId': 'node-a',
            'targetNoteId': 'node-b',
            'createdAt': '2026-06-10T00:00:00.000Z',
            'updatedAt': '2026-06-10T00:00:00.000Z',
          },
        ],
      }, topicId: '0-t');

      expect(result, hasLength(1));
      expect(result[0]['source_note_id'], '1-node-a');
      expect(result[0]['target_note_id'], '1-node-b');
      expect(result[0]['text'], '关联');
    });

    test('returns empty list when no relations', () {
      final converter = GuruMindDataConverter();
      expect(converter.relationsFromDocument({}, topicId: '0-t'), isEmpty);
      expect(converter.relationsFromDocument({'relations': []}, topicId: '0-t'), isEmpty);
    });
  });

  group('summariesFromDocument', () {
    test('parses summaries with index defaults', () {
      final converter = GuruMindDataConverter();
      final result = converter.summariesFromDocument({
        'summaries': [
          {
            'id': 'sum-1',
            'parent_id': '1-p',
            'start_index': 0,
            'end_index': 2,
            'text': '要点',
            'created_at': '2026-06-10T00:00:00.000Z',
            'updated_at': '2026-06-10T00:00:00.000Z',
          },
        ],
      }, topicId: '0-t');

      expect(result, hasLength(1));
      expect(result[0]['parent_id'], '1-p');
      expect(result[0]['start_index'], 0);
      expect(result[0]['end_index'], 2);
      expect(result[0]['text'], '要点');
    });

    test('returns empty list when no summaries', () {
      final converter = GuruMindDataConverter();
      expect(converter.summariesFromDocument({}, topicId: '0-t'), isEmpty);
    });
  });

  group('noteTagNamesFromDocument', () {
    test('parses note tag bindings', () {
      final converter = GuruMindDataConverter();
      final result = converter.noteTagNamesFromDocument({
        'nodeTags': {
          '1-node-a': ['important', 'review'],
          'node-b': ['draft'],
        },
      });

      expect(result, hasLength(2));
      expect(result['1-node-a'], ['important', 'review']);
      expect(result['1-node-b'], ['draft']);
    });

    test('returns empty map when no tags', () {
      final converter = GuruMindDataConverter();
      expect(converter.noteTagNamesFromDocument({}), isEmpty);
    });
  });
}
