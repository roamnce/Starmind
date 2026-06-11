// test/mindmap/ui/editors/node_ink_editor_test.dart
//
// NodeInkEditor 测试：
// - 非墨迹模式下点击空白处应穿透到下层 TextField
// - 墨迹模式下点击同一位置应画出墨迹而非穿透

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:starmind/src/mindmap/ink/ink_layer.dart';
import 'package:starmind/src/mindmap/ink/ink_layer_controller.dart';
import 'package:starmind/src/mindmap/ui/editors/node_ink_editor.dart';

void main() {
  group('NodeInkEditor', () {
    testWidgets('passthrough: non-ink mode allows clicks to reach TextField', (tester) async {
      final inkController = InkLayerController();
      final textController = TextEditingController();
      final focusNode = FocusNode();
      const noteId = 'test-note-1';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: NodeInkEditor(
                noteId: noteId,
                inkController: inkController,
                isInkActive: false,
                markdownWidget: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(hintText: 'Enter markdown'),
                ),
              ),
            ),
          ),
        ),
      );

      // 找到 TextField 并验证初始状态
      final textFieldFinder = find.byType(TextField);
      expect(textFieldFinder, findsOneWidget);
      expect(textController.text, isEmpty);
      expect(focusNode.hasFocus, isFalse);

      // 点击 TextField 区域
      // NodeInkEditor 应允许事件穿透，TextField 获得焦点
      await tester.tap(textFieldFinder);
      await tester.pump();

      // TextField 应获得焦点
      expect(focusNode.hasFocus, isTrue);
    });

    testWidgets('ink mode: click draws stroke instead of passthrough', (tester) async {
      final inkController = InkLayerController();
      final textController = TextEditingController();
      final focusNode = FocusNode();
      const noteId = 'test-note-2';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: NodeInkEditor(
                noteId: noteId,
                inkController: inkController,
                isInkActive: true,
                markdownWidget: TextField(
                  controller: textController,
                  focusNode: focusNode,
                  decoration: const InputDecoration(hintText: 'Enter markdown'),
                ),
              ),
            ),
          ),
        ),
      );

      // 验证初始状态：无笔画
      final layer = inkController.getLayer(InkLayerOwnerType.node, noteId);
      expect(layer?.strokes ?? [], isEmpty);
      expect(inkController.currentStroke, isNull);

      // 模拟触摸开始
      final gesture = await tester.startGesture(const Offset(200, 200));
      await tester.pump();

      // 验证开始笔画
      expect(inkController.currentStroke, isNotNull);
      expect(inkController.currentStroke?.points.length, 1);

      // 移动并结束
      await gesture.moveBy(const Offset(50, 50));
      await tester.pump();
      await gesture.moveBy(const Offset(50, 50));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // 验证笔画已提交
      expect(inkController.currentStroke, isNull);
      final updatedLayer = inkController.getLayer(InkLayerOwnerType.node, noteId);
      expect(updatedLayer?.strokes.length ?? 0, 1);
      expect(updatedLayer?.strokes.first.points.length ?? 0, greaterThan(1));

      // TextField 未获得焦点
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('toggling isInkActive switches passthrough behavior', (tester) async {
      final inkController = InkLayerController();
      final textController = TextEditingController();
      final focusNode = FocusNode();
      const noteId = 'test-note-3';

      // Stateful wrapper to toggle isInkActive
      await tester.pumpWidget(
        _ToggleableInkEditor(
          noteId: noteId,
          inkController: inkController,
          textController: textController,
          focusNode: focusNode,
        ),
      );

      // 初始状态：墨迹模式关闭
      expect(find.byType(NodeInkEditor), findsOneWidget);

      // 点击应穿透到 TextField
      await tester.tap(find.byType(TextField));
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      // 切换到墨迹模式
      final state = tester.state<_ToggleableInkEditorState>(find.byType(_ToggleableInkEditor));
      state.toggle();
      await tester.pump();

      // 点击应画墨迹
      final gesture = await tester.startGesture(const Offset(100, 100));
      await tester.pump();
      await gesture.moveBy(const Offset(50, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final layer = inkController.getLayer(InkLayerOwnerType.node, noteId);
      expect(layer?.strokes.length ?? 0, 1);
    });

    testWidgets('renders strokes via CanvasInkPainter', (tester) async {
      final inkController = InkLayerController();
      const noteId = 'test-note-4';

      // 预加载一个笔画
      inkController.ensureLayer(InkLayerOwnerType.node, noteId);
      inkController.beginStroke(InkLayerOwnerType.node, noteId, const Offset(50, 50));
      inkController.appendPoint(const Offset(100, 100));
      inkController.endStroke(InkLayerOwnerType.node, noteId);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 400,
              child: NodeInkEditor(
                noteId: noteId,
                inkController: inkController,
                isInkActive: true,
                markdownWidget: const Text('Markdown content'),
              ),
            ),
          ),
        ),
      );

      // 验证 CustomPaint 存在（由 CanvasInkLayer 内部提供）
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });
}

/// Stateful wrapper to toggle isInkActive during test
class _ToggleableInkEditor extends StatefulWidget {
  final String noteId;
  final InkLayerController inkController;
  final TextEditingController textController;
  final FocusNode focusNode;

  const _ToggleableInkEditor({
    required this.noteId,
    required this.inkController,
    required this.textController,
    required this.focusNode,
  });

  @override
  State<_ToggleableInkEditor> createState() => _ToggleableInkEditorState();
}

class _ToggleableInkEditorState extends State<_ToggleableInkEditor> {
  bool _isInkActive = false;

  void toggle() {
    setState(() {
      _isInkActive = !_isInkActive;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 400,
          child: NodeInkEditor(
            noteId: widget.noteId,
            inkController: widget.inkController,
            isInkActive: _isInkActive,
            markdownWidget: TextField(
              controller: widget.textController,
              focusNode: widget.focusNode,
              decoration: const InputDecoration(hintText: 'Enter markdown'),
            ),
          ),
        ),
      ),
    );
  }
}