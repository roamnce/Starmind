import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Floating toolbar that appears above selected text.
///
/// Contains:
/// - "Highlight" and "Underline" actions.
/// - 4 customizable preset colors (long-press to customize).
/// - Palette button to select custom colors from a popover.
class PdfSelectionToolbar extends StatefulWidget {
  final Offset position;
  final VoidCallback onDismiss;
  final ValueChanged<Color> onHighlight;
  final ValueChanged<Color> onUnderline;
  final String documentId;

  const PdfSelectionToolbar({
    super.key,
    required this.position,
    required this.onDismiss,
    required this.onHighlight,
    required this.onUnderline,
    this.documentId = '',
  });

  @override
  State<PdfSelectionToolbar> createState() => _PdfSelectionToolbarState();
}

class _PdfSelectionToolbarState extends State<PdfSelectionToolbar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  List<Color> _presetColors = [
    const Color(0xFFFFD60A), // Yellow
    const Color(0xFF30D158), // Green
    const Color(0xFF0A84FF), // Blue
    const Color(0xFFFF375F), // Pink/Red
  ];
  Color _activeColor = const Color(0xFFFFD60A);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
    _loadPresetColors();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadPresetColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorsList = prefs.getStringList('starmind_preset_colors');
      if (colorsList != null && colorsList.length == 4) {
        setState(() {
          _presetColors = colorsList.map((c) => Color(int.parse(c))).toList();
          _activeColor = _presetColors.first;
        });
      }
    } catch (e) {
      debugPrint('Error loading preset colors: $e');
    }
  }

  Future<void> _savePresetColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorsList = _presetColors.map((c) => c.toARGB32().toString()).toList();
      await prefs.setStringList('starmind_preset_colors', colorsList);
    } catch (e) {
      debugPrint('Error saving preset colors: $e');
    }
  }

  void _showColorPickerPopover(BuildContext context, Offset buttonPosition, int? indexToUpdate) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _ColorPickerPopoverOverlay(
        position: buttonPosition,
        currentColor: indexToUpdate != null ? _presetColors[indexToUpdate] : _activeColor,
        onDismiss: () {
          entry.remove();
        },
        onColorSelected: (color) {
          entry.remove();
          if (indexToUpdate != null) {
            setState(() {
              _presetColors[indexToUpdate] = color;
              _activeColor = color;
            });
            _savePresetColors();
            // Automatically apply the changed color to the highlight
            widget.onHighlight(color);
          } else {
            // Apply custom highlight directly
            widget.onHighlight(color);
          }
        },
      ),
    );

    overlay.insert(entry);
  }

  Widget _buildPresetColorButton(BuildContext context, int index) {
    final color = _presetColors[index];
    final isSelected = _activeColor.toARGB32() == color.toARGB32();

    return GestureDetector(
      onTap: () {
        setState(() {
          _activeColor = color;
        });
        widget.onHighlight(color);
      },
      onLongPressStart: (details) {
        _showColorPickerPopover(context, details.globalPosition, index);
      },
      child: Container(
        width: 26,
        height: 26,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.5),
            width: isSelected ? 2.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: isSelected ? 6 : 3,
              spreadRadius: isSelected ? 1 : 0,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned(
      left: widget.position.dx - 180, // Offset to center the toolbar
      top: widget.position.dy - 55,  // Position slightly above the target point
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          type: MaterialType.transparency,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF161520).withOpacity(0.85) : Colors.white.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Highlight Action
                    Tooltip(
                      message: '高亮',
                      child: TextButton.icon(
                        onPressed: () => widget.onHighlight(_activeColor),
                        style: TextButton.styleFrom(
                          foregroundColor: _activeColor,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: const Icon(Icons.border_color_rounded, size: 16),
                        label: const Text(
                          '高亮',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Underline Action
                    Tooltip(
                      message: '下划线',
                      child: TextButton.icon(
                        onPressed: () => widget.onUnderline(_activeColor),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.format_underlined_rounded, size: 16, color: _activeColor),
                        label: Text(
                          '下划线',
                          style: TextStyle(
                            fontSize: 12, 
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),
                    Container(
                      height: 18,
                      width: 1.0,
                      color: isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.12),
                    ),
                    const SizedBox(width: 6),

                    // 4 Preset Colors
                    ...List.generate(4, (index) => _buildPresetColorButton(context, index)),

                    const SizedBox(width: 4),

                    // Palette / Color Picker Button
                    GestureDetector(
                      onTapDown: (details) {
                        _showColorPickerPopover(context, details.globalPosition, null);
                      },
                      child: Tooltip(
                        message: '调色板',
                        child: Container(
                          width: 26,
                          height: 26,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.05),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.palette_outlined,
                            size: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Close Button
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black.withOpacity(0.5),
                        size: 18,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: widget.onDismiss,
                      splashRadius: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



class _ColorPickerPopoverOverlay extends StatelessWidget {
  final Offset position;
  final Color currentColor;
  final VoidCallback onDismiss;
  final ValueChanged<Color> onColorSelected;

  const _ColorPickerPopoverOverlay({
    required this.position,
    required this.currentColor,
    required this.onDismiss,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final popoverWidth = 240.0;
    final popoverHeight = 150.0;

    double left = position.dx - popoverWidth / 2;
    left = left.clamp(8.0, mediaQuery.size.width - popoverWidth - 8.0);

    double top = position.dy + 12.0;
    if (top + popoverHeight > mediaQuery.size.height) {
      top = position.dy - popoverHeight - 12.0;
    }

    final gridColors = [
      const Color(0xFFFFD60A), // Yellow
      const Color(0xFF30D158), // Green
      const Color(0xFF0A84FF), // Blue
      const Color(0xFFFF375F), // Pink/Red
      const Color(0xFFBF5AF2), // Purple
      const Color(0xFFFF9F0A), // Orange
      const Color(0xFF64D2FF), // Cyan
      const Color(0xFFE5E5EA), // Light Grey
      const Color(0xFF34C759), // Darker Green
      const Color(0xFF5856D6), // Darker Purple
      const Color(0xFFFF2D55), // Red/Pink
      const Color(0xFFAF52DE), // Violet
    ];

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: onDismiss,
          child: Container(color: Colors.transparent),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(16),
            type: MaterialType.transparency,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  width: popoverWidth,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2E).withOpacity(0.9) : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '选择颜色',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: gridColors.map((color) {
                          final isSelected = color.toARGB32() == currentColor.toARGB32();
                          return GestureDetector(
                            onTap: () => onColorSelected(color),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : Colors.black87)
                                      : Colors.white.withOpacity(0.8),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withOpacity(0.25),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
