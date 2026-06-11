import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ink/stylus_input_handler.dart';

void main() {
  group('StylusInputHandler', () {
    group('isStylusPointer', () {
      test('returns true for stylus', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.stylus,
          pressure: 0.5,
          size: 0.01,
        );
        expect(StylusInputHandler.isStylusPointer(event), isTrue);
      });

      test('returns true for invertedStylus', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.invertedStylus,
          pressure: 0.5,
          size: 0.01,
        );
        expect(StylusInputHandler.isStylusPointer(event), isTrue);
      });

      test('returns false for touch', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.touch,
          pressure: 0.5,
          size: 0.01,
        );
        expect(StylusInputHandler.isStylusPointer(event), isFalse);
      });

      test('returns false for mouse', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.mouse,
          pressure: 0.5,
          size: 0.01,
        );
        expect(StylusInputHandler.isStylusPointer(event), isFalse);
      });
    });

    group('getPressure', () {
      test('returns clamped pressure for stylus', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.stylus,
          pressure: 0.75,
          size: 0.01,
        );
        expect(StylusInputHandler.getPressure(event), equals(0.75));
      });

      test('clamps pressure above 1.0', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.stylus,
          pressure: 1.5,
          size: 0.01,
        );
        expect(StylusInputHandler.getPressure(event), equals(1.0));
      });

      test('clamps pressure below 0.0', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.stylus,
          pressure: -0.1,
          size: 0.01,
        );
        expect(StylusInputHandler.getPressure(event), equals(0.0));
      });

      test('returns 1.0 for non-stylus', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.touch,
          pressure: 0.5,
          size: 0.01,
        );
        expect(StylusInputHandler.getPressure(event), equals(1.0));
      });

      test('returns 1.0 for mouse', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.mouse,
          pressure: 0.0,
          size: 0.01,
        );
        expect(StylusInputHandler.getPressure(event), equals(1.0));
      });
    });

    group('isPalmTouch', () {
      test('returns true for touch with large size', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.touch,
          pressure: 0.5,
          size: 0.1,
        );
        expect(StylusInputHandler.isPalmTouch(event), isTrue);
      });

      test('returns false for touch with small size', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.touch,
          pressure: 0.5,
          size: 0.03,
        );
        expect(StylusInputHandler.isPalmTouch(event), isFalse);
      });

      test('returns false for stylus even with large size', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.stylus,
          pressure: 0.5,
          size: 0.1,
        );
        expect(StylusInputHandler.isPalmTouch(event), isFalse);
      });

      test('returns false at threshold boundary', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.touch,
          pressure: 0.5,
          size: 0.05,
        );
        expect(StylusInputHandler.isPalmTouch(event), isFalse);
      });

      test('returns true just above threshold', () {
        final event = _FakePointerEvent(
          kind: PointerDeviceKind.touch,
          pressure: 0.5,
          size: 0.051,
        );
        expect(StylusInputHandler.isPalmTouch(event), isTrue);
      });
    });
  });
}

/// 测试用 Fake PointerEvent，仅实现测试所需的字段。
class _FakePointerEvent implements PointerEvent {
  @override
  final PointerDeviceKind kind;

  @override
  final double pressure;

  @override
  final double size;

  _FakePointerEvent({
    required this.kind,
    required this.pressure,
    required this.size,
  });

  // === PointerEvent 必需字段 ===
  @override
  Offset get localPosition => Offset.zero;

  @override
  Offset get position => Offset.zero;

  @override
  Offset get delta => Offset.zero;

  @override
  int get pointer => 0;

  @override
  int get device => 0;

  @override
  int get buttons => 0;

  @override
  bool get down => false;

  @override
  double get pressureMax => 1.0;

  @override
  double get pressureMin => 0.0;

  @override
  Offset get localDelta => Offset.zero;

  @override
  Duration get timeStamp => Duration.zero;

  @override
  int get embedderId => 0;

  @override
  double get orientation => 0.0;

  @override
  double get tilt => 0.0;

  @override
  double get tangentialPressure => 0.0;

  @override
  int get display => 0;

  @override
  bool get synthesized => false;

  @override
  Offset get originalPosition => Offset.zero;

  @override
  int get platformData => 0;

  @override
  double get distance => 0.0;

  @override
  double get distanceMax => 0.0;

  @override
  double get distanceMin => 0.0;

  @override
  bool get obscured => false;

  @override
  PointerEvent? get original => null;

  @override
  double get radiusMajor => 0.0;

  @override
  double get radiusMax => 0.0;

  @override
  double get radiusMin => 0.0;

  @override
  double get radiusMinor => 0.0;

  @override
  Matrix4? get transform => null;

  @override
  int get viewId => 0;

  @override
  Offset localToGlobal(Offset point) => point;

  @override
  Offset globalToLocal(Offset point) => point;

  @override
  PointerEvent transformed(Matrix4? transform) => this;

  @override
  PointerEvent copyWith({
    Offset? position,
    Offset? localPosition,
    Offset? delta,
    Offset? localDelta,
    int? pointer,
    int? device,
    PointerDeviceKind? kind,
    int? buttons,
    bool? down,
    bool? synthesized,
    double? pressure,
    double? pressureMin,
    double? pressureMax,
    double? orientation,
    double? tilt,
    double? tangentialPressure,
    int? embedderId,
    int? display,
    double? size,
    Duration? timeStamp,
    bool? obscured,
    double? distance,
    double? distanceMax,
    double? radiusMajor,
    double? radiusMinor,
    double? radiusMin,
    double? radiusMax,
    Matrix4? transform,
    int? platformData,
    int? viewId,
    PointerEvent? original,
  }) {
    return _FakePointerEvent(
      kind: kind ?? this.kind,
      pressure: pressure ?? this.pressure,
      size: size ?? this.size,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    properties.add(DiagnosticsProperty<PointerDeviceKind>('kind', kind));
    properties.add(DoubleProperty('pressure', pressure));
    properties.add(DoubleProperty('size', size));
  }

  @override
  DiagnosticsNode toDiagnosticsNode({
    String? name,
    DiagnosticsTreeStyle? style,
  }) {
    return DiagnosticsProperty<void>(
      name ?? 'PointerEvent',
      null,
      description: toString(),
    );
  }

  @override
  String toStringShort() => describeIdentity(this);

  @override
  String toString({DiagnosticLevel minLevel = DiagnosticLevel.info}) {
    return '_FakePointerEvent(kind: $kind, pressure: $pressure, size: $size)';
  }
}