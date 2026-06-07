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
}
