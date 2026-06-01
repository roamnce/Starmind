// test/mindmap/ui/framework_child_position_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/framework_child_position.dart';

void main() {
  group('FrameworkChildPosition', () {
    test('creates position with row and col', () {
      const pos = FrameworkChildPosition(row: 0, col: 1);
      expect(pos.row, equals(0));
      expect(pos.col, equals(1));
    });

    test('serializes to and from JSON', () {
      const pos = FrameworkChildPosition(row: 2, col: 0);
      final json = pos.toJson();
      expect(json['row'], equals(2));
      expect(json['col'], equals(0));

      final restored = FrameworkChildPosition.fromJson(json);
      expect(restored.row, equals(2));
      expect(restored.col, equals(0));
    });

    test('supports equality comparison', () {
      const pos1 = FrameworkChildPosition(row: 1, col: 2);
      const pos2 = FrameworkChildPosition(row: 1, col: 2);
      const pos3 = FrameworkChildPosition(row: 0, col: 2);

      expect(pos1, equals(pos2));
      expect(pos1, isNot(equals(pos3)));
    });
  });
}