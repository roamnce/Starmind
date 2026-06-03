import 'package:flutter/material.dart';

/// Color picker popup with preset colors and custom color entry.
///
/// Usage:
/// ```dart
/// showColorPickerPopup(
///   context: context,
///   currentColor: '#FFFF00',
///   onColorSelected: (colorHex) { ... },
/// );
/// ```
class ColorPickerPopup extends StatelessWidget {
  final String currentColor;
  final void Function(String colorHex) onColorSelected;

  const ColorPickerPopup({
    super.key,
    required this.currentColor,
    required this.onColorSelected,
  });

  /// Preset colors for quick access.
  static const List<String> presetColors = [
    '#FFFF00', // Yellow (default highlight)
    '#FF9800', // Orange
    '#4CAF50', // Green
    '#2196F3', // Blue
    '#9C27B0', // Purple
    '#F44336', // Red
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Preset colors row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: presetColors.map((colorHex) {
                return _ColorChip(
                  colorHex: colorHex,
                  isSelected: colorHex == currentColor,
                  onTap: () => onColorSelected(colorHex),
                );
              }).toList(),
            ),

            const SizedBox(height: 12),

            // Custom color button
            InkWell(
              onTap: () => _showFullColorPicker(context),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.palette,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '自定义颜色',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullColorPicker(BuildContext context) {
    // Show full color picker using Flutter's built-in color picker
    showDialog(
      context: context,
      builder: (context) => _FullColorPickerDialog(
        currentColor: currentColor,
        onColorSelected: (colorHex) {
          Navigator.of(context).pop();
          onColorSelected(colorHex);
        },
      ),
    );
  }
}

/// A single color chip in the preset palette.
class _ColorChip extends StatelessWidget {
  final String colorHex;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorChip({
    required this.colorHex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColorHex(colorHex);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: theme.colorScheme.primary,
                  width: 3,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
                size: 18,
              )
            : null,
      ),
    );
  }

  Color _parseColorHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

/// Full color picker with HSV wheel.
class _FullColorPickerDialog extends StatefulWidget {
  final String currentColor;
  final void Function(String colorHex) onColorSelected;

  const _FullColorPickerDialog({
    required this.currentColor,
    required this.onColorSelected,
  });

  @override
  State<_FullColorPickerDialog> createState() => _FullColorPickerDialogState();
}

class _FullColorPickerDialogState extends State<_FullColorPickerDialog> {
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedColor = _parseColorHex(widget.currentColor);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('选择颜色'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color preview
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _selectedColor,
              shape: BoxShape.circle,
              border: Border.all(color: theme.colorScheme.outline),
            ),
          ),

          const SizedBox(height: 16),

          // HSV sliders
          _ColorSlider(
            label: '色相',
            value: _hsvColorFromColor(_selectedColor).hue,
            max: 360,
            onChanged: (value) {
              setState(() {
                final hsv = _hsvColorFromColor(_selectedColor);
                _selectedColor = HSVColor.fromAHSV(hsv.alpha, value, hsv.saturation, hsv.value).toColor();
              });
            },
          ),

          _ColorSlider(
            label: '饱和度',
            value: _hsvColorFromColor(_selectedColor).saturation * 100,
            max: 100,
            onChanged: (value) {
              setState(() {
                final hsv = _hsvColorFromColor(_selectedColor);
                _selectedColor = HSVColor.fromAHSV(hsv.alpha, hsv.hue, value / 100, hsv.value).toColor();
              });
            },
          ),

          _ColorSlider(
            label: '亮度',
            value: _hsvColorFromColor(_selectedColor).value * 100,
            max: 100,
            onChanged: (value) {
              setState(() {
                final hsv = _hsvColorFromColor(_selectedColor);
                _selectedColor = HSVColor.fromAHSV(hsv.alpha, hsv.hue, hsv.saturation, value / 100).toColor();
              });
            },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () {
            widget.onColorSelected(_colorToHex(_selectedColor));
          },
          child: const Text('确定'),
        ),
      ],
    );
  }

  Color _parseColorHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) {
      buffer.write('ff');
    }
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  String _colorToHex(Color color) {
    return '#${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  HSVColor _hsvColorFromColor(Color color) {
    return HSVColor.fromColor(color);
  }
}

/// A color slider with label.
class _ColorSlider extends StatelessWidget {
  final String label;
  final double value;
  final double max;
  final void Function(double) onChanged;

  const _ColorSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 60,
          child: Text(label),
        ),
        Expanded(
          child: Slider(
            value: value,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

/// Helper function to show color picker popup.
void showColorPickerPopup({
  required BuildContext context,
  required String currentColor,
  required void Function(String colorHex) onColorSelected,
}) {
  final overlay = Overlay.of(context);
  final renderBox = context.findRenderObject() as RenderBox?;
  if (renderBox == null) return;

  final position = renderBox.localToGlobal(Offset.zero);

  OverlayEntry? entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: position.dx,
      top: position.dy + renderBox.size.height,
      child: ColorPickerPopup(
        currentColor: currentColor,
        onColorSelected: (colorHex) {
          onColorSelected(colorHex);
          entry?.remove();
        },
      ),
    ),
  );

  overlay.insert(entry);
}