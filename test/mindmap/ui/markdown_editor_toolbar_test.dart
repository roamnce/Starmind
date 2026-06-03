// test/mindmap/ui/markdown_editor_toolbar_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/markdown_editor_toolbar.dart';

void main() {
  group('MarkdownEditorToolbar Tests', () {
    late TextEditingController controller;
    late FocusNode focusNode;

    setUp(() {
      controller = TextEditingController();
      focusNode = FocusNode();
    });

    tearDown(() {
      controller.dispose();
      focusNode.dispose();
    });

    testWidgets('renders all major Markdown shortcut buttons', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MarkdownEditorToolbar(
            textController: controller,
            focusNode: focusNode,
          ),
        ),
      ));

      // Verify that H, B, I, S label buttons exist
      expect(find.text('H'), findsOneWidget);
      expect(find.text('B'), findsOneWidget);
      expect(find.text('I'), findsOneWidget);
      expect(find.text('S'), findsOneWidget);

      // Verify some icons exist
      expect(find.byIcon(Icons.link_rounded), findsOneWidget);
      expect(find.byIcon(Icons.format_list_bulleted_rounded), findsOneWidget);
      expect(find.byIcon(Icons.format_list_numbered_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
    });

    testWidgets('Heading button inserts prefix ### at cursor', (WidgetTester tester) async {
      controller.text = 'Hello World';
      controller.selection = const TextSelection.collapsed(offset: 6); // Just after "Hello "

      // We need to focus the node in the test environment to check hasFocus later
      focusNode.requestFocus();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: TextField(
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      ));

      // Build toolbar in separate overlay or hierarchy to simulate actual use
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MarkdownEditorToolbar(
                textController: controller,
                focusNode: focusNode,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                ),
              ),
            ],
          ),
        ),
      ));

      final headingButton = find.text('H');
      await tester.tap(headingButton);
      await tester.pumpAndSettle();

      expect(controller.text, equals('Hello ### World'));
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, equals(10)); // 'Hello ' (6) + '### ' (4) = 10
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('Bold button wraps selected text in double asterisks', (WidgetTester tester) async {
      controller.text = 'Hello World';
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11); // "World"

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MarkdownEditorToolbar(
                textController: controller,
                focusNode: focusNode,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                ),
              ),
            ],
          ),
        ),
      ));

      final boldButton = find.text('B');
      await tester.tap(boldButton);
      await tester.pumpAndSettle();

      expect(controller.text, equals('Hello **World**'));
      expect(controller.selection.baseOffset, equals(8)); // start of "World" inside **World**
      expect(controller.selection.extentOffset, equals(13)); // end of "World" inside **World**
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('Strikethrough button wraps selected text in double tildes', (WidgetTester tester) async {
      controller.text = 'Hello World';
      controller.selection = const TextSelection(baseOffset: 6, extentOffset: 11); // "World"

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MarkdownEditorToolbar(
                textController: controller,
                focusNode: focusNode,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                ),
              ),
            ],
          ),
        ),
      ));

      final strikeButton = find.text('S');
      await tester.tap(strikeButton);
      await tester.pumpAndSettle();

      expect(controller.text, equals('Hello ~~World~~'));
      expect(controller.selection.baseOffset, equals(8));
      expect(controller.selection.extentOffset, equals(13));
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('Link button wraps selected text as []() with correct selection', (WidgetTester tester) async {
      controller.text = 'Google';
      controller.selection = const TextSelection(baseOffset: 0, extentOffset: 6);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MarkdownEditorToolbar(
                textController: controller,
                focusNode: focusNode,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                ),
              ),
            ],
          ),
        ),
      ));

      final linkButton = find.byIcon(Icons.link_rounded);
      await tester.tap(linkButton);
      await tester.pumpAndSettle();

      expect(controller.text, equals('[Google]()'));
      expect(controller.selection.baseOffset, equals(1));
      expect(controller.selection.extentOffset, equals(7));
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('Task List button inserts task list checkbox template', (WidgetTester tester) async {
      controller.text = 'Write code';
      controller.selection = const TextSelection.collapsed(offset: 0);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              MarkdownEditorToolbar(
                textController: controller,
                focusNode: focusNode,
              ),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                ),
              ),
            ],
          ),
        ),
      ));

      final taskButton = find.byIcon(Icons.check_box_outlined);
      await tester.tap(taskButton);
      await tester.pumpAndSettle();

      expect(controller.text, equals('\n- [ ] Write code'));
      expect(controller.selection.isCollapsed, isTrue);
      expect(controller.selection.baseOffset, equals(7)); // After '\n- [ ] '
      expect(focusNode.hasFocus, isTrue);
    });
  });
}
