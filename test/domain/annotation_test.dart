import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/domain/ink_stroke.dart';
import 'package:starmind/src/domain/in_memory_storage_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Annotation', () {
    test('should create highlight annotation', () {
      final annotation = Annotation.highlight(
        id: 'test-id',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Hello World',
        rects: [
          const AnnotationRect(left: 100, top: 200, right: 200, bottom: 220),
        ],
        colorHex: '#FFFF00',
      );

      expect(annotation.id, equals('test-id'));
      expect(annotation.type, equals(AnnotationType.highlight));
      expect(annotation.category, equals(AnnotationCategory.standard));
      expect(annotation.isStandard, isTrue);
      expect(annotation.colorHex, equals('#FFFF00'));
      expect(annotation.startCharIndex, equals(10));
      expect(annotation.endCharIndex, equals(20));
      expect(annotation.selectedText, equals('Hello World'));
      expect(annotation.rects, hasLength(1));
    });

    test('should create underline annotation', () {
      final annotation = Annotation.underline(
        id: 'test-id',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Underlined',
        rects: [
          const AnnotationRect(left: 100, top: 200, right: 200, bottom: 220),
        ],
      );

      expect(annotation.type, equals(AnnotationType.underline));
      expect(annotation.category, equals(AnnotationCategory.standard));
      expect(annotation.isStandard, isTrue);
    });

    test('should create strikeOut annotation', () {
      final annotation = Annotation.strikeOut(
        id: 'test-id',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Deleted text',
        rects: [
          const AnnotationRect(left: 100, top: 200, right: 200, bottom: 220),
        ],
      );

      expect(annotation.type, equals(AnnotationType.strikeOut));
      expect(annotation.category, equals(AnnotationCategory.standard));
      expect(annotation.isStandard, isTrue);
      expect(annotation.colorHex, equals('#FF0000'));
    });

    test('should serialize and deserialize strikeOut', () {
      final annotation = Annotation.strikeOut(
        id: 'test-id',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Deleted text',
        rects: [
          const AnnotationRect(left: 100, top: 200, right: 200, bottom: 220),
        ],
      );

      final json = annotation.toJson();
      final restored = Annotation.fromJson(json);

      expect(restored.type, equals(AnnotationType.strikeOut));
      expect(restored.category, equals(AnnotationCategory.standard));
      expect(restored.colorHex, equals('#FF0000'));
      expect(restored.startCharIndex, equals(10));
      expect(restored.endCharIndex, equals(20));
      expect(restored.selectedText, equals('Deleted text'));
    });

    test('should create wave annotation', () {
      final annotation = Annotation.wave(
        id: 'test-id',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Wavy text',
        rects: [
          const AnnotationRect(left: 100, top: 200, right: 200, bottom: 220),
        ],
      );

      expect(annotation.type, equals(AnnotationType.wave));
      expect(annotation.category, equals(AnnotationCategory.private));
      expect(annotation.isStandard, isFalse);
    });

    test('should create ink annotation', () {
      final strokes = [
        InkStroke(
          points: const [
            InkPoint(x: 10, y: 20),
            InkPoint(x: 30, y: 40),
          ],
          color: 0xFF000000,
          strokeWidth: 2.0,
        ),
      ];

      final annotation = Annotation.ink(
        id: 'test-id',
        documentId: 'doc-1',
        pageIndex: 0,
        strokes: strokes,
      );

      expect(annotation.type, equals(AnnotationType.ink));
      expect(annotation.category, equals(AnnotationCategory.private));
      expect(annotation.isStandard, isFalse);
      expect(annotation.strokes, hasLength(1));
      expect(annotation.strokes!.first.points, hasLength(2));
    });

    test('should create note annotation', () {
      final annotation = Annotation.note(
        id: 'test-id',
        documentId: 'doc-1',
        pageIndex: 0,
        noteContent: 'This is a note',
        noteRect: const AnnotationRect(left: 100, top: 200, right: 120, bottom: 220),
      );

      expect(annotation.type, equals(AnnotationType.note));
      expect(annotation.category, equals(AnnotationCategory.private));
      expect(annotation.noteContent, equals('This is a note'));
      expect(annotation.noteRect, isNotNull);
    });

    test('should serialize to JSON and back', () {
      final original = Annotation.highlight(
        id: 'test-id',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Hello World',
        rects: [
          const AnnotationRect(left: 100, top: 200, right: 200, bottom: 220),
        ],
        colorHex: '#FFFF00',
      );

      final json = original.toJson();
      final restored = Annotation.fromJson(json);

      expect(restored.id, equals(original.id));
      expect(restored.documentId, equals(original.documentId));
      expect(restored.pageIndex, equals(original.pageIndex));
      expect(restored.type, equals(original.type));
      expect(restored.category, equals(original.category));
      expect(restored.colorHex, equals(original.colorHex));
      expect(restored.startCharIndex, equals(original.startCharIndex));
      expect(restored.endCharIndex, equals(original.endCharIndex));
      expect(restored.selectedText, equals(original.selectedText));
      expect(restored.rects, hasLength(1));
    });

    test('should deep copy', () {
      final original = Annotation.highlight(
        id: 'test-id',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Hello World',
        rects: [
          const AnnotationRect(left: 100, top: 200, right: 200, bottom: 220),
        ],
      );

      final copy = original.deepCopy();

      expect(copy.id, equals(original.id));
      // rects are lists, so equality check fails due to list reference
      // Just verify fields are equal individually
      expect(copy.documentId, equals(original.documentId));
      expect(copy.pageIndex, equals(original.pageIndex));
      expect(copy.startCharIndex, equals(original.startCharIndex));
      expect(copy.endCharIndex, equals(original.endCharIndex));
      expect(copy.selectedText, equals(original.selectedText));
      expect(copy.rects!.length, equals(original.rects!.length));
    });
  });

  group('InkStroke', () {
    test('should create stroke with points', () {
      final stroke = InkStroke(
        points: const [
          InkPoint(x: 10, y: 20, pressure: 0.5),
          InkPoint(x: 30, y: 40, pressure: 0.8),
        ],
        color: 0xFF000000,
        strokeWidth: 2.0,
      );

      expect(stroke.points, hasLength(2));
      expect(stroke.color, equals(0xFF000000));
      expect(stroke.strokeWidth, equals(2.0));
      expect(stroke.isEmpty, isFalse);
    });

    test('should calculate bounds', () {
      final stroke = InkStroke(
        points: const [
          InkPoint(x: 10, y: 20),
          InkPoint(x: 30, y: 40),
          InkPoint(x: 50, y: 10),
        ],
        color: 0xFF000000,
      );

      final bounds = stroke.bounds;
      expect(bounds, isNotNull);
      expect(bounds!.left, equals(10));
      expect(bounds.top, equals(10));
      expect(bounds.right, equals(50));
      expect(bounds.bottom, equals(40));
    });

    test('should serialize to JSON and back', () {
      final original = InkStroke(
        points: const [
          InkPoint(x: 10, y: 20, pressure: 0.5),
          InkPoint(x: 30, y: 40),
        ],
        color: 0xFF000000,
        strokeWidth: 2.0,
        isHighlighter: true,
      );

      final json = original.toJson();
      final restored = InkStroke.fromJson(json);

      expect(restored.points, hasLength(2));
      expect(restored.color, equals(original.color));
      expect(restored.strokeWidth, equals(original.strokeWidth));
      expect(restored.isHighlighter, equals(original.isHighlighter));
    });
  });

  group('InMemoryStorageRepository Annotation Operations', () {
    late InMemoryStorageRepository repository;

    setUp(() async {
      repository = InMemoryStorageRepository();
      await repository.initialize('', '');
    });

    test('should create and retrieve annotation', () async {
      final annotation = Annotation.highlight(
        id: 'anno-1',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [
          const AnnotationRect(left: 100, top: 200, right: 200, bottom: 220),
        ],
      );

      final id = await repository.createAnnotation(annotation);
      expect(id, equals('anno-1'));

      final annotations = await repository.getAnnotations('doc-1');
      expect(annotations, hasLength(1));
      expect(annotations.first.id, equals('anno-1'));
    });

    test('should get annotations for specific page', () async {
      await repository.createAnnotation(Annotation.highlight(
        id: 'anno-1',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Page 0',
        rects: [],
      ));

      await repository.createAnnotation(Annotation.highlight(
        id: 'anno-2',
        documentId: 'doc-1',
        pageIndex: 1,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Page 1',
        rects: [],
      ));

      final page0Annotations = await repository.getAnnotationsForPage('doc-1', 0);
      expect(page0Annotations, hasLength(1));
      expect(page0Annotations.first.selectedText, equals('Page 0'));

      final page1Annotations = await repository.getAnnotationsForPage('doc-1', 1);
      expect(page1Annotations, hasLength(1));
      expect(page1Annotations.first.selectedText, equals('Page 1'));
    });

    test('should update annotation color', () async {
      await repository.createAnnotation(Annotation.highlight(
        id: 'anno-1',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
        colorHex: '#FFFF00',
      ));

      await repository.updateAnnotationColor('anno-1', '#FF0000');

      final annotations = await repository.getAnnotations('doc-1');
      expect(annotations.first.colorHex, equals('#FF0000'));
    });

    test('should update note content', () async {
      await repository.createAnnotation(Annotation.note(
        id: 'anno-1',
        documentId: 'doc-1',
        pageIndex: 0,
        noteContent: 'Original content',
        noteRect: const AnnotationRect(left: 0, top: 0, right: 10, bottom: 10),
      ));

      await repository.updateAnnotationNoteContent('anno-1', 'Updated content');

      final annotations = await repository.getAnnotations('doc-1');
      expect(annotations.first.noteContent, equals('Updated content'));
    });

    test('should delete annotation', () async {
      await repository.createAnnotation(Annotation.highlight(
        id: 'anno-1',
        documentId: 'doc-1',
        pageIndex: 0,
        startCharIndex: 10,
        endCharIndex: 20,
        selectedText: 'Test',
        rects: [],
      ));

      await repository.deleteAnnotation('anno-1');

      final annotations = await repository.getAnnotations('doc-1');
      expect(annotations, isEmpty);
    });
  });
}
