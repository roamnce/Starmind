import 'package:flutter/material.dart';
import 'package:starmind/src/pdf/pen_config.dart';
import 'package:starmind/src/pdf/pressure_curve.dart';

/// Pen configuration panel widget.
///
/// Provides UI for configuring pen settings:
/// - Pen type selection (fountainPen, ballpointPen, pencil, highlighter, eraser)
/// - Stabilizer level slider (0-10)
/// - Pressure curve selection (when pressure is enabled)
class PenConfigPanel extends StatefulWidget {
  /// Current pen configuration.
  final PenConfig config;

  /// Callback when configuration changes.
  final ValueChanged<PenConfig> onConfigChanged;

  const PenConfigPanel({
    super.key,
    required this.config,
    required this.onConfigChanged,
  });

  @override
  State<PenConfigPanel> createState() => _PenConfigPanelState();
}

class _PenConfigPanelState extends State<PenConfigPanel> {
  /// Pen type labels in Chinese.
  static const Map<PenType, String> _penTypeLabels = {
    PenType.fountainPen: '钢笔',
    PenType.ballpointPen: '圆珠笔',
    PenType.pencil: '铅笔',
    PenType.highlighter: '荧光笔',
    PenType.eraser: '橡皮擦',
  };

  /// Pressure curve labels in Chinese.
  static const Map<PressureCurvePreset, String> _pressureCurveLabels = {
    PressureCurvePreset.linear: '线性',
    PressureCurvePreset.soft: '柔和',
    PressureCurvePreset.firm: '硬朗',
    PressureCurvePreset.sCurve: 'S型',
    PressureCurvePreset.heavy: '重压',
  };

  void _onPenTypeChanged(PenType type) {
    // Create a new config based on the pen type preset
    PenConfig newConfig;
    switch (type) {
      case PenType.fountainPen:
        newConfig = PenConfig.fountainPen(
          color: widget.config.color,
          stabilizerLevel: widget.config.stabilizerLevel,
        );
      case PenType.ballpointPen:
        newConfig = PenConfig.ballpointPen(
          color: widget.config.color,
          stabilizerLevel: widget.config.stabilizerLevel,
        );
      case PenType.pencil:
        newConfig = PenConfig.pencil(
          color: widget.config.color,
          stabilizerLevel: widget.config.stabilizerLevel,
        );
      case PenType.highlighter:
        newConfig = PenConfig.highlighter(
          color: widget.config.color,
          baseWidth: widget.config.baseWidth,
        );
      case PenType.eraser:
        newConfig = PenConfig.eraser(
          baseWidth: widget.config.baseWidth,
        );
    }
    widget.onConfigChanged(newConfig);
  }

  void _onStabilizerLevelChanged(double value) {
    widget.onConfigChanged(
      widget.config.copyWith(stabilizerLevel: value.round()),
    );
  }

  void _onPressureCurveChanged(PressureCurve curve) {
    widget.onConfigChanged(
      widget.config.copyWith(pressureCurve: curve),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pen type selection
          _buildSectionTitle('笔类型', theme),
          const SizedBox(height: 8),
          _buildPenTypeSelector(theme),
          const SizedBox(height: 24),

          // Stabilizer level slider
          _buildSectionTitle('平滑度', theme),
          const SizedBox(height: 8),
          _buildStabilizerSlider(theme),
          const SizedBox(height: 24),

          // Pressure curve selection (only for pressure-enabled pens)
          if (widget.config.pressureEnabled) ...[
            _buildSectionTitle('压感曲线', theme),
            const SizedBox(height: 8),
            _buildPressureCurveSelector(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildPenTypeSelector(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: PenType.values.map((type) {
        final isSelected = widget.config.type == type;
        return ChoiceChip(
          label: Text(_penTypeLabels[type]!),
          selected: isSelected,
          onSelected: (selected) {
            if (selected) {
              _onPenTypeChanged(type);
            }
          },
          selectedColor: theme.colorScheme.primaryContainer,
          labelStyle: TextStyle(
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStabilizerSlider(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Slider(
          value: widget.config.stabilizerLevel.toDouble(),
          min: 0,
          max: 10,
          divisions: 10,
          onChanged: _onStabilizerLevelChanged,
        ),
        Text(
          '当前: ${widget.config.stabilizerLevel}',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildPressureCurveSelector(ThemeData theme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildPressureCurveChip(
          theme: theme,
          label: _pressureCurveLabels[PressureCurvePreset.linear]!,
          curve: PressureCurve.linear,
          isSelected: _isPressureCurveEqual(PressureCurve.linear),
        ),
        _buildPressureCurveChip(
          theme: theme,
          label: _pressureCurveLabels[PressureCurvePreset.soft]!,
          curve: PressureCurve.soft,
          isSelected: _isPressureCurveEqual(PressureCurve.soft),
        ),
        _buildPressureCurveChip(
          theme: theme,
          label: _pressureCurveLabels[PressureCurvePreset.firm]!,
          curve: PressureCurve.firm,
          isSelected: _isPressureCurveEqual(PressureCurve.firm),
        ),
        _buildPressureCurveChip(
          theme: theme,
          label: _pressureCurveLabels[PressureCurvePreset.sCurve]!,
          curve: PressureCurve.sCurve,
          isSelected: _isPressureCurveEqual(PressureCurve.sCurve),
        ),
        _buildPressureCurveChip(
          theme: theme,
          label: _pressureCurveLabels[PressureCurvePreset.heavy]!,
          curve: PressureCurve.heavy,
          isSelected: _isPressureCurveEqual(PressureCurve.heavy),
        ),
      ],
    );
  }

  Widget _buildPressureCurveChip({
    required ThemeData theme,
    required String label,
    required PressureCurve curve,
    required bool isSelected,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          _onPressureCurveChanged(curve);
        }
      },
      selectedColor: theme.colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: isSelected
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurface,
      ),
    );
  }

  /// Check if two pressure curves are equal by comparing control points.
  bool _isPressureCurveEqual(PressureCurve other) {
    return widget.config.pressureCurve.p1 == other.p1 &&
        widget.config.pressureCurve.p2 == other.p2;
  }
}

/// Pressure curve preset enum for UI purposes.
enum PressureCurvePreset {
  linear,
  soft,
  firm,
  sCurve,
  heavy,
}
