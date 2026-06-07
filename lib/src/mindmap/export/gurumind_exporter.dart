import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';

import '../domain/note.dart';
import '../domain/topic.dart';
import '../import/gurumind_data_converter.dart';
import 'export_exception.dart';
import 'hive_encoder.dart';

class GuruMindDataExporter {
  GuruMindDataExporter({HiveEncoder? hiveEncoder, GuruMindDataConverter? converter})
      : _hiveEncoder = hiveEncoder ?? HiveEncoder(),
        _converter = converter ?? GuruMindDataConverter();

  final HiveEncoder _hiveEncoder;
  final GuruMindDataConverter _converter;

  Future<File> exportTopic({
    required Topic topic,
    required List<Note> notes,
    required String outputPath,
    List<String> assetPaths = const [],
    List<int>? thumbnailBytes,
  }) async {
    if (!outputPath.endsWith('.gurumind')) {
      throw ExportException('Output path must end with .gurumind', details: outputPath);
    }
    final archive = Archive();
    final exportedAt = DateTime.now().toIso8601String();
    final topicDir = 'documents/${topic.id}';
    final topicHivePath = '$topicDir/doc_${topic.id}.hive';
    final notePaths = <String>[];
    final exportedAssets = <String>[];

    final topicDocument = _converter.topicToDocument(topic);
    final topicBytes = _hiveEncoder.encodeDocument(topicDocument);
    archive.addFile(ArchiveFile(topicHivePath, topicBytes.length, topicBytes));
    _addJsonFile(archive, '$topicDir/meta.json', {
      'id': topic.id,
      'title': topic.title,
      'type': 'mindMap',
      'createdAt': topic.createdAt.toIso8601String(),
      'updatedAt': topic.updatedAt.toIso8601String(),
      'thumbnailPath': '$topicDir/assets/thumb.png',
      'linkedIds': topic.pdfIds,
    });

    final thumbnail = thumbnailBytes ?? _defaultThumbnailBytes(topic.title);
    final thumbnailPath = '$topicDir/assets/thumb.png';
    exportedAssets.add(thumbnailPath);
    archive.addFile(ArchiveFile(thumbnailPath, thumbnail.length, thumbnail));

    for (final assetPath in assetPaths) {
      final file = File(assetPath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      final archivePath = '$topicDir/assets/${file.uri.pathSegments.last}';
      exportedAssets.add(archivePath);
      archive.addFile(ArchiveFile(archivePath, bytes.length, bytes));
    }

    for (final note in notes) {
      final noteDocument = _converter.noteToDocument(note);
      final guruNoteId = noteDocument['id'] as String;
      final noteDir = 'documents/$guruNoteId';
      final path = '$noteDir/doc_$guruNoteId.hive';
      final bytes = _hiveEncoder.encodeDocument(noteDocument);
      notePaths.add(path);
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
      _addJsonFile(archive, '$noteDir/meta.json', {
        'id': guruNoteId,
        'title': note.title,
        'type': 'note',
        'noteType': 'node',
        'linkedIds': [topic.id],
        'createdAt': note.createdAt.toIso8601String(),
        'updatedAt': note.updatedAt.toIso8601String(),
      });
    }

    final manifest = {
      'version': 1,
      'exportedAt': exportedAt,
      'documentCount': 1,
      'documents': [
        {'id': topic.id, 'type': 'mindMap', 'title': topic.title},
      ],
      'tags': const <Map<String, dynamic>>[],
      'topic': topicHivePath,
      'notes': notePaths,
      'assets': exportedAssets,
      'thumbnail': thumbnailPath,
    };
    _addJsonFile(archive, 'manifest.json', manifest);

    final encoded = ZipEncoder().encode(archive);
    final file = File(outputPath);
    await file.parent.create(recursive: true);
    return file.writeAsBytes(encoded);
  }

  Map<String, dynamic> topicToGuruMindDocument(Topic topic) => _converter.topicToDocument(topic);

  Map<String, dynamic> noteToGuruMindDocument(Note note) => _converter.noteToDocument(note);

  void _addJsonFile(Archive archive, String path, Map<String, dynamic> json) {
    final bytes = utf8.encode(jsonEncode(json));
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  List<int> _defaultThumbnailBytes(String title) => utf8.encode('Starmind GuruMind export: $title');
}
