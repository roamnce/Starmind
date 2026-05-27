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

/// Toolbar for ink/handwriting annotation tools.
///
/// Provides:
/// - Tool selection (pen, highlighter, eraser)
/// - Color picker
/// - Stroke width slider
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

class _InkToolbarState extends State<InkToolbar> {
  bool _showColorPicker = false;
  bool _showWidthSlider = false;

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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
              // Tool buttons
              _ToolButton(
                icon: Icons.edit,
                isSelected: widget.currentTool == InkTool.pen,
                tooltip: '画笔',
                onTap: () => widget.onToolChanged(InkTool.pen),
              ),
              _ToolButton(
                icon: Icons.highlight,
                isSelected: widget.currentTool == InkTool.highlighter,
                tooltip: '荧光笔',
                onTap: () => widget.onToolChanged(InkTool.highlighter),
              ),
              _ToolButton(
                icon: Icons.cleaning_services,
                isSelected: widget.currentTool == InkTool.eraser,
                tooltip: '橡皮擦',
                onTap: () => widget.onToolChanged(InkTool.eraser),
              ),

              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 32,
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),

              // Color button
              _ColorButton(
                colorHex: widget.currentTool == InkTool.eraser
                    ? '#FFFFFF'
                    : widget.currentColor,
                onTap: widget.currentTool != InkTool.eraser
                    ? () => _showColorPickerDialog()
                    : null,
              ),

              const SizedBox(width: 8),

              // Stroke width button
              _WidthButton(
                strokeWidth: widget.strokeWidth,
                onTap: widget.currentTool != InkTool.eraser
                    ? () => _showWidthSliderDialog()
                    : null,
              ),

              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 32,
                color: theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
              const SizedBox(width: 8),

              // Palm rejection toggle
              IconButton(
                icon: Icon(
                  widget.palmRejectionEnabled
                      ? Icons.touch_app
                      : Icons.do_not_touch,
                  size: 20,
                ),
                color: widget.palmRejectionEnabled
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                onPressed: () => widget.onPalmRejectionChanged(!widget.palmRejectionEnabled),
                tooltip: widget.palmRejectionEnabled ? '防误触开启' : '防误触关闭',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('选择颜色'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: presetColors.map((colorHex) {
            final isSelected = colorHex == widget.currentColor;
            final color = _parseColorHex(colorHex);

            return GestureDetector(
              onTap: () {
                widget.onColorChanged(colorHex);
                Navigator.of(context).pop();
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 3)
                      : null,
                ),
                child: isSelected
                    ? Icon(
                        Icons.check,
                        color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        size: 20,
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
  }

  void _showWidthSliderDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('笔触粗细'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Slider(
              value: widget.strokeWidth,
              min: 1.0,
              max: 20.0,
              divisions: 19,
              onChanged: (value) {
                widget.onStrokeWidthChanged(value);
              },
            ),
            Text('当前: ${widget.strokeWidth.toStringAsFixed(1)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Color _parseColorHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

/// Tool selection button.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final String tooltip;
  final VoidCallback? onTap;

  const _ToolButton({
    required this.icon,
    required this.isSelected,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: isSelected ? theme.colorScheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 36,
          height: 36,
          child: Icon(
            icon,
            size: 20,
            color: isSelected
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}

/// Color selection button.
class _ColorButton extends StatelessWidget {
  final String colorHex;
  final VoidCallback? onTap;

  const _ColorButton({
    required this.colorHex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColorHex(colorHex);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
            ),
          ],
        ),
      ),
    );
  }

  Color _parseColorHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

/// Stroke width button.
class _WidthButton extends StatelessWidget {
  final double strokeWidth;
  final VoidCallback? onTap;

  const _WidthButton({
    required this.strokeWidth,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Container(
            width: strokeWidth.clamp(2.0, 16.0),
            height: strokeWidth.clamp(2.0, 16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}