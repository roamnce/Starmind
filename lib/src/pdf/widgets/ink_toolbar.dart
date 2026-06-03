import 'package:flutter/material.dart';
import 'package:starmind/src/pdf/pen_config.dart';

/// Drawing tool types for PDF annotation.
///
/// Note: Prefer using [PenType] from pen_config.dart for richer pen configurations.
/// This enum is kept for backward compatibility.
enum InkTool {
  pen, // 普通画笔
  highlighter, // 荧光笔（半透明）
  eraser, // 橡皮擦
}

/// Extension to convert between InkTool and PenType.
extension InkToolPenTypeConversion on InkTool {
  /// Convert to corresponding PenType.
  PenType toPenType() {
    switch (this) {
      case InkTool.pen:
        return PenType.ballpointPen;
      case InkTool.highlighter:
        return PenType.highlighter;
      case InkTool.eraser:
        return PenType.eraser;
    }
  }

  /// Create a PenConfig preset for this tool.
  PenConfig toPenConfig({Color? color, double? width}) {
    switch (this) {
      case InkTool.pen:
        return PenConfig.ballpointPen(color: color ?? Colors.black, baseWidth: width ?? 1.0);
      case InkTool.highlighter:
        return PenConfig.highlighter(color: color ?? Colors.yellow, baseWidth: width ?? 8.0);
      case InkTool.eraser:
        return PenConfig.eraser(baseWidth: width ?? 20.0);
    }
  }
}

/// Extension to convert PenType to InkTool.
extension PenTypeInkToolConversion on PenType {
  /// Convert to corresponding InkTool.
  InkTool toInkTool() {
    switch (this) {
      case PenType.fountainPen:
      case PenType.ballpointPen:
      case PenType.pencil:
        return InkTool.pen;
      case PenType.highlighter:
        return InkTool.highlighter;
      case PenType.eraser:
        return InkTool.eraser;
    }
  }
}

/// Compact toolbar for ink/handwriting annotation tools.
///
/// Provides:
/// - Tool selection (pen, highlighter, eraser)
/// - Color picker
/// - Stroke width slider
/// - Palm rejection toggle
///
/// Uses Forui components for a modern, compact UI.
class InkToolbar extends StatefulWidget {
  final InkTool currentTool;
  final String currentColor;
  final double strokeWidth;
  final bool palmRejectionEnabled;
  final void Function(InkTool) onToolChanged;
  final void Function(String) onColorChanged;
  final void Function(double) onStrokeWidthChanged;
  final void Function(bool) onPalmRejectionChanged;

  const InkToolbar({
    super.key,
    required this.currentTool,
    required this.currentColor,
    required this.strokeWidth,
    required this.palmRejectionEnabled,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onStrokeWidthChanged,
    required this.onPalmRejectionChanged,
  });

  @override
  State<InkToolbar> createState() => _InkToolbarState();
}

class _InkToolbarState extends State<InkToolbar> with SingleTickerProviderStateMixin {
  late AnimationController _expandController;
  bool _isColorExpanded = false;
  bool _isWidthExpanded = false;

  /// Preset colors for ink.
  static const List<String> presetColors = [
    '#000000', // Black
    '#FF0000', // Red
    '#0000FF', // Blue
    '#008000', // Green
    '#FF6B35', // Orange
    '#800080', // Purple
  ];

