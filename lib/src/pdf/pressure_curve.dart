import 'package:flutter/material.dart';

/// Pressure curve - uses cubic Bezier to map raw pressure to output pressure
///
/// Control points define the shape:
/// - p0 is always (0, 0) - zero pressure stays zero
/// - p3 is always (1, 1) - max pressure stays max
/// - p1, p2 are user-configurable control points
class PressureCurve {
  final Offset p1; // Control point 1
  final Offset p2; // Control point 2

  const PressureCurve({
    this.p1 = const Offset(0.25, 0.25),
    this.p2 = const Offset(0.75, 0.75),
  });

  // Named presets
  static const linear = PressureCurve(
    p1: Offset(0.25, 0.25),
    p2: Offset(0.75, 0.75),
  );

  static const soft = PressureCurve(
    p1: Offset(0.15, 0.45),
    p2: Offset(0.55, 0.90),
  );

  static const firm = PressureCurve(
    p1: Offset(0.45, 0.10),
    p2: Offset(0.85, 0.55),
  );

  static const sCurve = PressureCurve(
    p1: Offset(0.25, 0.05),
    p2: Offset(0.75, 0.95),
  );

  static const heavy = PressureCurve(
    p1: Offset(0.60, 0.05),
    p2: Offset(0.95, 0.40),
  );

  /// Evaluate the curve at a given raw pressure value
  double evaluate(double rawPressure) {
    final x = rawPressure.clamp(0.0, 1.0);
    if (x <= 0.0) return 0.0;
    if (x >= 1.0) return 1.0;

    final t = _solveForT(x);
    return _bezierY(t).clamp(0.0, 1.0);
  }

  double _bezierX(double t) {
    final mt = 1.0 - t;
    return 3.0 * mt * mt * t * p1.dx +
        3.0 * mt * t * t * p2.dx +
        t * t * t;
  }

  double _bezierY(double t) {
    final mt = 1.0 - t;
    return 3.0 * mt * mt * t * p1.dy +
        3.0 * mt * t * t * p2.dy +
        t * t * t;
  }

  double _bezierXDerivative(double t) {
    final mt = 1.0 - t;
    return 3.0 * mt * mt * p1.dx +
        6.0 * mt * t * (p2.dx - p1.dx) +
        3.0 * t * t * (1.0 - p2.dx);
  }

  double _solveForT(double x) {
    double t = x;
    for (int i = 0; i < 6; i++) {
      final error = _bezierX(t) - x;
      final deriv = _bezierXDerivative(t);
      if (deriv.abs() < 1e-10) break;
      t -= error / deriv;
      t = t.clamp(0.0, 1.0);
      if (error.abs() < 1e-5) break;
    }
    return t;
  }

  Map<String, dynamic> toJson() => {
        'p1x': p1.dx,
        'p1y': p1.dy,
        'p2x': p2.dx,
        'p2y': p2.dy,
      };

  factory PressureCurve.fromJson(Map<String, dynamic>? json) {
    if (json == null) return PressureCurve.linear;
    return PressureCurve(
      p1: Offset(
        (json['p1x'] as num?)?.toDouble() ?? 0.25,
        (json['p1y'] as num?)?.toDouble() ?? 0.25,
      ),
      p2: Offset(
        (json['p2x'] as num?)?.toDouble() ?? 0.75,
        (json['p2y'] as num?)?.toDouble() ?? 0.75,
      ),
    );
  }
}
