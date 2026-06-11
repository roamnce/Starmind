// test/mindmap/domain/mindmap_summary_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/mindmap_summary.dart';

void main() {
  group('MindMapSummary', () {
    test('normalizes reversed ranges and keeps default text', () {
      final now = DateTime.utc(2026, 6, 9);
      final summary = MindMapSummary(
        id: 'sum-1',
        topicId: 'topic-1',
        parentId: '1-parent',
        startIndex: 4,
        endIndex: 2,
        createdAt: now,
        updatedAt: now,
      );

      expect(summary.startIndex, 2);
      expect(summary.endIndex, 4);
      expect(summary.text, '概要');
    });

    test('round trips through map', () {
      final now = DateTime.utc(2026, 6, 9);
      final summary = MindMapSummary(
        id: 'sum-1',
        topicId: 'topic-1',
        parentId: '1-parent',
        startIndex: 0,
        endIndex: 2,
        text: 'Summary text',
        createdAt: now,
        updatedAt: now,
      );

      final restored = MindMapSummary.fromMap(summary.toMap());

      expect(restored.id, summary.id);
      expect(restored.topicId, summary.topicId);
      expect(restored.parentId, summary.parentId);
      expect(restored.startIndex, 0);
      expect(restored.endIndex, 2);
      expect(restored.text, 'Summary text');
    });

    test('copyWith updates specified fields', () {
      final now = DateTime.utc(2026, 6, 9);
      final summary = MindMapSummary(
        id: 'sum-1',
        topicId: 'topic-1',
        parentId: '1-parent',
        startIndex: 0,
        endIndex: 2,
        createdAt: now,
        updatedAt: now,
      );

      final updated = summary.copyWith(
        text: 'Updated summary',
        updatedAt: DateTime.utc(2026, 6, 10),
      );

      expect(updated.text, 'Updated summary');
      expect(updated.startIndex, 0); // unchanged
      expect(updated.endIndex, 2); // unchanged
    });
  });
}
