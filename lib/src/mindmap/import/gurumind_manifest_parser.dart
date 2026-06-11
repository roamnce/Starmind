import 'dart:convert';

import 'gurumind_zip_extractor.dart';
import 'import_exception.dart';

class GuruMindManifest {
  const GuruMindManifest({
    required this.topicPath,
    required this.notePaths,
    this.meta = const {},
    this.assetPaths = const [],
    this.rawManifest = const {},
  });

  final String topicPath;
  final List<String> notePaths;
  final Map<String, dynamic> meta;
  final List<String> assetPaths;
  final Map<String, dynamic> rawManifest;
}

class GuruMindManifestParser {
  GuruMindManifest parse(GuruMindArchive archive) {
    final manifestBytes = archive['manifest.json'];
    if (manifestBytes == null) throw const ImportException('manifest.json missing');
    final manifest = jsonDecode(utf8.decode(manifestBytes)) as Map<String, dynamic>;
    final documents = (manifest['documents'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((document) => Map<String, dynamic>.from(document))
        .toList();
    final topicId = documents
        .where((document) => document['type'] == 'mindMap')
        .map((document) => document['id'] as String?)
        .whereType<String>()
        .firstOrNull;

    final topicPath = manifest['topic'] as String? ??
        (topicId == null ? 'topic.bin' : _findHivePath(archive, 'documents/$topicId/'));
    final notePaths = (manifest['notes'] as List<dynamic>? ?? const [])
        .cast<String>()
        .followedBy(_findNoteHivePaths(archive, topicPath))
        .toSet()
        .toList();
    final assetPaths = (manifest['assets'] as List<dynamic>? ?? const [])
        .cast<String>()
        .followedBy(archive.paths.where((path) => path.contains('/assets/')))
        .toSet()
        .toList();
    final metaDirectory = topicPath.substring(0, topicPath.lastIndexOf('/'));
    final metaPath = '$metaDirectory/meta.json';
    final metaBytes = archive[metaPath] ?? archive['meta.json'];
    final meta = metaBytes == null ? <String, dynamic>{} : Map<String, dynamic>.from(jsonDecode(utf8.decode(metaBytes)) as Map);
    return GuruMindManifest(topicPath: topicPath, notePaths: notePaths, assetPaths: assetPaths, meta: meta, rawManifest: manifest);
  }

  String _findHivePath(GuruMindArchive archive, String prefix) {
    return archive.paths.firstWhere(
      (path) => path.startsWith(prefix) && path.endsWith('.hive'),
      orElse: () => throw ImportException('Hive document missing', details: prefix),
    );
  }

  Iterable<String> _findNoteHivePaths(GuruMindArchive archive, String topicPath) sync* {
    final topicDirectory = topicPath.substring(0, topicPath.lastIndexOf('/'));
    for (final path in archive.paths) {
      if (!path.startsWith('documents/') || !path.endsWith('.hive')) continue;
      if (path.startsWith('$topicDirectory/')) continue;
      yield path;
    }
  }
}
