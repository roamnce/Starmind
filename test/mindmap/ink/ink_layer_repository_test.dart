import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/ink_layer.dart';
import 'package:starmind/src/mindmap/ink/ink_layer_repository.dart';

void main() {
  InkLayer sampleLayer() {
    final now = DateTime.utc(2026, 6, 3);
    return InkLayer(
      id: 'ink-1',
      ownerType: InkLayerOwnerType.node,
      ownerId: '1-note',
      createdAt: now,
      updatedAt: now,
      strokes: [
        InkStroke(
          id: 'stroke-1',
          tool: InkTool.pen,
          color: 0xFFFFAA00,
          width: 2,
          points: const [InkPoint(1, 2), InkPoint(3, 4)],
          createdAt: now,
        ),
      ],
    );
  }

  test('InMemoryInkLayerRepository saves and loads ink layers', () async {
    final repository = InMemoryInkLayerRepository();
    final layer = sampleLayer();

    await repository.saveInkLayer(layer);
    final loaded = await repository.loadInkLayer(layer.ownerId, layer.ownerType);

    expect(loaded, isNotNull);
    expect(loaded!.strokes.single.points.last.x, 3);
  });

  test('JsonFileInkLayerRepository persists ink layers as JSON', () async {
    final directory = await Directory.systemTemp.createTemp('starmind_ink_repo_');
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    final repository = JsonFileInkLayerRepository(directory.path);
    final layer = sampleLayer();

    await repository.saveInkLayer(layer);
    final loaded = await repository.loadInkLayer(layer.ownerId, layer.ownerType);

    expect(loaded, isNotNull);
    expect(loaded!.id, layer.id);
    expect(loaded.strokes.single.tool, InkTool.pen);
  });
}
