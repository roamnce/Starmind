import 'package:flutter/material.dart';

/// Floating toolbar that appears after text selection.
///
/// Shows buttons for creating different annotation types:
/// - Highlight
/// - Underline
/// - Wave line
/// - Note
///
/// Also provides access to color picker.
class AnnotationToolbar extends StatelessWidget {
  final Offset position;
  final VoidCallback onClose;
  final void Function(String colorHex) onHighlight;
  final void Function(String colorHex) onUnderline;
  final void Function(String colorHex) onWave;
  final VoidCallback onNote;
  final String currentColor;

  const AnnotationToolbar({
    super.key,
    required this.position,
    required this.onClose,
    required this.onHighlight,
    required this.onUnderline,
    required this.onWave,
    required this.onNote,
    this.currentColor = '#FFFF00',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _parseColorHex(currentColor);

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Highlight button
              _ToolButton(
                icon: Icons.highlight,
                color: color,
                tooltip: '高亮',
                onPressed: () => onHighlight(currentColor),
              ),

              // Underline button
              _ToolButton(
                icon: Icons.format_underline,
                color: color,
                tooltip: '下划线',
                onPressed: () => onUnderline(currentColor),
              ),

              // Wave button
              _ToolButton(
                icon: Icons.show_chart,
                color: color,
                tooltip: '波浪线',
                onPressed: () => onWave(currentColor),
              ),

              const SizedBox(width: 4),
              Container(
                width: 1,
                height: 24,
                color: theme.colorScheme.outline.withOpacity(0.3),
              ),
              const SizedBox(width: 4),

              // Note button
              _ToolButton(
                icon: Icons.note_add,
                color: color,
                tooltip: '笔记',
                onPressed: onNote,
              ),

              const SizedBox(width: 4),

              // Color picker trigger
              Builder(
                builder: (context) => _ColorButton(
                  currentColor: color,
                  onTap: () => _showColorPicker(context),
                ),
              ),

              const SizedBox(width: 4),

              // Close button
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: onClose,
                tooltip: '关闭',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorPicker(BuildContext context) {
    // Color picker will be implemented in the next task
    // For now, just show a simple dialog
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        currentColor: currentColor,
        onColorSelected: (colorHex) {
          Navigator.of(context).pop();
        },
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

/// Tool button with colored background.
class _ToolButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  const _ToolButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      color: color,
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(
        minWidth: 36,
        minHeight: 36,
      ),
    );
  }
}

/// Color button showing current color.
class _ColorButton extends StatelessWidget {
  final Color currentColor;
  final VoidCallback onTap;

  const _ColorButton({
    required this.currentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: currentColor,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Color picker dialog with preset colors.
class ColorPickerDialog extends StatelessWidget {
  final String currentColor;
  final void Function(String colorHex) onColorSelected;

  const ColorPickerDialog({
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
    '#E91E63', // Pink
    '#00BCD4', // Cyan
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('选择颜色'),
      content: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: presetColors.map((colorHex) {
          final color = _parseColorHex(colorHex);
          final isSelected = colorHex == currentColor;

          return GestureDetector(
            onTap: () => onColorSelected(colorHex),
            child: Container(
              width: 40,
              height: 40,
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
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
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
        TextButton(
          onPressed: () {
            // TODO: Open full color picker
            Navigator.of(context).pop();
          },
          child: const Text('自定义...'),
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
}