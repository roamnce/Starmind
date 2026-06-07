import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/export/hive_encoder.dart';
import 'package:starmind/src/mindmap/import/hive_decoder.dart';

void main() {
  test('HiveEncoder and HiveDecoder support string arrays and float64 values', () {
    final bytes = HiveEncoder().encodeDocument({
      '1': 'title',
      'tags': ['a', 'b'],
      'score': 2.5,
    });

    final document = HiveDecoder().decodeBytes(bytes);

    expect(document.getString(1), 'title');
    expect(document.getArray('tags'), ['a', 'b']);
    expect(document.getFloat64('score'), 2.5);
  });
}
