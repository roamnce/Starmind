import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/ink_layer.dart';
import 'package:starmind/src/mindmap/ink/ink_layer_controller.dart';

void main() {
  test('InkLayerController records, erases, and moves strokes', () {
    final controller = InkLayerController(idFactory: () => 'fixed-id');

    controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
    controller.appendPoint(const Offset(10, 10));
    controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

    var layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
    expect(layer!.strokes, hasLength(1));

    controller.moveSelection(InkLayerOwnerType.canvas, 'topic-1', const Rect.fromLTWH(-1, -1, 20, 20), const Offset(5, 0));
    layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
    expect(layer!.strokes.single.points.first.x, 5);

    controller.erase(InkLayerOwnerType.canvas, 'topic-1', const Rect.fromLTWH(0, 0, 20, 20));
    layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
    expect(layer!.strokes, isEmpty);
  });

  group('undo/redo', () {
    test('undo reverts last stroke', () {
      final controller = InkLayerController(idFactory: () => 'fixed-id');

      // Draw first stroke
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      var layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(1));

      // Draw second stroke
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(20, 20));
      controller.appendPoint(const Offset(30, 30));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(2));

      // Undo second stroke
      expect(controller.canUndo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);
      expect(controller.undo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);

      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(1));
      expect(layer.strokes.first.points.first.x, 0);
    });

    test('redo restores undone stroke', () {
      final controller = InkLayerController(idFactory: () => 'fixed-id');

      // Draw two strokes
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(20, 20));
      controller.appendPoint(const Offset(30, 30));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      var layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(2));

      // Undo one
      controller.undo(InkLayerOwnerType.canvas, 'topic-1');
      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(1));

      // Redo
      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);
      expect(controller.redo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);

      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(2));
    });

    test('new action clears redo history', () {
      final controller = InkLayerController(idFactory: () => 'fixed-id');

      // Draw first stroke
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      // Draw second stroke
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(20, 20));
      controller.appendPoint(const Offset(30, 30));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      // Undo twice
      controller.undo(InkLayerOwnerType.canvas, 'topic-1');
      controller.undo(InkLayerOwnerType.canvas, 'topic-1');

      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);

      // Draw new stroke - should clear redo history
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(40, 40));
      controller.appendPoint(const Offset(50, 50));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);
    });

    test('undo/redo works independently per owner', () {
      final controller = InkLayerController(idFactory: () => 'fixed-id');

      // Draw two strokes on topic-1
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(20, 20));
      controller.appendPoint(const Offset(30, 30));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      // Draw two strokes on topic-2
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-2', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-2');
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-2', const Offset(20, 20));
      controller.appendPoint(const Offset(30, 30));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-2');

      // Undo topic-1 - should not affect topic-2
      controller.undo(InkLayerOwnerType.canvas, 'topic-1');
      expect(controller.getLayer(InkLayerOwnerType.canvas, 'topic-1')!.strokes, hasLength(1));
      expect(controller.getLayer(InkLayerOwnerType.canvas, 'topic-2')!.strokes, hasLength(2));

      // topic-2 should still have redo available for its own history (if undone)
      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);
    });

    test('history limited to 20 states', () {
      final controller = InkLayerController(idFactory: () => 'fixed-id');

      // Create 21 strokes
      for (var i = 0; i < 21; i++) {
        controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', Offset(i.toDouble(), i.toDouble()));
        controller.appendPoint(Offset(i + 1, i + 1));
        controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');
      }

      var layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(21));

      // Should be able to undo exactly 19 times (one state is lost due to circular buffer)
      var undoCount = 0;
      while (controller.canUndo(InkLayerOwnerType.canvas, 'topic-1')) {
        controller.undo(InkLayerOwnerType.canvas, 'topic-1');
        undoCount++;
      }

      // After 21 strokes with max history of 20, we should have 19 undoable states
      // (first state is overwritten when circular buffer reaches limit)
      expect(undoCount, equals(19));

      // After all undos, should have 2 strokes remaining
      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(2));
    });

    test('canUndo and canRedo return correct values', () {
      final controller = InkLayerController(idFactory: () => 'fixed-id');

      // Initially no undo/redo
      expect(controller.canUndo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);
      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);

      // Draw first stroke
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      // Still can't undo with just one stroke (no previous state)
      expect(controller.canUndo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);
      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);

      // Draw second stroke
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(20, 20));
      controller.appendPoint(const Offset(30, 30));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      // Can undo, cannot redo
      expect(controller.canUndo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);
      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);

      // Undo
      controller.undo(InkLayerOwnerType.canvas, 'topic-1');

      // Cannot undo, can redo
      expect(controller.canUndo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);
      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);

      // Redo
      controller.redo(InkLayerOwnerType.canvas, 'topic-1');

      // Can undo, cannot redo
      expect(controller.canUndo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);
      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);
    });

    test('undo/redo with erase operation', () {
      final controller = InkLayerController(idFactory: () => 'fixed-id');

      // Draw two strokes
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(20, 20));
      controller.appendPoint(const Offset(30, 30));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      var layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(2));

      // Erase both strokes (they both intersect the rect)
      controller.erase(InkLayerOwnerType.canvas, 'topic-1', const Rect.fromLTWH(-1, -1, 100, 100));
      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, isEmpty);

      // Undo erase
      controller.undo(InkLayerOwnerType.canvas, 'topic-1');
      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, hasLength(2));

      // Redo erase
      controller.redo(InkLayerOwnerType.canvas, 'topic-1');
      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes, isEmpty);
    });

    test('undo/redo with moveSelection operation', () {
      final controller = InkLayerController(idFactory: () => 'fixed-id');

      // Draw two strokes
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(20, 20));
      controller.appendPoint(const Offset(30, 30));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');

      var layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes.first.points.first.x, equals(0));

      // Move
      controller.moveSelection(
        InkLayerOwnerType.canvas,
        'topic-1',
        const Rect.fromLTWH(-1, -1, 20, 20),
        const Offset(100, 100),
      );
      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes.first.points.first.x, equals(100));

      // Undo move
      controller.undo(InkLayerOwnerType.canvas, 'topic-1');
      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes.first.points.first.x, equals(0));

      // Redo move
      controller.redo(InkLayerOwnerType.canvas, 'topic-1');
      layer = controller.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(layer!.strokes.first.points.first.x, equals(100));
    });

    test('clearHistory removes all history for owner', () {
      final controller = InkLayerController(idFactory: () => 'fixed-id');

      // Draw multiple strokes
      for (var i = 0; i < 5; i++) {
        controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', Offset(i.toDouble(), i.toDouble()));
        controller.appendPoint(Offset(i + 1, i + 1));
        controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');
      }

      expect(controller.canUndo(InkLayerOwnerType.canvas, 'topic-1'), isTrue);

      // Clear history
      controller.clearHistory(InkLayerOwnerType.canvas, 'topic-1');

      expect(controller.canUndo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);
      expect(controller.canRedo(InkLayerOwnerType.canvas, 'topic-1'), isFalse);
    });
  });
}
