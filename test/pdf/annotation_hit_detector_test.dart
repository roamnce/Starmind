import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/domain/ink_stroke.dart';
import 'package:starmind/src/pdf/widgets/annotation_hit_detector.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';

class MockViewportController extends PdfViewportController {
  @override
  final Map<int, Size> pageSizes = {
    0: const Size(600, 800),
  };

  @override
  double get zoom => 1.0;

  @override
  Offset get panOffset => Offset.zero;
}

void main() {
  group('AnnotationHitDetector', () {
    late AnnotationHitDetector detector;
    late MockViewportController mockController;

    setUp(() {
      mockController = MockViewportController();
      detector = AnnotationHitDetector(viewportController: mockController);
    });

    test('should return null when no annotations exist', () {
      final result = detector.hitTest(
        pageIndex: 0,
        screenPosition: const Offset(100, 100),
        annotations: [],
      );

      expect(result, isNull);
    });

    test('should detect highlight annotation when hit', () {
      final annotation = Annotation.highlight(
        id: 'test-1',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 0,
        endCharIndex: 10,
        selectedText: 'test text',
        rects: [
          AnnotationRect(left: 50, top: 700, right: 150, bottom: 750),
        ],
        colorHex: '#FF0000',
      );

      // Screen position (100, 100) maps to PDF (100, 700) in PDF coordinates
      // PDF Y coordinate: 800 - 100 = 700
      final result = detector.hitTest(
        pageIndex: 0,
        screenPosition: const Offset(100, 100),
        annotations: [annotation],
      );

      expect(result, isNotNull);
      expect(result?.id, 'test-1');
    });

    test('should not detect highlight when position is outside', () {
      final annotation = Annotation.highlight(
        id: 'test-2',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 0,
        endCharIndex: 10,
        selectedText: 'test text',
        rects: [
          AnnotationRect(left: 50, top: 50, right: 150, bottom: 80),
        ],
        colorHex: '#FF0000',
      );

      // Position way outside the annotation rect
      final result = detector.hitTest(
        pageIndex: 0,
        screenPosition: const Offset(500, 500),
        annotations: [annotation],
      );

      expect(result, isNull);
    });

    test('should detect ink annotation when near stroke', () {
      final annotation = Annotation.ink(
        id: 'test-3',
        documentId: 'doc-1',
        pageIndex: 0,
        strokes: [
          InkStroke(
            points: [
              InkPoint(x: 100, y: 500),
              InkPoint(x: 150, y: 500),
              InkPoint(x: 200, y: 500),
            ],
            color: 0xFF000000,
            strokeWidth: 3.0,
          ),
        ],
      );

      // Screen Y=300 maps to PDF Y=800-300=500, which matches the ink stroke
      // Screen X=125 maps to PDF X=125
      // Ink point at (150, 500), distance from (125, 500) is 25
      // With hitPadding=8 and strokeWidth/2=1.5, effective padding is 9.5
      // 25 > 9.5, so this won't hit. Let's use a point closer to the stroke.
      final result = detector.hitTest(
        pageIndex: 0,
        screenPosition: const Offset(148, 300), // PDF: (148, 500), distance 2 from (150, 500)
        annotations: [annotation],
        hitPadding: 8.0,
      );

      expect(result, isNotNull);
      expect(result?.id, 'test-3');
    });

    test('should detect note annotation when hit', () {
      final annotation = Annotation.note(
        id: 'test-4',
        documentId: 'doc-1',
        pageIndex: 0,
        noteContent: 'Test note',
        noteRect: AnnotationRect(left: 50, top: 730, right: 70, bottom: 750),
        colorHex: '#FFFF00',
      );

      // Screen Y=70 maps to PDF Y=800-70=730, which is inside the note rect
      final result = detector.hitTest(
        pageIndex: 0,
        screenPosition: const Offset(60, 70),
        annotations: [annotation],
      );

      expect(result, isNotNull);
      expect(result?.id, 'test-4');
    });

    test('should return top-most annotation when overlapping', () {
      final annotation1 = Annotation.highlight(
        id: 'bottom',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 0,
        endCharIndex: 10,
        selectedText: 'test',
        rects: [
          AnnotationRect(left: 50, top: 50, right: 150, bottom: 150),
        ],
        colorHex: '#FF0000',
      );

      final annotation2 = Annotation.highlight(
        id: 'top',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 0,
        endCharIndex: 10,
        selectedText: 'test',
        rects: [
          AnnotationRect(left: 60, top: 60, right: 140, bottom: 140),
        ],
        colorHex: '#00FF00',
      );

      final result = detector.hitTest(
        pageIndex: 0,
        screenPosition: const Offset(100, 700), // Inside both
        annotations: [annotation1, annotation2],
      );

      // Should return the last (top-most) annotation
      expect(result?.id, 'top');
    });

    test('should use hitPadding for near-miss detection', () {
      final annotation = Annotation.highlight(
        id: 'test-5',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 0,
        endCharIndex: 10,
        selectedText: 'test',
        rects: [
          AnnotationRect(left: 100, top: 100, right: 200, bottom: 200),
        ],
        colorHex: '#FF0000',
      );

      // Position just outside the rect, but within padding
      final result = detector.hitTest(
        pageIndex: 0,
        screenPosition: const Offset(95, 600), // PDF: (95, 200) - just outside left edge
        annotations: [annotation],
        hitPadding: 10.0, // 10px padding should include this
      );

      expect(result, isNotNull);
    });
  });
}
