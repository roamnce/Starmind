import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:starmind/src/mindmap/ui/cards/live_preview/rendering/code_block_renderer.dart';

void main() {
  group('CodeBlockRenderer', () {
    testWidgets('renders code with monospace font', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodeBlockRenderer(
            code: 'void main() { print("hello"); }',
            language: 'dart',
            maxWidth: 400,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CodeBlockRenderer), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('renders language label when present', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodeBlockRenderer(
            code: 'console.log("hi");',
            language: 'javascript',
            maxWidth: 400,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('javascript'), findsOneWidget);
    });

    testWidgets('renders code even when language is empty', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CodeBlockRenderer(
            code: 'some code',
            language: '',
            maxWidth: 400,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CodeBlockRenderer), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
