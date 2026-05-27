import 'dart:convert';
import 'dart:io';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/domain/storage_repository.dart';
import 'package:starmind/src/rust/api/pdf.dart' as pdf_ffi;
import 'package:starmind/src/rust/api/storage.dart' as storage_ffi;
import 'package:starmind/src/rust/storage/annotations.dart' as ffi_annotation;

/// Service for exporting PDFs with annotations.
///
/// Export behavior:
/// - Standard annotations (highlight, underline): exported as PDF native annotations
/// - Private annotations (wave, ink, note): exported as rendered graphics
class PdfExportService {
  final StorageRepository _repository;

  PdfExportService(this._repository);

  /// Exports a PDF with all its annotations to a new file.
  ///
  /// Returns the path to the exported file.
  Future<String> exportPdfWithAnnotations({
    required String documentId,
    required String outputPath,
  }) async {
    // Get document info
    final documents = await _repository.getDocuments();
    final doc = documents.firstWhere(
      (d) => d.id == documentId,
      orElse: () => throw Exception('Document not found: $documentId'),
    );

    // Get all annotations
    final annotations = await _repository.getAnnotations(documentId);

    // Convert annotations to FFI format
    final ffiAnnotations = annotations.map(_convertToFfi).toList();

    // Call Rust export function
    await pdf_ffi.exportPdfWithAnnotations(
      sourcePath: doc.filePath,
      outputPath: outputPath,
      annotations: ffiAnnotations,
    );

    return outputPath;
  }

  /// Exports only standard annotations (for sharing with other PDF readers).
  Future<String> exportPdfStandardOnly({
    required String documentId,
    required String outputPath,
  }) async {
    final documents = await _repository.getDocuments();
    final doc = documents.firstWhere(
      (d) => d.id == documentId,
      orElse: () => throw Exception('Document not found: $documentId'),
    );

    final annotations = await _repository.getAnnotations(documentId);
    final standardAnnotations = annotations.where((a) => a.isStandard).toList();
    final ffiAnnotations = standardAnnotations.map(_convertToFfi).toList();

    await pdf_ffi.exportPdfWithAnnotations(
      sourcePath: doc.filePath,
      outputPath: outputPath,
      annotations: ffiAnnotations,
    );

    return outputPath;
  }

  /// Exports annotations to a separate JSON file.
  Future<String> exportAnnotationsJson({
    required String documentId,
    required String outputPath,
  }) async {
    final annotations = await _repository.getAnnotations(documentId);
    final json = annotations.map((a) => a.toJson()).toList();

    final file = File(outputPath);
    await file.writeAsString(_prettyJson(json));

    return outputPath;
  }

  /// Imports annotations from a JSON file.
  Future<void> importAnnotationsJson({
    required String documentId,
    required String inputPath,
    bool merge = true,
  }) async {
    final file = File(inputPath);
    final content = await file.readAsString();
    final jsonList = _parseJsonList(content);

    if (!merge) {
      await storage_ffi.deleteAnnotationsForDocument(documentId: documentId);
    }

    for (final json in jsonList) {
      final annotation = Annotation.fromJson(Map<String, dynamic>.from(json));
      await _repository.createAnnotation(annotation);
    }
  }

  /// Converts Dart Annotation to FFI AnnotationRecord.
  ffi_annotation.AnnotationRecord _convertToFfi(Annotation annotation) {
    return ffi_annotation.AnnotationRecord(
      id: annotation.id,
      documentId: annotation.documentId,
      pageIndex: annotation.pageIndex,
      annotationType: annotation.type.name,
      isStandard: annotation.isStandard,
      colorHex: annotation.colorHex,
      createdAt: annotation.createdAt.millisecondsSinceEpoch,
      modifiedAt: annotation.modifiedAt.millisecondsSinceEpoch,
      startCharIndex: annotation.startCharIndex,
      endCharIndex: annotation.endCharIndex,
      selectedText: annotation.selectedText,
      rectsJson: annotation.rectsJson,
      strokesJson: annotation.strokesJson,
      noteContent: annotation.noteContent,
      noteRectJson: annotation.noteRectJson,
    );
  }

  String _prettyJson(List<dynamic> json) {
    return const JsonEncoder.withIndent('  ').convert(json);
  }

  List<dynamic> _parseJsonList(String content) {
    final decoded = jsonDecode(content);
    if (decoded is List) return decoded;
    throw FormatException('Expected JSON array');
  }
}

// JSON encoder for pretty printing
class JsonEncoder {
  final String indent;
  const JsonEncoder.withIndent(this.indent);

  String convert(Object? object) {
    return _encode(object, 0);
  }

  String _encode(Object? object, int level) {
    if (object == null) return 'null';
    if (object is String) return '"${_escape(object)}"';
    if (object is num || object is bool) return object.toString();

    final spaces = indent * level;
    final nextSpaces = indent * (level + 1);

    if (object is List) {
      if (object.isEmpty) return '[]';
      final items = object.map((e) => '$nextSpaces${_encode(e, level + 1)}');
      return '[\n${items.join(',\n')}\n$spaces]';
    }

    if (object is Map) {
      if (object.isEmpty) return '{}';
      final items = object.entries.map((e) {
        final key = '"${_escape(e.key.toString())}"';
        final value = _encode(e.value, level + 1);
        return '$nextSpaces$key: $value';
      });
      return '{\n${items.join(',\n')}\n$spaces}';
    }

    return '"${_escape(object.toString())}"';
  }

  String _escape(String s) {
    return s
        .replaceAll('\\', '\\\\')
        .replaceAll('"', '\\"')
        .replaceAll('\n', '\\n')
        .replaceAll('\r', '\\r')
        .replaceAll('\t', '\\t');
  }
}
