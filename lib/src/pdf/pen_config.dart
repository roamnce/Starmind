import 'package:flutter/material.dart';
import 'package:starmind/src/pdf/pressure_curve.dart';

/// Pen type enumeration for different drawing tools.
///
/// Each pen type has distinct characteristics:
/// - **fountainPen**: Pressure-sensitive, variable width, smooth curves
/// - **ballpointPen**: Consistent width, moderate stabilizer
/// - **pencil**: Textured appearance, lower opacity, pressure-sensitive
/// - **highlighter**: Semi-transparent, fixed width, no pressure
/// - **eraser**: Removes strokes, fixed width, no pressure
enum PenType {
  fountainPen,
  ballpointPen,
  pencil,
  highlighter,
  eraser;

  /// Parse pen type from string, returns [ballpointPen] for invalid/null input.
  static PenType fromString(String? value) {
    if (value == null || value.isEmpty) return PenType.ballpointPen;
    return PenType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => PenType.ballpointPen,
    );
  }
}

/// Configuration for pen/drawing tool behavior.
///
/// Encapsulates all configurable parameters for ink strokes:
/// - Visual properties: color, width, opacity
/// - Pressure behavior: curve, enabled/disabled
/// - Stabilization: level for stroke smoothing
///
/// Use factory presets for common pen types, or create custom configurations.
///
/// Example:
/// ```dart
/// // Use preset
/// final fountainPen = PenConfig.fountainPen();
///
/// // Custom configuration
/// final customPen = PenConfig(
///   type: PenType.ballpointPen,
///   color: Colors.blue,
///   baseWidth: 2.0,
///   stabilizerLevel: 5,
/// );
///
/// // Modify existing config
/// final thickerPen = fountainPen.copyWith(baseWidth: 4.0);
/// ```
class PenConfig {
  /// Type of pen/tool.
  final PenType type;

  /// Stroke color.
  final Color color;

  /// Base stroke width in logical pixels.
  final double baseWidth;

  /// Stroke opacity (0.0 = transparent, 1.0 = opaque).
  final double opacity;

  /// Pressure curve for pressure-sensitive pens.
  final PressureCurve pressureCurve;

  /// Stabilizer level (0 = none, 10 = maximum smoothing).
  final int stabilizerLevel;

  /// Whether pressure sensitivity is enabled.
  final bool pressureEnabled;

