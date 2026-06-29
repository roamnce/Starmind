import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:starmind/src/mindmap/ui/cards/live_preview/rendering/image_renderer.dart';

void main() {
  group('ImageRenderer', () {
    testWidgets('renders error widget for invalid path', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ImageRenderer(
            imagePath: '/nonexistent/image.png',
            maxWidth: 300,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('[图片加载失败]'), findsOneWidget);
    });

    testWidgets('renders Image.file for valid path', (tester) async {
      // Create a temporary file that actually exists.
      final tmpDir = Directory.systemTemp;
      final tmpFile = File('${tmpDir.path}/test_image.png');
      tmpFile.writeAsStringSync('fake png content');

      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ImageRenderer(
              imagePath: tmpFile.path,
              maxWidth: 300,
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(Image), findsOneWidget);
      } finally {
        tmpFile.deleteSync();
      }
    });
  });
}
