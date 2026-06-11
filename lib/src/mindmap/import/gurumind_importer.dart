import 'dart:io';

import '../domain/mindmap_relation.dart';
import '../domain/mindmap_summary.dart';
import '../domain/note.dart';
import '../domain/topic.dart';
import '../storage/mindmap_repository.dart';
import 'gurumind_data_converter.dart';
import 'gurumind_manifest_parser.dart';
import 'gurumind_zip_extractor.dart';
import 'hive_decoder.dart';
import 'import_exception.dart';

class ImportResult {
  const ImportResult({this.topic, this.notes = const [], this.error});

  final Topic? topic;
  final List<Note> notes;
  final ImportException? error;

  bool get isSuccess => topic != null && error == null;
}

class GuruMindImporter {
  GuruMindImporter({
    required MindMapRepository repository,
    GuruMindZipExtractor? zipExtractor,
    GuruMindManifestParser? manifestParser,
    HiveDecoder? hiveDecoder,
    GuruMindDataConverter? converter,
    this.resourceDirectory,
  })
      // ignore: prefer_initializing_formals
      : _repository = repository,
        _zipExtractor = zipExtractor ?? GuruMindZipExtractor(),
        _manifestParser = manifestParser ?? GuruMindManifestParser(),
        _hiveDecoder = hiveDecoder ?? HiveDecoder(),
        _converter = converter ?? GuruMindDataConverter();

  final MindMapRepository _repository;
  final GuruMindZipExtractor _zipExtractor;
  final GuruMindManifestParser _manifestParser;
  final HiveDecoder _hiveDecoder;
  final GuruMindDataConverter _converter;
  final String? resourceDirectory;

  Future<ImportResult> importFile(String filePath) async {
    try {
      final archive = await _zipExtractor.extract(filePath);
      final manifest = _manifestParser.parse(archive);
      final topicBytes = archive[manifest.topicPath];
      if (topicBytes == null) throw ImportException('Topic payload missing', details: manifest.topicPath);

      final topicDocument = _hiveDecoder.decodeBytes(topicBytes).values;
      var topic = _converter.topicFromDocument(topicDocument);
      final notesById = <String, Note>{};
      for (final node in topicDocument['nodes'] as List<dynamic>? ?? const []) {
        final note = _converter.noteFromDocument(Map<String, dynamic>.from(node as Map), topicId: topic.id);
        notesById[note.id] = note;
      }
      for (final notePath in manifest.notePaths) {
        final noteBytes = archive[notePath];
        if (noteBytes == null) throw ImportException('Note payload missing', details: notePath);
        final note = _converter.noteFromDocument(_hiveDecoder.decodeBytes(noteBytes).values, topicId: topic.id);
        notesById[note.id] = note;
      }
      final notes = notesById.values.toList();
      if (topic.rootNoteIds.isEmpty) {
        final rootIds = notes.where((note) => note.parentId == null).map((note) => note.id).toList();
        topic = topic.copyWith(rootNoteIds: rootIds);
      }
      await _repository.updateTopic(topic);
      for (final note in notes) {
        await _repository.updateNote(note);
      }

      await _importRelations(manifest.rawManifest, topic.id);
      await _importSummaries(manifest.rawManifest, topic.id);
      await _importNodeTags(manifest.rawManifest);

      await _copyResources(archive, manifest.assetPaths);
      return ImportResult(topic: topic, notes: notes);
    } on ImportException catch (error) {
      return ImportResult(error: error);
    } catch (error) {
      return ImportResult(error: ImportException('Import failed', details: error.toString()));
    }
  }

  Future<void> _importRelations(Map<String, dynamic> rawManifest, String topicId) async {
    final relationMaps = _converter.relationsFromDocument(rawManifest, topicId: topicId);
    for (final relMap in relationMaps) {
      final relation = MindMapRelation.fromMap(relMap);
      await _repository.createRelation(
        topicId: relation.topicId,
        sourceNoteId: relation.sourceNoteId,
        targetNoteId: relation.targetNoteId,
        text: relation.text,
      );
    }
  }

  Future<void> _importSummaries(Map<String, dynamic> rawManifest, String topicId) async {
    final summaryMaps = _converter.summariesFromDocument(rawManifest, topicId: topicId);
    for (final sumMap in summaryMaps) {
      final summary = MindMapSummary.fromMap(sumMap);
      await _repository.createSummary(
        topicId: summary.topicId,
        parentId: summary.parentId,
        startIndex: summary.startIndex,
        endIndex: summary.endIndex,
        text: summary.text,
      );
    }
  }

  Future<void> _importNodeTags(Map<String, dynamic> rawManifest) async {
    final noteTagNames = _converter.noteTagNamesFromDocument(rawManifest);
    for (final entry in noteTagNames.entries) {
      final noteId = entry.key;
      for (final tagName in entry.value) {
        final tagId = await _repository.createTag(tagName, null, null);
        await _repository.bindTagToNote(noteId: noteId, tagId: tagId);
      }
    }
  }

  Future<void> _copyResources(GuruMindArchive archive, List<String> assetPaths) async {
    final directory = resourceDirectory;
    if (directory == null) return;
    await Directory(directory).create(recursive: true);
    for (final assetPath in assetPaths) {
      final bytes = archive[assetPath];
      if (bytes == null) continue;
      final fileName = assetPath.split('/').last;
      await File('$directory/$fileName').writeAsBytes(bytes);
    }
  }
}
