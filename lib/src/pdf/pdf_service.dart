/// 🤖 Generated wholly or partially with Claude Code; Google Antigravity
library;

import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../rust/api/pdf.dart' as ffi;

class PdfService {
  static final PdfService _instance = PdfService._internal();
  factory PdfService() => _instance;
  PdfService._internal();

  bool _initialized = false;

  /// Finds the pdfium.dll/libpdfium.so path that was downloaded by pdfrx.
  /// pdfrx downloads it to native assets during build.
  Future<String?> _findPdfiumPath() async {
    if (Platform.isWindows) {
      // pdfrx puts pdfium.dll in the executable directory on Windows
      final exePath = Platform.resolvedExecutable;
      final exeDir = p.dirname(exePath);
      final dllPath = p.join(exeDir, 'pdfium.dll');

      if (File(dllPath).existsSync()) {
        debugPrint('Starmind: Found pdfium.dll at $dllPath');
        return dllPath;
      }

      // Also try looking in build output directories
      final buildPaths = [
        p.join(exeDir, 'data', 'flutter_assets', 'pdfium.dll'),
        p.join(exeDir, 'rust', 'target', 'release', 'pdfium.dll'),
      ];

      for (final path in buildPaths) {
        if (File(path).existsSync()) {
          debugPrint('Starmind: Found pdfium.dll at $path');
          return path;
        }
      }

      debugPrint('Starmind: pdfium.dll not found, will try system library search');
      return null;
    }

    if (Platform.isAndroid) {
      // On Android, pdfrx bundles libpdfium.so in the app's lib directory
      // The Rust library should be able to find it via bind_to_system_library
      return null; // Let Rust use system library search
    }

    // Other platforms - use system library search
    return null;
  }

  /// Initializes the underlying PDFium library.
  Future<void> initialize({String? libraryPath}) async {
    if (_initialized) return;
    try {
      String? targetPath = libraryPath;
      if (targetPath == null) {
        targetPath = await _findPdfiumPath();
      }

      debugPrint('Starmind: Initializing PDFium with path=$targetPath');
      await ffi.initPdfium(libraryPath: targetPath);
      _initialized = true;
      debugPrint('Starmind: PDFium initialized successfully.');
    } catch (e) {
      debugPrint('Starmind: PDFium initialization failed: $e');
      rethrow;
    }
  }

  Future<String> loadDocument(String filePath) async {
    await initialize();
    return ffi.loadDocument(filePath: filePath);
  }

  Future<void> closeDocument(String docId) async {
    await ffi.closeDocument(docId: docId);
  }

  Future<int> getPageCount(String docId) async {
    return ffi.getPageCount(docId: docId);
  }

  Future<(double, double)> getPageSize(String docId, int pageIndex) async {
    return ffi.getPageSize(docId: docId, pageIndex: pageIndex);
  }

  Future<Uint8List> renderViewport({
    required String docId,
    required int pageIndex,
    required double pdfLeft,
    required double pdfTop,
    required double pdfRight,
    required double pdfBottom,
    required int targetWidth,
    required int targetHeight,
    double? renderDpi,
  }) async {
    final req = ffi.ViewportRequest(
      docId: docId,
      pageIndex: pageIndex,
      pdfLeft: pdfLeft,
      pdfTop: pdfTop,
      pdfRight: pdfRight,
      pdfBottom: pdfBottom,
      targetWidth: targetWidth,
      targetHeight: targetHeight,
      renderDpi: renderDpi,
    );
    return ffi.renderViewport(req: req);
  }

  Future<List<ffi.CharInfo>> getPageChars(String docId, int pageIndex) async {
    return ffi.getPageChars(docId: docId, pageIndex: pageIndex);
  }
}