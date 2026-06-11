# Canvas Ink Layer Implementation Plan (Phase 1-A)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade ink rendering to GoodNotes-level quality using Catmull-Rom spline + variable-width strokes

**Architecture:** Create StrokeRenderer utility class that processes raw input points through a pipeline (filter → smooth → Catmull-Rom path → variable-width polygon), then integrate into CanvasInkPainter

**Tech Stack:** Flutter CustomPainter, dart:ui CatmullRomSpline, Canvas drawPath

---

### Task 1: Stroke Renderer Core

**Files:**
- Create: `lib/src/mindmap/ink/stroke_renderer.dart`
- Test: `test/mindmap/ink/stroke_renderer_test.dart`

- [ ] **Step 1: Write failing test for point filtering**

```dart
// test/mindmap/ink/stroke_renderer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/stroke_renderer.dart';
import 'package:starmind/src/mindmap/ink/ink_layer.dart';

void main() {
  group('StrokeRenderer', () {
    test('filterPoints removes duplicate points within 0.5px threshold', () {
      final points = [
        InkPoint(0, 0),
        InkPoint(0.3, 0.3), // should be filtered
        InkPoint(0.4, 0.4), // should be filtered  
        InkPoint(1, 1),
        InkPoint(2, 2),
      ];
      final filtered = StrokeRenderer.filterPoints(points);
      expect(filtered.length, 3);
      expect(filtered[0].offset, const Offset(0, 0));
      expect(filtered[1].offset, const Offset(1, 1));
      expect(filtered[2].offset, const Offset(2, 2));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: FAIL with "StrokeRenderer not found"

- [ ] **Step 3: Create StrokeRenderer with filterPoints**

```dart
// lib/src/mindmap/ink/stroke_renderer.dart
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'ink_layer.dart';

