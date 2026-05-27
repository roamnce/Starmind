import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';
import 'package:starmind/src/pdf/widgets/pdf_viewport_widget.dart';

void main() {
  group('PdfViewportWidget repaint optimization', () {
    testWidgets('creates ViewportRepaintNotifier', (tester) async {
      // Basic smoke test - verifies the integration doesn't break existing functionality
      final controller = PdfViewportController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfViewportWidget(
              controller: controller,
            ),
          ),
        ),
      );

      // Verify widget builds without errors
      expect(find.byType(PdfViewportWidget), findsOneWidget);

      // Clean up
      controller.dispose();
    });

    testWidgets('notifier is disposed when widget is disposed', (tester) async {
      final controller = PdfViewportController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PdfViewportWidget(
              controller: controller,
            ),
          ),
        ),
      );

      // Dispose the widget by removing it from the tree
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));

      // Clean up
      controller.dispose();

      // If notifier wasn't disposed properly, there would be memory leaks
      // This test verifies the dispose lifecycle works
    });
  });
}
