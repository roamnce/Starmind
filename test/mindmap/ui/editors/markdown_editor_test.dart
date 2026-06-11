import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:starmind/src/mindmap/ui/editors/markdown_editor.dart';

void main() {
  group('MarkdownEditor', () {
    testWidgets('renders initial text in TextField and preview',
        (tester) async {
      const initialText = '# Title\n\nParagraph text';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: initialText,
            ),
          ),
        ),
      );

      // Find TextField and verify initial text
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);

      final textField = tester.widget<TextField>(textFieldFinder);
      expect(textField.controller?.text, equals(initialText));

      // Verify Markdown preview is rendered
      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('onTextChanged is called when text changes', (tester) async {
      String? changedText;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: '',
              onTextChanged: (text) {
                changedText = text;
              },
            ),
          ),
        ),
      );

      // Enter text in TextField
      await tester.enterText(find.byType(TextField), 'New text');
      await tester.pump();

      expect(changedText, equals('New text'));
    });

    testWidgets('bold button wraps selected text with **', (tester) async {
      final controller = TextEditingController(text: 'Hello World');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: 'Hello World',
              controller: controller,
            ),
          ),
        ),
      );

      // Select 'World'
      final textFieldFinder = find.byType(TextField);
      await tester.tap(textFieldFinder);
      await tester.pump();

      // Simulate selection
      controller.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );
      await tester.pump();

      // Find and tap bold button (B icon)
      final boldButtonFinder = find.byIcon(Icons.format_bold);
      expect(boldButtonFinder, findsOneWidget);
      await tester.tap(boldButtonFinder);
      await tester.pump();

      expect(controller.text, equals('Hello **World**'));
    });

    testWidgets('italic button wraps selected text with *', (tester) async {
      final controller = TextEditingController(text: 'Hello World');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: 'Hello World',
              controller: controller,
            ),
          ),
        ),
      );

      // Select 'World'
      controller.selection = const TextSelection(
        baseOffset: 6,
        extentOffset: 11,
      );
      await tester.pump();

      // Tap italic button
      await tester.tap(find.byIcon(Icons.format_italic));
      await tester.pump();

      expect(controller.text, equals('Hello *World*'));
    });

    testWidgets('H1 button inserts heading format', (tester) async {
      final controller = TextEditingController(text: 'Title');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: 'Title',
              controller: controller,
            ),
          ),
        ),
      );

      // Tap H1 button
      await tester.tap(find.text('H1'));
      await tester.pump();

      expect(controller.text, equals('# Title'));
    });

    testWidgets('list button inserts list format', (tester) async {
      final controller = TextEditingController(text: 'Item');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: 'Item',
              controller: controller,
            ),
          ),
        ),
      );

      // Tap list button
      await tester.tap(find.byIcon(Icons.format_list_bulleted));
      await tester.pump();

      expect(controller.text, equals('- Item'));
    });

    testWidgets('code button inserts code block format', (tester) async {
      final controller = TextEditingController(text: 'print("hello")');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: 'print("hello")',
              controller: controller,
            ),
          ),
        ),
      );

      // Select all text
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 14,
      );
      await tester.pump();

      // Tap code button
      await tester.tap(find.byIcon(Icons.code));
      await tester.pump();

      expect(controller.text, equals('```\nprint("hello")\n```'));
    });

    testWidgets('link button inserts link format', (tester) async {
      final controller = TextEditingController(text: 'Example');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: 'Example',
              controller: controller,
            ),
          ),
        ),
      );

      // Select text
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 7,
      );
      await tester.pump();

      // Tap link button
      await tester.tap(find.byIcon(Icons.link));
      await tester.pump();

      expect(controller.text, equals('[Example](url)'));
    });

    testWidgets('image button triggers onImagePicked callback', (tester) async {
      bool imagePicked = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: '',
              onImagePicked: () {
                imagePicked = true;
              },
            ),
          ),
        ),
      );

      // Tap image button
      await tester.tap(find.byIcon(Icons.image));
      await tester.pump();

      expect(imagePicked, isTrue);
    });

    testWidgets('H2 and H3 buttons work correctly', (tester) async {
      final controller = TextEditingController(text: 'Title');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: 'Title',
              controller: controller,
            ),
          ),
        ),
      );

      // Tap H2 button
      await tester.tap(find.text('H2'));
      await tester.pump();
      expect(controller.text, equals('## Title'));

      // Reset and test H3
      controller.text = 'Title';
      await tester.tap(find.text('H3'));
      await tester.pump();
      expect(controller.text, equals('### Title'));
    });

    testWidgets('toolbar displays all buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownEditor(
              initialText: '',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.format_bold), findsOneWidget);
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
      expect(find.text('H1'), findsOneWidget);
      expect(find.text('H2'), findsOneWidget);
      expect(find.text('H3'), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
      expect(find.byIcon(Icons.code), findsOneWidget);
      expect(find.byIcon(Icons.link), findsOneWidget);
      expect(find.byIcon(Icons.image), findsOneWidget);
    });
  });
}