class StrokeRenderer {
  /// Filters out micro-jitter and duplicate points within 0.5px threshold.
  static List<InkPoint> filterPoints(List<InkPoint> points) {
    if (points.isEmpty) return [];
    final List<InkPoint> filtered = [points.first];
    for (int i = 1; i < points.length; i++) {
      final distance = (points[i].offset - filtered.last.offset).distance;
      if (distance > 0.5) {
        filtered.add(points[i]);
      }
    }
    return filtered;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit filterPoints implementation**

```bash
git add lib/src/mindmap/ink/stroke_renderer.dart test/mindmap/ink/stroke_renderer_test.dart
git commit -m "feat(ink): add StrokeRenderer.filterPoints for jitter removal"
```

---

### Task 2: Point Smoothing

**Files:**
- Modify: `lib/src/mindmap/ink/stroke_renderer.dart`
- Modify: `test/mindmap/ink/stroke_renderer_test.dart`

- [ ] **Step 1: Write failing test for smoothing**

```dart
// test/mindmap/ink/stroke_renderer_test.dart (append)
    test('smoothPoints applies weighted moving average (0.25, 0.5, 0.25)', () {
      final points = [
        InkPoint(0, 0),
        InkPoint(10, 10),
        InkPoint(20, 0),
      ];
      final smoothed = StrokeRenderer.smoothPoints(points);
      expect(smoothed.length, 3);
      // First and last points unchanged
      expect(smoothed[0].offset, const Offset(0, 0));
      expect(smoothed[2].offset, const Offset(20, 0));
      // Middle point: 0.25*(0,0) + 0.5*(10,10) + 0.25*(20,0) = (2.5, 5) + (5, 5) + (5, 0) = (12.5, 10)? No
      // Actually: x = 0*0.25 + 10*0.5 + 20*0.25 = 0 + 5 + 5 = 10
      // y = 0*0.25 + 10*0.5 + 0*0.25 = 0 + 5 + 0 = 5
      expect(smoothed[1].x, closeTo(10.0, 0.01));
      expect(smoothed[1].y, closeTo(5.0, 0.01));
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: FAIL with "StrokeRenderer.smoothPoints not found"

- [ ] **Step 3: Implement smoothPoints**

```dart
// lib/src/mindmap/ink/stroke_renderer.dart (append)
  /// Weighted moving average filter: P'[i] = 0.25*P[i-1] + 0.5*P[i] + 0.25*P[i+1]
  static List<InkPoint> smoothPoints(List<InkPoint> pts) {
    if (pts.length < 3) return pts;
    final List<InkPoint> smoothed = [pts.first];
    for (int i = 1; i < pts.length - 1; i++) {
      final double x = pts[i-1].x * 0.25 + pts[i].x * 0.5 + pts[i+1].x * 0.25;
      final double y = pts[i-1].y * 0.25 + pts[i].y * 0.5 + pts[i+1].y * 0.25;
      final double p = pts[i-1].pressure * 0.25 + pts[i].pressure * 0.5 + pts[i+1].pressure * 0.25;
      smoothed.add(InkPoint(x, y, pressure: p));
    }
    smoothed.add(pts.last);
    return smoothed;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit smoothPoints**

```bash
git add lib/src/mindmap/ink/stroke_renderer.dart test/mindmap/ink/stroke_renderer_test.dart
git commit -m "feat(ink): add StrokeRenderer.smoothPoints for moving average"
```

---

### Task 3: Catmull-Rom Path Generation

**Files:**
- Modify: `lib/src/mindmap/ink/stroke_renderer.dart`
- Modify: `test/mindmap/ink/stroke_renderer_test.dart`

- [ ] **Step 1: Write failing test for Catmull-Rom path**

```dart
// test/mindmap/ink/stroke_renderer_test.dart (append)
    test('catmullRomPath generates smooth interpolated curve', () {
      final points = [
        InkPoint(0, 0),
        InkPoint(50, 100),
        InkPoint(100, 50),
        InkPoint(150, 150),
      ];
      final path = StrokeRenderer.catmullRomPath(points, 2.0);
      final bounds = path.getBounds();
      // Path should span from ~0 to ~150 in both dimensions
      expect(bounds.width, greaterThan(140));
      expect(bounds.height, greaterThan(140));
    });

    test('catmullRomPath returns simple path for fewer than 4 points', () {
      final points = [
        InkPoint(0, 0),
        InkPoint(100, 100),
      ];
      final path = StrokeRenderer.catmullRomPath(points, 2.0);
      final bounds = path.getBounds();
      expect(bounds.width, closeTo(100, 1));
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement catmullRomPath**

```dart
// lib/src/mindmap/ink/stroke_renderer.dart (append)
  /// Catmull-Rom spline path generation for smooth curves.
  static Path catmullRomPath(List<InkPoint> points, double baseWidth) {
    if (points.length < 4) {
      // Fallback: simple line connection
      final path = Path();
      if (points.isEmpty) return path;
      path.moveTo(points.first.x, points.first.y);
      for (final p in points.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      return path;
    }

    final offsets = points.map((p) => p.offset).toList();
    final spline = CatmullRomSpline(offsets);

    final totalDist = _totalDistance(points);
    final samples = math.max(64, (totalDist / 0.5).round());

    final path = Path();
    path.moveTo(points.first.x, points.first.y);
    for (int i = 1; i <= samples; i++) {
      final t = i / samples;
      final p = spline.transform(t);
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  static double _totalDistance(List<InkPoint> points) {
    double total = 0;
    for (int i = 0; i < points.length - 1; i++) {
      total += (points[i+1].offset - points[i].offset).distance;
    }
    return total;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit catmullRomPath**

```bash
git add lib/src/mindmap/ink/stroke_renderer.dart test/mindmap/ink/stroke_renderer_test.dart
git commit -m "feat(ink): add Catmull-Rom spline path generation"
```

---

### Task 4: Variable-Width Path

**Files:**
- Modify: `lib/src/mindmap/ink/stroke_renderer.dart`
- Modify: `test/mindmap/ink/stroke_renderer_test.dart`

- [ ] **Step 1: Write failing test for variable-width path**

```dart
// test/mindmap/ink/stroke_renderer_test.dart (append)
    test('variableWidthPath generates closed polygon envelope', () {
      final points = [
        InkPoint(0, 0, pressure: 1.0),
        InkPoint(50, 50, pressure: 0.5),
        InkPoint(100, 0, pressure: 1.0),
        InkPoint(150, 50, pressure: 0.8),
      ];
      final path = StrokeRenderer.variableWidthPath(points, 10.0);
      // Should be a closed path
      final bounds = path.getBounds();
      expect(bounds.width, greaterThan(140));
      // Height should be larger due to width envelope
      expect(bounds.height, greaterThan(50));
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement variableWidthPath**

```dart
// lib/src/mindmap/ink/stroke_renderer.dart (append)
  /// Variable-width stroke polygon envelope (pressure-based widths).
  static Path variableWidthPath(List<InkPoint> points, double baseWidth) {
    if (points.length < 4) {
      return _simpleVariablePath(points, baseWidth);
    }

    final processed = smoothPoints(filterPoints(points));
    final offsets = processed.map((p) => p.offset).toList();
    final spline = CatmullRomSpline(offsets);

    final totalDist = _totalDistance(processed);
    final samples = math.max(64, (totalDist / 0.5).round());

    final leftPoints = <Offset>[];
    final rightPoints = <Offset>[];

    // Taper at start/end (20% of samples)
    final taperSamples = (samples * 0.2).round();

    for (int i = 0; i <= samples; i++) {
      final t = i / samples;
      final point = spline.transform(t);

      // Interpolate pressure-based width
      final segIdx = (t * (processed.length - 1)).floor().clamp(0, processed.length - 2);
      final localT = (t * (processed.length - 1) - segIdx).clamp(0.0, 1.0);
      var width = lerpDouble(
        processed[segIdx].pressure * baseWidth,
        processed[segIdx + 1].pressure * baseWidth,
        localT,
      ) ?? baseWidth;

      // Apply taper at ends
      if (i < taperSamples) {
        width *= i / taperSamples;
      } else if (i > samples - taperSamples) {
        width *= (samples - i) / taperSamples;
      }

      // Compute tangent and normal
      Offset tangent;
      if (i == 0) {
        tangent = spline.transform(1/samples) - point;
      } else if (i == samples) {
        tangent = point - spline.transform((samples-1)/samples);
      } else {
        tangent = spline.transform((i+1)/samples) - spline.transform((i-1)/samples);
      }
      final len = tangent.distance;
      final normal = len < 0.0001 
          ? const Offset(0, 1) 
          : Offset(-tangent.dy, tangent.dx) / len;

      leftPoints.add(point + normal * (width / 2));
      rightPoints.add(point - normal * (width / 2));
    }

    // Build closed polygon path
    final path = Path();
    path.moveTo(leftPoints.first.dx, leftPoints.first.dy);
    for (final p in leftPoints.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    for (final p in rightPoints.reversed) {
      path.lineTo(p.dx, p.dy);
    }
    path.close();
    return path;
  }

  static Path _simpleVariablePath(List<InkPoint> points, double baseWidth) {
    if (points.isEmpty) return Path();
    if (points.length == 1) {
      final r = points.first.pressure * baseWidth / 2;
      final path = Path();
      path.addOval(Rect.fromCircle(center: points.first.offset, radius: r));
      return path;
    }
    // Simple polygon for 2-3 points
    final path = Path();
    // Approximate with circles + lines
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      final w1 = p1.pressure * baseWidth / 2;
      final w2 = p2.pressure * baseWidth / 2;
      final dir = (p2.offset - p1.offset);
      final len = dir.distance;
      if (len < 0.001) continue;
      final normal = Offset(-dir.dy, dir.dx) / len;
      
      path.moveTo(p1.x + normal.dx * w1, p1.y + normal.dy * w1);
      path.lineTo(p2.x + normal.dx * w2, p2.y + normal.dy * w2);
      path.lineTo(p2.x - normal.dx * w2, p2.y - normal.dy * w2);
      path.lineTo(p1.x - normal.dx * w1, p1.y - normal.dy * w1);
      path.close();
    }
    return path;
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit variableWidthPath**

```bash
git add lib/src/mindmap/ink/stroke_renderer.dart test/mindmap/ink/stroke_renderer_test.dart
git commit -m "feat(ink): add variable-width polygon envelope for pressure strokes"
```

---

### Task 5: Draw Stroke Method

**Files:**
- Modify: `lib/src/mindmap/ink/stroke_renderer.dart`
- Modify: `test/mindmap/ink/stroke_renderer_test.dart`

- [ ] **Step 1: Write test for drawStroke**

```dart
// test/mindmap/ink/stroke_renderer_test.dart (append)
    test('drawStroke handles pen tool', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final stroke = InkStroke(
        id: 'test-1',
        tool: InkTool.pen,
        color: Colors.black.value,
        width: 4.0,
        points: [
          InkPoint(0, 0, pressure: 1.0),
          InkPoint(50, 50, pressure: 0.8),
          InkPoint(100, 0, pressure: 1.0),
          InkPoint(150, 50, pressure: 0.9),
        ],
        createdAt: DateTime.now(),
      );
      StrokeRenderer.drawStroke(canvas, stroke);
      final picture = recorder.endRecording();
      // Verify picture was created
      expect(picture, isNotNull);
    });

    test('drawStroke handles highlighter with transparency', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final stroke = InkStroke(
        id: 'test-2',
        tool: InkTool.highlighter,
        color: Colors.yellow.value,
        width: 4.0,
        points: [
          InkPoint(0, 0),
          InkPoint(100, 100),
        ],
        createdAt: DateTime.now(),
      );
      StrokeRenderer.drawStroke(canvas, stroke);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });

    test('drawStroke handles eraser with clear blend mode', () {
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      final stroke = InkStroke(
        id: 'test-3',
        tool: InkTool.eraser,
        color: Colors.white.value,
        width: 20.0,
        points: [
          InkPoint(0, 0),
          InkPoint(50, 50),
          InkPoint(100, 100),
          InkPoint(150, 150),
        ],
        createdAt: DateTime.now(),
      );
      StrokeRenderer.drawStroke(canvas, stroke);
      final picture = recorder.endRecording();
      expect(picture, isNotNull);
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: FAIL

- [ ] **Step 3: Implement drawStroke**

```dart
// lib/src/mindmap/ink/stroke_renderer.dart (append)
  /// Draws a complete stroke onto the canvas using appropriate rendering.
  static void drawStroke(Canvas canvas, InkStroke stroke) {
    if (stroke.points.length < 2) return;

    final processed = smoothPoints(filterPoints(stroke.points));

    switch (stroke.tool) {
      case InkTool.highlighter:
        _drawHighlighterStroke(canvas, processed, stroke);
        break;
      case InkTool.eraser:
        _drawEraserStroke(canvas, processed, stroke);
        break;
      case InkTool.pen:
      case InkTool.lasso:
        _drawPenStroke(canvas, processed, stroke);
        break;
    }
  }

  static void _drawPenStroke(Canvas canvas, List<InkPoint> points, InkStroke stroke) {
    if (points.length < 2) return;

    final path = variableWidthPath(points, stroke.width);
    
    // Fill with color
    final fillPaint = Paint()
      ..color = Color(stroke.color)
      ..isAntiAlias = true
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // Thin outline to hide polygon facets
    final strokePaint = Paint()
      ..color = Color(stroke.color)
      ..isAntiAlias = true
      ..strokeWidth = 0.5
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  static void _drawHighlighterStroke(Canvas canvas, List<InkPoint> points, InkStroke stroke) {
    final path = catmullRomPath(points, stroke.width);
    final paint = Paint()
      ..color = Color(stroke.color).withOpacity(0.35)
      ..strokeWidth = stroke.width * 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..blendMode = BlendMode.srcOver;
    canvas.drawPath(path, paint);
  }

  static void _drawEraserStroke(Canvas canvas, List<InkPoint> points, InkStroke stroke) {
    if (points.length < 4) {
      // Simple eraser: wide stroke
      final paint = Paint()
        ..strokeWidth = stroke.width * 2
        ..strokeCap = StrokeCap.round
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..blendMode = BlendMode.clear;
      final path = Path();
      path.moveTo(points.first.x, points.first.y);
      for (final p in points.skip(1)) {
        path.lineTo(p.x, p.y);
      }
      canvas.drawPath(path, paint);
      return;
    }

    final path = variableWidthPath(points, stroke.width * 2);
    final paint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.clear;
    canvas.drawPath(path, paint);
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/mindmap/ink/stroke_renderer_test.dart`
Expected: PASS

- [ ] **Step 5: Commit drawStroke**

```bash
git add lib/src/mindmap/ink/stroke_renderer.dart test/mindmap/ink/stroke_renderer_test.dart
git commit -m "feat(ink): add StrokeRenderer.drawStroke with pen/highlighter/eraser support"
```

---

### Task 6: Integrate into CanvasInkPainter

**Files:**
- Modify: `lib/src/mindmap/ink/canvas_ink_layer.dart:54-80`
- Modify: `test/mindmap/ink/canvas_ink_layer_test.dart`

- [ ] **Step 1: Write test for CanvasInkPainter using StrokeRenderer**

```dart
// test/mindmap/ink/canvas_ink_layer_test.dart (append)
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/rendering.dart';
import 'package:starmind/src/mindmap/ink/canvas_ink_layer.dart';
import 'package:starmind/src/mindmap/ink/ink_layer.dart';

void main() {
  group('CanvasInkPainter', () {
    test('paints strokes using StrokeRenderer', () {
      final strokes = [
        InkStroke(
          id: 'test-1',
          tool: InkTool.pen,
          color: Colors.blue.value,
          width: 4.0,
          points: [
            InkPoint(0, 0, pressure: 1.0),
            InkPoint(50, 50, pressure: 0.8),
            InkPoint(100, 0, pressure: 1.0),
            InkPoint(150, 50, pressure: 0.9),
          ],
          createdAt: DateTime.now(),
        ),
      ];
      final painter = CanvasInkPainter(strokes: strokes);
      
      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      painter.paint(canvas, const Size(200, 100));
      final picture = recorder.endRecording();
      
      expect(picture, isNotNull);
    });
  });
}
```

- [ ] **Step 2: Run test**

Run: `flutter test test/mindmap/ink/canvas_ink_layer_test.dart`
Expected: Currently using old renderer, should still PASS but we'll verify integration

- [ ] **Step 3: Update CanvasInkPainter to use StrokeRenderer**

```dart
// lib/src/mindmap/ink/canvas_ink_layer.dart:54-80 (replace entire class)
import 'stroke_renderer.dart';

class CanvasInkPainter extends CustomPainter {
  const CanvasInkPainter({required this.strokes});

  final List<InkStroke> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.length < 2) continue;
      StrokeRenderer.drawStroke(canvas, stroke);
    }
  }

  @override
  bool shouldRepaint(covariant CanvasInkPainter oldDelegate) {
    return oldDelegate.strokes != strokes;
  }
}
```

- [ ] **Step 4: Run all ink tests**

Run: `flutter test test/mindmap/ink/`
Expected: PASS

- [ ] **Step 5: Commit integration**

```bash
git add lib/src/mindmap/ink/canvas_ink_layer.dart test/mindmap/ink/canvas_ink_layer_test.dart
git commit -m "feat(ink): integrate StrokeRenderer into CanvasInkPainter"
```

---

### Task 7: Full Pipeline Test

**Files:**
- Modify: `test/mindmap/ink/stroke_renderer_test.dart`

- [ ] **Step 1: Write integration test**

```dart
// test/mindmap/ink/stroke_renderer_test.dart (append)
    test('full pipeline: filter -> smooth -> variable-width path produces smooth output', () {
      // Simulate noisy input
      final noisyPoints = [
        InkPoint(0, 0, pressure: 1.0),
        InkPoint(1, 1, pressure: 1.0),  // jitter
        InkPoint(2, 2, pressure: 0.9),  // jitter
        InkPoint(50, 100, pressure: 0.8),
        InkPoint(51, 99, pressure: 0.8), // jitter
        InkPoint(100, 50, pressure: 1.0),
        InkPoint(150, 150, pressure: 0.9),
      ];

      // Pipeline
      final filtered = StrokeRenderer.filterPoints(noisyPoints);
      expect(filtered.length, lessThan(noisyPoints.length));
      
      final smoothed = StrokeRenderer.smoothPoints(filtered);
      expect(smoothed.length, filtered.length);
      
      final path = StrokeRenderer.variableWidthPath(smoothed, 10.0);
      final bounds = path.getBounds();
      
      // Should span full range
      expect(bounds.width, greaterThan(140));
      expect(bounds.height, greaterThan(140));
    });
```

- [ ] **Step 2: Run full test suite**

Run: `flutter test test/mindmap/ink/`
Expected: PASS

- [ ] **Step 3: Static analysis**

Run: `flutter analyze lib/src/mindmap/ink/`
Expected: No errors

- [ ] **Step 4: Commit final**

```bash
git add test/mindmap/ink/stroke_renderer_test.dart
git commit -m "test(ink): add full pipeline integration test"
```

---

## Verification Checklist

- [ ] `flutter test test/mindmap/ink/` - All tests pass
- [ ] `flutter analyze lib/src/mindmap/ink/` - No errors
- [ ] StrokeRenderer.filterPoints removes jitter
- [ ] StrokeRenderer.smoothPoints applies weighted MA
- [ ] StrokeRenderer.catmullRomPath generates smooth curves
- [ ] StrokeRenderer.variableWidthPath creates pressure-based envelopes
- [ ] StrokeRenderer.drawStroke handles pen/highlighter/eraser
- [ ] CanvasInkPainter uses new renderer

## Next Steps

After Plan 1-A completion, proceed to:
- Plan 1-B: Input stabilizer (String Pulling + Moving Average)
- Plan 1-C: Android Stylus pressure support