  @override
  void initState() {
    super.initState();
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2E).withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main toolbar row
          Row(
            children: [
              // Tool buttons group
              _CompactToolButton(
                icon: Icons.edit_rounded,
                isSelected: widget.currentTool == InkTool.pen,
                tooltip: '画笔',
                onTap: () => widget.onToolChanged(InkTool.pen),
              ),
              _CompactToolButton(
                icon: Icons.highlight_rounded,
                isSelected: widget.currentTool == InkTool.highlighter,
                tooltip: '荧光笔',
                onTap: () => widget.onToolChanged(InkTool.highlighter),
              ),
              _CompactToolButton(
                icon: Icons.cleaning_services_rounded,
                isSelected: widget.currentTool == InkTool.eraser,
                tooltip: '橡皮擦',
                onTap: () => widget.onToolChanged(InkTool.eraser),
              ),

              _VerticalDivider(),

              // Color button (compact)
              if (widget.currentTool != InkTool.eraser)
                _CompactColorButton(
                  colorHex: widget.currentColor,
                  onTap: () => setState(() => _isColorExpanded = !_isColorExpanded),
                ),

              // Width button (compact)
              if (widget.currentTool != InkTool.eraser)
                _CompactWidthButton(
                  strokeWidth: widget.strokeWidth,
                  onTap: () => setState(() => _isWidthExpanded = !_isWidthExpanded),
                ),

              _VerticalDivider(),

              // Palm rejection toggle (compact)
              _CompactIconButton(
                icon: widget.palmRejectionEnabled
                    ? Icons.touch_app_rounded
                    : Icons.do_not_touch_rounded,
                tooltip: widget.palmRejectionEnabled ? '防误触开启' : '防误触关闭',
                isActive: widget.palmRejectionEnabled,
                onTap: () => widget.onPalmRejectionChanged(!widget.palmRejectionEnabled),
              ),
            ],
          ),

          // Expanded color picker
          if (_isColorExpanded && widget.currentTool != InkTool.eraser)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _CompactColorPicker(
                colors: presetColors,
                selectedColor: widget.currentColor,
                onColorSelected: (colorHex) {
                  widget.onColorChanged(colorHex);
                  setState(() => _isColorExpanded = false);
                },
              ),
            ),

          // Expanded width slider
          if (_isWidthExpanded && widget.currentTool != InkTool.eraser)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _CompactWidthSlider(
                strokeWidth: widget.strokeWidth,
                onChanged: widget.onStrokeWidthChanged,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact tool selection button.
class _CompactToolButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final String tooltip;
  final VoidCallback onTap;

  const _CompactToolButton({
    required this.icon,
    required this.isSelected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isSelected
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.white54 : Colors.black45),
          ),
        ),
      ),
    );
  }
}

/// Compact icon button.
class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool isActive;
  final VoidCallback onTap;

  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.1))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isActive
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.white54 : Colors.black45),
          ),
        ),
      ),
    );
  }
}

/// Compact color button.
class _CompactColorButton extends StatelessWidget {
  final String colorHex;
  final VoidCallback onTap;

  const _CompactColorButton({
    required this.colorHex,
    required this.onTap,
  });

  Color _parseColorHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    final color = _parseColorHex(colorHex);

    return Tooltip(
      message: '颜色',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact width button.
class _CompactWidthButton extends StatelessWidget {
  final double strokeWidth;
  final VoidCallback onTap;

  const _CompactWidthButton({
    required this.strokeWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: '粗细: ${strokeWidth.toStringAsFixed(1)}',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Container(
              width: strokeWidth.clamp(3.0, 12.0),
              height: strokeWidth.clamp(3.0, 12.0),
              decoration: BoxDecoration(
                color: isDark ? Colors.white70 : Colors.black54,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact color picker row.
class _CompactColorPicker extends StatelessWidget {
  final List<String> colors;
  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  const _CompactColorPicker({
    required this.colors,
    required this.selectedColor,
    required this.onColorSelected,
  });

  Color _parseColorHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: colors.map((colorHex) {
        final color = _parseColorHex(colorHex);
        final isSelected = colorHex == selectedColor;

        return GestureDetector(
          onTap: () => onColorSelected(colorHex),
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2)
                  : Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 2,
                ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check,
                    size: 14,
                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  )
                : null,
          ),
        );
      }).toList(),
    );
  }
}

/// Compact width slider.
class _CompactWidthSlider extends StatelessWidget {
  final double strokeWidth;
  final ValueChanged<double> onChanged;

  const _CompactWidthSlider({
    required this.strokeWidth,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.edit_rounded,
          size: 14,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: Slider(
            value: strokeWidth,
            min: 1.0,
            max: 20.0,
            divisions: 19,
            onChanged: onChanged,
          ),
        ),
        Text(
          strokeWidth.toStringAsFixed(1),
          style: TextStyle(
            fontSize: 11,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ],
    );
  }
}

/// Vertical divider for toolbar sections.
class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.12),
    );
  }
}