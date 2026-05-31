// test/mindmap/ui/radar_painter_test.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/navigation_radar.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/ui/tree_layout.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';

void main() {
  group('NavigationRadar & Painters Test Suite', () {
    late InMemoryMindMapRepository repo;
    late MindMapService service;
    late MindMapController controller;

    setUp(() {
      repo = InMemoryMindMapRepository();
      service = MindMapService(repo);
      controller = MindMapController(service);
    });

    tearDown(() {
      controller.dispose();
    });

    test('Radar Scale Calculation & Bounds Fitting Math', () {
      const radarW = 200.0;
      const radarH = 150.0;

      // Case 1: normal bounds
      var contentBounds = const Rect.fromLTWH(100, 200, 1000, 500);
      var scaleX = (radarW - 16) / contentBounds.width; // 184 / 1000 = 0.184
      var scaleY = (radarH - 16) / contentBounds.height; // 134 / 500 = 0.268
      var expectedRadarScale = min(scaleX, scaleY).clamp(0.001, 10.0);
      expect(expectedRadarScale, closeTo(0.184, 0.0001));

      // Case 2: zero/negative bounds width/height handled gracefully
      contentBounds = const Rect.fromLTWH(0, 0, 0, 0);
      var boundsW = contentBounds.width <= 0 ? 1.0 : contentBounds.width;
      var boundsH = contentBounds.height <= 0 ? 1.0 : contentBounds.height;
      scaleX = (radarW - 16) / boundsW;
      scaleY = (radarH - 16) / boundsH;
      var safeRadarScale = min(scaleX, scaleY).clamp(0.001, 10.0);
      expect(safeRadarScale, equals(10.0)); // Clamped to maxScale = 10.0
    });

    test('Node Mini-Positions and Viewport Projection Math', () {
      const radarW = 200.0;
      const radarH = 150.0;
      final contentBounds = const Rect.fromLTWH(0, 0, 1000, 500);
      final visibleRect = const Rect.fromLTWH(200, 100, 400, 300);

      final scaleX = (radarW - 16) / contentBounds.width; // 184 / 1000 = 0.184
      final scaleY = (radarH - 16) / contentBounds.height; // 134 / 500 = 0.268
      final radarScale = min(scaleX, scaleY).clamp(0.001, 10.0); // 0.184

      // Project node at (500, 250)
      final nodePos = const Offset(500, 250);
      final projectedNodeX = (nodePos.dx - contentBounds.left) * radarScale + 8;
      final projectedNodeY = (nodePos.dy - contentBounds.top) * radarScale + 8;

      expect(projectedNodeX, closeTo(100.0, 0.01)); // (500 - 0)*0.184 + 8 = 100
      expect(projectedNodeY, closeTo(54.0, 0.01));  // (250 - 0)*0.184 + 8 = 54

      // Project viewport rect
      final viewLeft = (visibleRect.left - contentBounds.left) * radarScale + 8;
      final viewTop = (visibleRect.top - contentBounds.top) * radarScale + 8;
      final viewW = visibleRect.width * radarScale;
      final viewH = visibleRect.height * radarScale;

      expect(viewLeft, closeTo(44.8, 0.01));  // (200 - 0)*0.184 + 8 = 44.8
      expect(viewTop, closeTo(26.4, 0.01));   // (100 - 0)*0.184 + 8 = 26.4
      expect(viewW, closeTo(73.6, 0.01));     // 400 * 0.184 = 73.6
      expect(viewH, closeTo(55.2, 0.01));     // 300 * 0.184 = 55.2
    });

    test('Bi-directional Delta Conversion Math', () {
      const radarScale = 0.2;
      final deltaRadar = const Offset(10, -5);

      // Translate drag details delta into canvas translation delta
      final deltaCanvas = Offset(deltaRadar.dx / radarScale, deltaRadar.dy / radarScale);

      expect(deltaCanvas.dx, equals(50.0));  // 10 / 0.2 = 50
      expect(deltaCanvas.dy, equals(-25.0)); // -5 / 0.2 = -25
    });

    testWidgets('NavigationRadar renders successfully without runtime errors', (tester) async {
      final contentBounds = const Rect.fromLTWH(0, 0, 800, 600);
      final visibleRect = const Rect.fromLTWH(100, 100, 300, 200);
      final nodePositions = {
        'node1': const Offset(200, 150),
        'node2': const Offset(500, 450),
      };
      final connections = [
        const Connection(
          fromId: 'node1',
          toId: 'node2',
          start: Offset(200, 150),
          end: Offset(500, 450),
        ),
      ];

      Offset? pannedDelta;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NavigationRadar(
              controller: controller,
              visibleRect: visibleRect,
              contentBounds: contentBounds,
              nodePositions: nodePositions,
              connections: connections,
              onPanCanvas: (delta) {
                pannedDelta = delta;
              },
            ),
          ),
        ),
      );

      // Verify that all components rendered
      expect(find.byType(NavigationRadar), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NavigationRadar),
          matching: find.byType(CustomPaint),
        ),
        findsNWidgets(2),
      ); // Content painter + viewport painter

      // Drag the radar widget and verify panning delta conversion works
      final gesture = await tester.startGesture(const Offset(50, 50));
      await gesture.moveBy(const Offset(10, 20));
      await gesture.up();
      await tester.pump();

      expect(pannedDelta, isNotNull);
      // Ensure delta canvas has correct sign and values (divided by radar scale)
      expect(pannedDelta!.dx, isPositive);
      expect(pannedDelta!.dy, isPositive);
    });
  });
}
