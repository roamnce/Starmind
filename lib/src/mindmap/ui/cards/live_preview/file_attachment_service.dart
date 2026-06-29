import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FileAttachmentService {
  static const _imageExtensions = {
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp',
  };

  static bool isImageFile(String fileName) {
    final ext = p.extension(fileName).toLowerCase();
    return _imageExtensions.contains(ext);
  }

  static Future<String> copyToAssets(String sourcePath) async {
    final appDir = await getApplicationDocumentsDirectory();
    final sourceFile = File(sourcePath);
    final ext = p.extension(sourcePath);
    final baseName = p.basenameWithoutExtension(sourcePath);
    final uuid = const Uuid().v4();

    String targetDir;
    String newName;
    if (isImageFile(sourcePath)) {
      targetDir = p.join(appDir.path, 'assets', 'images');
      newName = '${baseName}_$uuid$ext';
    } else {
      targetDir = p.join(appDir.path, 'assets', 'files');
      newName = '${uuid}_$baseName$ext';
    }

    await Directory(targetDir).create(recursive: true);
    final targetPath = p.join(targetDir, newName);
    await sourceFile.copy(targetPath);
    return targetPath;
  }

  static String toMarkdownInsertion(String filePath, {String? alt}) {
    final fileName = p.basename(filePath);
    if (isImageFile(filePath)) {
      final label = alt ?? fileName;
      return '![$label]($filePath)';
    }
    return '[$fileName]($filePath)';
  }
}