/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

// PDF annotation integration helpers for main.dart
// This file contains widget builders for ink drawing layer and annotation rendering

import 'package:flutter/material.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';
import 'package:starmind/src/pdf/widgets/ink_canvas_layer.dart';
import 'package:starmind/src/pdf/widgets/ink_toolbar.dart' show InkTool;
import 'package:starmind/src/pdf/widgets/annotation_renderer.dart';
import 'package:starmind/src/pdf/annotation_controller.dart';
import 'package:starmind/src/pdf/undo_redo_stack.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/domain/ink_stroke.dart';

/// Builds the ink drawing layer overlay for a PDF page.
///
/// [annotationController] is optional - if null, a no-op controller is used.
Widget buildInkDrawingLayer({
  required PdfViewportController controller,
  required int pageIndex,
  required bool isInkMode,
  required InkTool currentTool,
  required String currentColor,
  required double strokeWidth,
  required double scale, // Static baseScale of the page layout
  AnnotationController? annotationController,
}) {
  return Positioned.fill(
    child: InkCanvasLayer(
      annotationController: annotationController ?? _NullAnnotationController(),
      pageIndex: pageIndex,
      isInkMode: isInkMode,
      palmRejectionEnabled: controller.palmRejectionEnabled,
      currentTool: currentTool,
      currentColor: currentColor,
      strokeWidth: strokeWidth,
      scale: scale,
      pdfWidth: controller.pageSizes[pageIndex]?.width ?? 595.0,
      pdfHeight: controller.pageSizes[pageIndex]?.height ?? 842.0,
    ),
  );
}

/// Builds the annotation renderer overlay for a PDF page.
Widget buildAnnotationRenderer({
  required PdfViewportController controller,
  required int pageIndex,
  required double scale, // Static baseScale of the page layout
}) {
  final pdfSize = controller.pageSizes[pageIndex];
  if (pdfSize == null) return const SizedBox.shrink();

  // Convert highlights to annotations for rendering
  final annotations = controller.highlights
      .where((h) => h.pageIndex == pageIndex)
      .map((h) => Annotation.highlight(
            id: h.id,
            documentId: 'current-doc',
            pageIndex: h.pageIndex,
            startCharIndex: h.startCharIndex,
            endCharIndex: h.endCharIndex,
            selectedText: h.text,
            rects: h.rects.map((r) => AnnotationRect(
                  left: r.left,
                  top: r.top,
                  right: r.right,
                  bottom: r.bottom,
                )).toList(),
            colorHex: _colorToHex(h.color),
          ))
      .toList();

  return Positioned.fill(
    child: CustomPaint(
      painter: AnnotationRenderer(
        annotations: annotations,
        scale: scale,
        pdfWidth: pdfSize.width,
        pdfHeight: pdfSize.height,
      ),
    ),
  );
}

/// Gets the hex string from a Color.
String _colorToHex(Color color) {
  final argb = color.toARGB32();
  return '#${(argb & 0x00FFFFFF).toRadixString(16).toUpperCase().padLeft(6, '0')}';
}

/// Determines if the current tool is an ink tool.
bool isInkTool(String tool) {
  return tool == 'pen' || tool == 'highlight' || tool == 'eraser';
}

/// A no-op annotation controller for the ink layer.
/// Used when no real AnnotationController is provided.
/// Ignores all operations silently.
class _NullAnnotationController extends ChangeNotifier implements AnnotationController {
  @override
  final UndoRedoStack undoRedoStack = UndoRedoStack();

  @override
  List<Annotation> annotationsForPage(int pageIndex) => [];

  @override
  Future<void> createInk({
    required int pageIndex,
    required List<InkStroke> strokes,
    String colorHex = '#000000',
  }) async {}

  @override
  Future<void> deleteAnnotation(String id) async {}

  @override
  String get documentId => '';

  @override
  List<Annotation> get annotations => [];

  @override
  bool get canUndo => false;

  @override
  bool get canRedo => false;

  @override
  Future<void> loadAnnotations() async {}

  @override
  Future<void> createHighlight({
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FFFF00',
  }) async {}

  @override
  Future<void> createUnderline({
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FFFF00',
  }) async {}

  @override
  Future<void> createWave({
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FF0000',
  }) async {}

  @override
  Future<void> createStrikeOut({
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FF0000',
  }) async {}

  @override
  Future<void> createNote({
    required int pageIndex,
    required String content,
    required AnnotationRect rect,
    String colorHex = '#FFFF00',
  }) async {}

  @override
  Future<void> updateColor(String annotationId, String newColorHex) async {}

  @override
  Future<void> updateNoteContent(String annotationId, String newContent) async {}

  @override
  Future<void> undo() async {}

  @override
  Future<void> redo() async {}

  @override
  void clearUndoRedo() {}
}