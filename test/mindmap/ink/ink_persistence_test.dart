import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/ink_layer.dart';
import 'package:starmind/src/mindmap/ink/ink_layer_controller.dart';
import 'package:starmind/src/mindmap/ink/ink_layer_repository.dart';
import 'package:starmind/src/mindmap/ink/ink_persistence.dart';

void main() {
  group('InkLayerPersistence', () {
    test('endStroke triggers repository.saveInkLayer with current layer', () async {
      final repo = InMemoryInkLayerRepository();
      final controller = InkLayerController();
      final persistence = InkLayerPersistence(repository: repo, controller: controller);

      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      final stroke = controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');
      await persistence.onStrokeEnded(InkLayerOwnerType.canvas, 'topic-1');

      final saved = await repo.loadInkLayer('topic-1', InkLayerOwnerType.canvas);
      expect(saved, isNotNull);
      expect(saved!.strokes.length, 1);
      expect(stroke, isNotNull);
    });

    test('hydrate loads existing layer into controller', () async {
      final repo = InMemoryInkLayerRepository();
      final now = DateTime.now();
      await repo.saveInkLayer(InkLayer(
        id: 'l1', ownerType: InkLayerOwnerType.canvas, ownerId: 'topic-1',
        strokes: const [], createdAt: now, updatedAt: now,
      ));
      final controller = InkLayerController();
      final persistence = InkLayerPersistence(repository: repo, controller: controller);

      await persistence.hydrate(InkLayerOwnerType.canvas, 'topic-1');
      expect(controller.getLayer(InkLayerOwnerType.canvas, 'topic-1'), isNotNull);
    });

    test('hydrate does nothing when layer does not exist', () async {
      final repo = InMemoryInkLayerRepository();
      final controller = InkLayerController();
      final persistence = InkLayerPersistence(repository: repo, controller: controller);

      await persistence.hydrate(InkLayerOwnerType.canvas, 'topic-nonexistent');
      expect(controller.getLayer(InkLayerOwnerType.canvas, 'topic-nonexistent'), isNull);
    });

    test('onStrokeEnded does nothing when layer does not exist', () async {
      final repo = InMemoryInkLayerRepository();
      final controller = InkLayerController();
      final persistence = InkLayerPersistence(repository: repo, controller: controller);

      // Should not throw
      await persistence.onStrokeEnded(InkLayerOwnerType.canvas, 'topic-nonexistent');
    });

    test('round-trip: draw, save, clear, reload', () async {
      final repo = InMemoryInkLayerRepository();
      final controller = InkLayerController();
      final persistence = InkLayerPersistence(repository: repo, controller: controller);

      // Draw a stroke
      controller.beginStroke(InkLayerOwnerType.canvas, 'topic-1', const Offset(0, 0));
      controller.appendPoint(const Offset(10, 10));
      controller.appendPoint(const Offset(20, 20));
      controller.endStroke(InkLayerOwnerType.canvas, 'topic-1');
      await persistence.onStrokeEnded(InkLayerOwnerType.canvas, 'topic-1');

      // Verify saved
      var saved = await repo.loadInkLayer('topic-1', InkLayerOwnerType.canvas);
      expect(saved, isNotNull);
      expect(saved!.strokes.length, 1);

      // Clear controller and reload
      final newController = InkLayerController();
      final newPersistence = InkLayerPersistence(repository: repo, controller: newController);
      await newPersistence.hydrate(InkLayerOwnerType.canvas, 'topic-1');

      // Verify reloaded
      final reloadedLayer = newController.getLayer(InkLayerOwnerType.canvas, 'topic-1');
      expect(reloadedLayer, isNotNull);
      expect(reloadedLayer!.strokes.length, 1);
    });
  });
}
