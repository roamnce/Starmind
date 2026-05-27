import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pdf_gesture_handler.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';

void main() {
  group('PdfGestureHandler', () {
    late PdfViewportController controller;
    late PdfGestureHandler handler;

    setUp(() {
      controller = PdfViewportController();
      handler = PdfGestureHandler(controller: controller);
    });

    tearDown(() {
      controller.dispose();
    });

    test('should detect zoom gesture', () {
      handler.onScaleStart(ScaleStartDetails(
        localFocalPoint: const Offset(100, 100),
      ));

      handler.onScaleUpdate(ScaleUpdateDetails(
        localFocalPoint: const Offset(100, 100),
        scale: 2.0,
      ));

      expect(controller.zoom, closeTo(2.0, 0.01));
    });

    test('should detect pan gesture', () {
      handler.onScaleStart(ScaleStartDetails(
        localFocalPoint: const Offset(0, 0),
      ));

      handler.onScaleUpdate(ScaleUpdateDetails(
        localFocalPoint: const Offset(50, 50),
        scale: 1.0,
      ));

      expect(controller.panOffset.dx, closeTo(50, 0.01));
      expect(controller.panOffset.dy, closeTo(50, 0.01));
    });

    test('should apply boundary constraints on scale end', () {
      controller.setViewportSize(const Size(400, 600));

      handler.onScaleStart(ScaleStartDetails(
        localFocalPoint: const Offset(200, 300),
      ));

      handler.onScaleUpdate(ScaleUpdateDetails(
        localFocalPoint: const Offset(200, 300),
        scale: 0.3, // Below minZoom
      ));

      handler.onScaleEnd(
        ScaleEndDetails(),
        const Size(595, 842),
        const Size(400, 600),
      );

      expect(controller.zoom, greaterThanOrEqualTo(PdfViewportController.minZoom));
    });
  });
}
