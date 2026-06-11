// test/mindmap/domain/mindmap_relation_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/mindmap_relation.dart';

void main() {
  group('MindMapRelation', () {
    test('uses default text and style when optional values are absent', () {
      final now = DateTime.utc(2026, 6, 9);
      final relation = MindMapRelation(
        id: 'rel-1',
        topicId: 'topic-1',
        sourceNoteId: '1-a',
        targetNoteId: '1-b',
        createdAt: now,
        updatedAt: now,
      );

      expect(relation.text, '关联');
      expect(relation.style, 'solid');
      expect(relation.controlPoints, isEmpty);
    });

    test('round trips through map with control points', () {
      final now = DateTime.utc(2026, 6, 9);
      final relation = MindMapRelation(
        id: 'rel-1',
        topicId: 'topic-1',
        sourceNoteId: '1-a',
        targetNoteId: '1-b',
        text: 'causes',
        controlPoints: const [
          RelationControlPoint(x: 12, y: 20),
          RelationControlPoint(x: 40, y: 28),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final restored = MindMapRelation.fromMap(relation.toMap());

      expect(restored.id, relation.id);
      expect(restored.topicId, relation.topicId);
      expect(restored.sourceNoteId, relation.sourceNoteId);
      expect(restored.targetNoteId, relation.targetNoteId);
      expect(restored.text, 'causes');
      expect(restored.controlPoints.map((p) => '${p.x},${p.y}'),
          ['12.0,20.0', '40.0,28.0']);
    });

    test('copyWith updates specified fields', () {
      final now = DateTime.utc(2026, 6, 9);
      final relation = MindMapRelation(
        id: 'rel-1',
        topicId: 'topic-1',
        sourceNoteId: '1-a',
        targetNoteId: '1-b',
        createdAt: now,
        updatedAt: now,
      );

      final updated = relation.copyWith(
        text: 'depends on',
        updatedAt: DateTime.utc(2026, 6, 10),
      );

      expect(updated.text, 'depends on');
      expect(updated.style, 'solid'); // unchanged
      expect(updated.sourceNoteId, '1-a'); // unchanged
    });
  });
}
