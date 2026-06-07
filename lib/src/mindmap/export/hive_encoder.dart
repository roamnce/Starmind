import 'dart:convert';
import 'dart:typed_data';

import '../domain/note.dart';
import '../domain/topic.dart';

class HiveEncoder {
  static const int magicA = 0xFA;
  static const int magicB = 0x42;

  Uint8List encodeDocument(Map<String, dynamic> document) {
    final jsonBytes = utf8.encode(jsonEncode(document));
    return Uint8List.fromList([magicA, magicB, 0x00, 0x00, ...jsonBytes]);
  }

  Uint8List encodeTopic(Topic topic) => encodeDocument(topic.toMap());

  Uint8List encodeNote(Note note) => encodeDocument(note.toMap());
}
