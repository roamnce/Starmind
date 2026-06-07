import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';

import 'import_exception.dart';

class GuruMindArchive {
  const GuruMindArchive(this.files);

  final Map<String, Uint8List> files;

  Uint8List? operator [](String path) => files[path];

  Iterable<String> get paths => files.keys;
}

class GuruMindZipExtractor {
  Future<GuruMindArchive> extract(String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) throw ImportException('GuruMind file not found', details: filePath);
    final archive = ZipDecoder().decodeBytes(await file.readAsBytes());
    final files = <String, Uint8List>{};
    for (final entry in archive.files) {
      if (entry.isFile) files[entry.name.replaceAll('\\', '/')] = Uint8List.fromList(entry.content as List<int>);
    }
    return GuruMindArchive(files);
  }
}
