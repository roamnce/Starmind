import 'dart:convert';
import 'dart:ui';
import 'package:starmind/src/domain/ink_stroke.dart';

/// Annotation types supported by Starmind.
enum AnnotationType {
  highlight,
  underline,
  strikeOut,
  wave,
  ink,
  note,
}

/// Whether an annotation can be exported as a native PDF annotation object.
enum AnnotationCategory {
  /// Standard annotation - exported as PDF native object (highlight, underline).
  /// Other PDF readers can recognize and edit these after export.
  standard,

  /// Private annotation - exported as rendered graphics (wave, ink, note).
  /// Other PDF readers see these as static images, cannot edit.
  private,
}

/// Rectangular region on a PDF page, in page coordinates.
class AnnotationRect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  const AnnotationRect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  double get width => right - left;
  double get height => bottom - top;

  Rect toRect() => Rect.fromLTRB(left, top, right, bottom);

  factory AnnotationRect.fromJson(Map<String, dynamic> json) {
    return AnnotationRect(
      left: (json['l'] as num).toDouble(),
      top: (json['t'] as num).toDouble(),
      right: (json['r'] as num).toDouble(),
      bottom: (json['b'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'l': left,
        't': top,
        'r': right,
        'b': bottom,
      };

  AnnotationRect copy() => AnnotationRect(
        left: left,
        top: top,
        right: right,
        bottom: bottom,
      );
}

/// User-created annotation attached to a specific location in a Document.
///
/// See docs/CONTEXT.md for the distinction between Standard and Private annotations.
class Annotation {
  final String id;
  final String documentId;
  final int pageIndex;
  final AnnotationType type;
  final AnnotationCategory category;
  final String colorHex;
  final DateTime createdAt;
  final DateTime modifiedAt;

  // -- Text-based annotation fields (highlight, underline, wave) --
  final int? startCharIndex;
  final int? endCharIndex;
  final String? selectedText;
  final List<AnnotationRect>? rects;

  // -- Handwriting annotation fields (ink) --
  final List<InkStroke>? strokes;

  // -- Text note annotation fields (note) --
  final String? noteContent;
  final AnnotationRect? noteRect;  // Position anchor for the note

  const Annotation({
    required this.id,
    required this.documentId,
    required this.pageIndex,
    required this.type,
    required this.category,
    this.colorHex = '#FFFF00',
    required this.createdAt,
    required this.modifiedAt,
    this.startCharIndex,
    this.endCharIndex,
    this.selectedText,
    this.rects,
    this.strokes,
    this.noteContent,
    this.noteRect,
  });

  /// Whether this annotation can be exported as a native PDF annotation.
  bool get isStandard => category == AnnotationCategory.standard;

  /// Factory to create a text highlight annotation.
  factory Annotation.highlight({
    required String id,
    required String documentId,
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FFFF00',
  }) {
    final now = DateTime.now();
    return Annotation(
      id: id,
      documentId: documentId,
      pageIndex: pageIndex,
      type: AnnotationType.highlight,
      category: AnnotationCategory.standard,
      colorHex: colorHex,
      createdAt: now,
      modifiedAt: now,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      selectedText: selectedText,
      rects: rects,
    );
  }

  /// Factory to create a text underline annotation.
  factory Annotation.underline({
    required String id,
    required String documentId,
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FFFF00',
  }) {
    final now = DateTime.now();
    return Annotation(
      id: id,
      documentId: documentId,
      pageIndex: pageIndex,
      type: AnnotationType.underline,
      category: AnnotationCategory.standard,
      colorHex: colorHex,
      createdAt: now,
      modifiedAt: now,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      selectedText: selectedText,
      rects: rects,
    );
  }

  /// Factory to create a text strikeOut (strikethrough) annotation.
  factory Annotation.strikeOut({
    required String id,
    required String documentId,
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FF0000',
  }) {
    final now = DateTime.now();
    return Annotation(
      id: id,
      documentId: documentId,
      pageIndex: pageIndex,
      type: AnnotationType.strikeOut,
      category: AnnotationCategory.standard,
      colorHex: colorHex,
      createdAt: now,
      modifiedAt: now,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      selectedText: selectedText,
      rects: rects,
    );
  }

  /// Factory to create a text wave line annotation.
  factory Annotation.wave({
    required String id,
    required String documentId,
    required int pageIndex,
    required int startCharIndex,
    required int endCharIndex,
    required String selectedText,
    required List<AnnotationRect> rects,
    String colorHex = '#FF0000',
  }) {
    final now = DateTime.now();
    return Annotation(
      id: id,
      documentId: documentId,
      pageIndex: pageIndex,
      type: AnnotationType.wave,
      category: AnnotationCategory.private,
      colorHex: colorHex,
      createdAt: now,
      modifiedAt: now,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      selectedText: selectedText,
      rects: rects,
    );
  }

  /// Factory to create an ink/handwriting annotation.
  factory Annotation.ink({
    required String id,
    required String documentId,
    required int pageIndex,
    required List<InkStroke> strokes,
    String colorHex = '#000000',
  }) {
    final now = DateTime.now();
    return Annotation(
      id: id,
      documentId: documentId,
      pageIndex: pageIndex,
      type: AnnotationType.ink,
      category: AnnotationCategory.private,
      colorHex: colorHex,
      createdAt: now,
      modifiedAt: now,
      strokes: strokes,
    );
  }

  /// Factory to create a text note annotation.
  factory Annotation.note({
    required String id,
    required String documentId,
    required int pageIndex,
    required String noteContent,
    required AnnotationRect noteRect,
    String colorHex = '#FFFF00',
  }) {
    final now = DateTime.now();
    return Annotation(
      id: id,
      documentId: documentId,
      pageIndex: pageIndex,
      type: AnnotationType.note,
      category: AnnotationCategory.private,
      colorHex: colorHex,
      createdAt: now,
      modifiedAt: now,
      noteContent: noteContent,
      noteRect: noteRect,
    );
  }

  factory Annotation.fromJson(Map<String, dynamic> json) {
    final typeStr = json['annotation_type'] as String;
    final type = AnnotationType.values.firstWhere(
      (t) => t.name == typeStr,
      orElse: () => AnnotationType.highlight,
    );

    final category = (json['is_standard'] as bool? ?? false)
        ? AnnotationCategory.standard
        : AnnotationCategory.private;

    List<AnnotationRect>? rects;
    if (json['rects_json'] != null && json['rects_json'] is String) {
      final rectsList = jsonDecode(json['rects_json'] as String) as List;
      rects = rectsList
          .map((r) => AnnotationRect.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    }

    List<InkStroke>? strokes;
    if (json['strokes_json'] != null && json['strokes_json'] is String) {
      final strokesList = jsonDecode(json['strokes_json'] as String) as List;
      strokes = strokesList
          .map((s) => InkStroke.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }

    AnnotationRect? noteRect;
    if (json['note_rect_json'] != null && json['note_rect_json'] is String) {
      noteRect = AnnotationRect.fromJson(
          Map<String, dynamic>.from(jsonDecode(json['note_rect_json'] as String)));
    }

    return Annotation(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      pageIndex: json['page_index'] as int,
      type: type,
      category: category,
      colorHex: json['color_hex'] as String? ?? '#FFFF00',
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      modifiedAt: DateTime.fromMillisecondsSinceEpoch(json['modified_at'] as int),
      startCharIndex: json['start_char_index'] as int?,
      endCharIndex: json['end_char_index'] as int?,
      selectedText: json['selected_text'] as String?,
      rects: rects,
      strokes: strokes,
      noteContent: json['note_content'] as String?,
      noteRect: noteRect,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'document_id': documentId,
        'page_index': pageIndex,
        'annotation_type': type.name,
        'is_standard': isStandard,
        'color_hex': colorHex,
        'created_at': createdAt.millisecondsSinceEpoch,
        'modified_at': modifiedAt.millisecondsSinceEpoch,
        if (startCharIndex != null) 'start_char_index': startCharIndex,
        if (endCharIndex != null) 'end_char_index': endCharIndex,
        if (selectedText != null) 'selected_text': selectedText,
        if (rects != null)
          'rects_json': jsonEncode(rects!.map((r) => r.toJson()).toList()),
        if (strokes != null)
          'strokes_json': jsonEncode(strokes!.map((s) => s.toJson()).toList()),
        if (noteContent != null) 'note_content': noteContent,
        if (noteRect != null) 'note_rect_json': jsonEncode(noteRect!.toJson()),
      };

  /// Convenience getters for JSON fields (used by FFI conversion).
  String? get rectsJson =>
      rects != null ? jsonEncode(rects!.map((r) => r.toJson()).toList()) : null;
  String? get strokesJson =>
      strokes != null ? jsonEncode(strokes!.map((s) => s.toJson()).toList()) : null;
  String? get noteRectJson =>
      noteRect != null ? jsonEncode(noteRect!.toJson()) : null;

  Annotation deepCopy() {
    return Annotation(
      id: id,
      documentId: documentId,
      pageIndex: pageIndex,
      type: type,
      category: category,
      colorHex: colorHex,
      createdAt: createdAt,
      modifiedAt: modifiedAt,
      startCharIndex: startCharIndex,
      endCharIndex: endCharIndex,
      selectedText: selectedText,
      rects: rects?.map((r) => r.copy()).toList(),
      strokes: strokes?.map((s) => s.copy()).toList(),
      noteContent: noteContent,
      noteRect: noteRect?.copy(),
    );
  }

  @override
  int get hashCode =>
      id.hashCode ^
      documentId.hashCode ^
      pageIndex.hashCode ^
      type.hashCode ^
      category.hashCode ^
      colorHex.hashCode ^
      createdAt.hashCode ^
      modifiedAt.hashCode ^
      startCharIndex.hashCode ^
      endCharIndex.hashCode ^
      selectedText.hashCode ^
      rects.hashCode ^
      strokes.hashCode ^
      noteContent.hashCode ^
      noteRect.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Annotation &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          documentId == other.documentId &&
          pageIndex == other.pageIndex &&
          type == other.type &&
          category == other.category &&
          colorHex == other.colorHex &&
          createdAt == other.createdAt &&
          modifiedAt == other.modifiedAt &&
          startCharIndex == other.startCharIndex &&
          endCharIndex == other.endCharIndex &&
          selectedText == other.selectedText &&
          rects == other.rects &&
          strokes == other.strokes &&
          noteContent == other.noteContent &&
          noteRect == other.noteRect;
}