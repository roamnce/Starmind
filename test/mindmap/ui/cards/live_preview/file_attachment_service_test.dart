import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/cards/live_preview/file_attachment_service.dart';

void main() {
  group('FileAttachmentService', () {
    test('isImageFile returns true for image extensions', () {
      expect(FileAttachmentService.isImageFile('photo.png'), true);
      expect(FileAttachmentService.isImageFile('photo.jpg'), true);
      expect(FileAttachmentService.isImageFile('photo.jpeg'), true);
      expect(FileAttachmentService.isImageFile('photo.gif'), true);
      expect(FileAttachmentService.isImageFile('photo.webp'), true);
      expect(FileAttachmentService.isImageFile('photo.bmp'), true);
    });

    test('isImageFile returns false for non-image extensions', () {
      expect(FileAttachmentService.isImageFile('document.pdf'), false);
      expect(FileAttachmentService.isImageFile('notes.txt'), false);
      expect(FileAttachmentService.isImageFile('file.md'), false);
    });

    test('toMarkdownInsertion creates image markdown for images', () {
      final result = FileAttachmentService.toMarkdownInsertion('/path/to/photo.png', alt: 'my photo');
      expect(result, '![my photo](/path/to/photo.png)');
    });

    test('toMarkdownInsertion creates link markdown for non-images', () {
      final result = FileAttachmentService.toMarkdownInsertion('/path/to/doc.pdf');
      expect(result, '[doc.pdf](/path/to/doc.pdf)');
    });

    test('toMarkdownInsertion uses filename as alt when alt is null for images', () {
      final result = FileAttachmentService.toMarkdownInsertion('/path/to/photo.png');
      expect(result, '![photo.png](/path/to/photo.png)');
    });
  });
}