  /// Creates a pen configuration.
  const PenConfig({
    this.type = PenType.ballpointPen,
    this.color = Colors.black,
    this.baseWidth = 2.0,
    this.opacity = 1.0,
    this.pressureCurve = PressureCurve.linear,
    this.stabilizerLevel = 3,
    this.pressureEnabled = false,
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FACTORY PRESETS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Fountain pen preset.
  ///
  /// Characteristics:
  /// - Pressure-sensitive with soft curve
  /// - Variable width based on pressure
  /// - Moderate stabilizer for smooth curves
  /// - Full opacity
  static PenConfig fountainPen({
    Color color = Colors.black,
    double baseWidth = 1.5,
    int stabilizerLevel = 4,
  }) {
    return PenConfig(
      type: PenType.fountainPen,
      color: color,
      baseWidth: baseWidth,
      opacity: 1.0,
      pressureCurve: PressureCurve.soft,
      stabilizerLevel: stabilizerLevel,
      pressureEnabled: true,
    );
  }

  /// Ballpoint pen preset.
  ///
  /// Characteristics:
  /// - Consistent width (no pressure)
  /// - Medium stabilizer for steady lines
  /// - Full opacity
  static PenConfig ballpointPen({
    Color color = Colors.black,
    double baseWidth = 1.0,
    int stabilizerLevel = 3,
  }) {
    return PenConfig(
      type: PenType.ballpointPen,
      color: color,
      baseWidth: baseWidth,
      opacity: 1.0,
      pressureCurve: PressureCurve.linear,
      stabilizerLevel: stabilizerLevel,
      pressureEnabled: false,
    );
  }

  /// Pencil preset.
  ///
  /// Characteristics:
  /// - Pressure-sensitive for shading
  /// - Slightly transparent for layering
  /// - Light stabilizer for natural feel
  static PenConfig pencil({
    Color color = const Color(0xFF444444),
    double baseWidth = 1.0,
    int stabilizerLevel = 2,
  }) {
    return PenConfig(
      type: PenType.pencil,
      color: color,
      baseWidth: baseWidth,
      opacity: 0.7,
      pressureCurve: PressureCurve.soft,
      stabilizerLevel: stabilizerLevel,
      pressureEnabled: true,
    );
  }

  /// Highlighter preset.
  ///
  /// Characteristics:
  /// - Semi-transparent (30% opacity)
  /// - Fixed width, no pressure
  /// - No stabilizer for direct response
  static PenConfig highlighter({
    Color color = Colors.yellow,
    double baseWidth = 8.0,
  }) {
    return PenConfig(
      type: PenType.highlighter,
      color: color,
      baseWidth: baseWidth,
      opacity: 0.3,
      pressureCurve: PressureCurve.linear,
      stabilizerLevel: 0,
      pressureEnabled: false,
    );
  }

  /// Eraser preset.
  ///
  /// Characteristics:
  /// - Fixed width
  /// - No pressure sensitivity
  /// - No stabilizer
  static PenConfig eraser({
    double baseWidth = 20.0,
  }) {
    return PenConfig(
      type: PenType.eraser,
      color: Colors.white,
      baseWidth: baseWidth,
      opacity: 1.0,
      pressureCurve: PressureCurve.linear,
      stabilizerLevel: 0,
      pressureEnabled: false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SERIALIZATION
  // ═══════════════════════════════════════════════════════════════════════════

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'color': color.toARGB32(), // Call the method to get int value
      'baseWidth': baseWidth,
      'opacity': opacity,
      'pressureCurve': pressureCurve.toJson(),
      'stabilizerLevel': stabilizerLevel,
      'pressureEnabled': pressureEnabled,
    };
  }

  /// Deserialize from JSON map.
  factory PenConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const PenConfig();

    // Handle color which may be stored as int or from toARGB32 getter
    int colorValue;
    final colorRaw = json['color'];
    if (colorRaw is int) {
      colorValue = colorRaw;
    } else {
      colorValue = 0xFF000000;
    }

    return PenConfig(
      type: PenType.fromString(json['type'] as String?),
      color: Color(colorValue),
      baseWidth: (json['baseWidth'] as num?)?.toDouble() ?? 2.0,
      opacity: (json['opacity'] as num?)?.toDouble() ?? 1.0,
      pressureCurve: PressureCurve.fromJson(
        json['pressureCurve'] as Map<String, dynamic>?,
      ),
      stabilizerLevel: (json['stabilizerLevel'] as int?) ?? 3,
      pressureEnabled: json['pressureEnabled'] as bool? ?? false,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a copy with modified fields.
  PenConfig copyWith({
    PenType? type,
    Color? color,
    double? baseWidth,
    double? opacity,
    PressureCurve? pressureCurve,
    int? stabilizerLevel,
    bool? pressureEnabled,
  }) {
    return PenConfig(
      type: type ?? this.type,
      color: color ?? this.color,
      baseWidth: baseWidth ?? this.baseWidth,
      opacity: opacity ?? this.opacity,
      pressureCurve: pressureCurve ?? this.pressureCurve,
      stabilizerLevel: stabilizerLevel ?? this.stabilizerLevel,
      pressureEnabled: pressureEnabled ?? this.pressureEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PenConfig &&
        other.type == type &&
        other.color == color &&
        other.baseWidth == baseWidth &&
        other.opacity == opacity &&
        other.pressureCurve == pressureCurve &&
        other.stabilizerLevel == stabilizerLevel &&
        other.pressureEnabled == pressureEnabled;
  }

  @override
  int get hashCode {
    return Object.hash(
      type,
      color,
      baseWidth,
      opacity,
      pressureCurve,
      stabilizerLevel,
      pressureEnabled,
    );
  }

  @override
  String toString() {
    return 'PenConfig(type: $type, color: $color, baseWidth: $baseWidth, '
        'opacity: $opacity, stabilizerLevel: $stabilizerLevel, '
        'pressureEnabled: $pressureEnabled)';
  }
}
