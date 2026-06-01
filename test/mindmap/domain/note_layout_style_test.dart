// test/mindmap/domain/note_layout_style_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/note.dart';

void main() {
  group('Note layoutStyle', () {
    test('creates note with default layoutStyle (normal)', () {
      final note = Note(
        id: '1-test',
        topicId: '0-topic',
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(note.layoutStyle, equals('normal'));
    });

    test('creates note with framework layoutStyle', () {
      final note = Note(
        id: '1-test',
        topicId: '0-topic',
        title: 'Test',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(note.layoutStyle, equals('framework'));
    });

    test('serializes layoutStyle to and from Map', () {
      final note = Note(
        id: '1-test',
        topicId: '0-topic',
        title: 'Test',
        layoutStyle: 'framework',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = note.toMap();
      expect(map['layout_style'], equals('framework'));

      final restored = Note.fromMap(map);
      expect(restored.layoutStyle, equals('framework'));
    });

    test('copyWith updates layoutStyle', () {
      final note = Note(
        id: '1-test',
        topicId: '0-topic',
        title: 'Test',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updated = note.copyWith(layoutStyle: 'framework');
      expect(updated.layoutStyle, equals('framework'));
    });
  });
}
