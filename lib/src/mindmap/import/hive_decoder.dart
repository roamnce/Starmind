import 'dart:convert';
import 'dart:typed_data';

import '../export/hive_encoder.dart';

class HiveDocument {
  HiveDocument(this.values);

  final Map<String, dynamic> values;

  String? getString(Object key) => values[key.toString()]?.toString() ?? values[key]?.toString();
  double? getFloat64(Object key) => (values[key.toString()] as num?)?.toDouble() ?? (values[key] as num?)?.toDouble();
  List<dynamic>? getArray(Object key) => values[key.toString()] as List<dynamic>? ?? values[key] as List<dynamic>?;
}

class HiveDecoder {
  HiveDocument decodeBytes(Uint8List bytes) {
    if (_hasJsonMagic(bytes)) {
      final payloadOffset = bytes.length >= 4 && bytes[2] == 0x00 && bytes[3] == 0x00 ? 4 : 2;
      try {
        final decoded = jsonDecode(utf8.decode(bytes.sublist(payloadOffset)));
        if (decoded is Map) return HiveDocument(Map<String, dynamic>.from(decoded));
      } on FormatException {
        // Fall through to GuruMind field scanning.
      }
    }
    return HiveDocument(_decodeGuruMindFields(bytes));
  }

  bool _hasJsonMagic(Uint8List bytes) => bytes.length >= 2 && bytes[0] == HiveEncoder.magicA && bytes[1] == HiveEncoder.magicB;

  Map<String, dynamic> _decodeGuruMindFields(Uint8List bytes) {
    final strings = _scanStringFields(bytes);
    final firstId = strings.where((field) => field.index == 0).map((field) => field.value).firstOrNull;
    final firstTitle = strings.where((field) => field.index == 1).map((field) => field.value).firstOrNull;
    final nodes = _extractTopicNodes(strings);
    return {
      // ignore: use_null_aware_elements
      if (firstId != null) 'id': firstId,
      // ignore: use_null_aware_elements
      if (firstTitle != null) 'title': firstTitle,
      if (nodes.isNotEmpty) 'nodes': nodes,
      if (nodes.isNotEmpty) 'rootNodes': nodes.where((node) => node['parentId'] == null).map((node) => node['id']).toList(),
    };
  }

  List<_HiveStringField> _scanStringFields(Uint8List bytes) {
    final fields = <_HiveStringField>[];
    for (var offset = 0; offset < bytes.length - 6; offset++) {
      final fieldIndex = bytes[offset];
      final type = bytes[offset + 1];
      if (type != 0x04 && type != 0x24) continue;
      final length = bytes[offset + 2] |
          (bytes[offset + 3] << 8) |
          (bytes[offset + 4] << 16) |
          (bytes[offset + 5] << 24);
      if (length <= 0 || length > 20000 || offset + 6 + length > bytes.length) continue;
      try {
        final value = utf8.decode(bytes.sublist(offset + 6, offset + 6 + length), allowMalformed: false);
        fields.add(_HiveStringField(offset: offset, index: fieldIndex, value: value));
      } on FormatException {
        // Ignore non-UTF8 payloads.
      }
    }
    return fields;
  }

  List<Map<String, dynamic>> _extractTopicNodes(List<_HiveStringField> fields) {
    final records = <_NodeRecord>[];
    _NodeRecord? current;

    void flush() {
      final record = current;
      if (record == null) return;
      if (record.id != null && (record.title != null || record.contentJson != null)) {
        records.add(record);
      }
    }

    for (final field in fields) {
      if (field.index == 0 && _isGuruMindNodeId(field.value)) {
        if (current != null && (current.title != null || current.contentJson != null)) {
          flush();
          current = _NodeRecord(id: field.value);
        } else {
          current = _NodeRecord(id: field.value);
        }
        continue;
      }
      final record = current;
      if (record == null) continue;
      if (field.index == 1 && _isGuruMindNodeId(field.value)) record.parentId = field.value;
      if (field.index == 3 && field.value.trim().isNotEmpty) record.title = field.value;
      if (field.index == 14 && field.value.trim().startsWith('{')) record.contentJson = field.value;
    }
    flush();

    final byId = <String, _NodeRecord>{};
    for (final record in records) {
      byId[record.id!] = record;
    }
    final childIdsByParent = <String, List<String>>{};
    for (final record in byId.values) {
      final parentId = record.parentId;
      if (parentId == null) continue;
      childIdsByParent.putIfAbsent(parentId, () => []).add(record.id!);
    }
    return byId.values
        .map((record) => {
              'id': record.id,
              'parentId': record.parentId,
              'title': record.title ?? record.id,
              'content': record.contentJson == null ? null : jsonDecode(record.contentJson!),
              'childIds': childIdsByParent[record.id] ?? const <String>[],
            })
        .toList();
  }

  bool _isGuruMindNodeId(String value) =>
      RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$').hasMatch(value);
}

class _HiveStringField {
  const _HiveStringField({required this.offset, required this.index, required this.value});

  final int offset;
  final int index;
  final String value;
}

class _NodeRecord {
  _NodeRecord({this.id});

  String? id;
  String? parentId;
  String? title;
  String? contentJson;
}
