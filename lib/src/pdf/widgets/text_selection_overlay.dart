import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Floating toolbar that appears above/below selected text.
///
/// Features:
/// - Dynamic arrow direction (points to selected text)
/// - "Highlight" and "Underline" actions
/// - 4 customizable preset colors (long-press to customize)
/// - Palette button to select custom colors from a popover
/// - No close button (tap outside to dismiss)
class PdfSelectionToolbar extends StatefulWidget {
  final Offset selectionCenter;
  final double selectionTop;
  final double selectionBottom;
  final double screenWidth;
  final double screenHeight;
  final VoidCallback onDismiss;
  final ValueChanged<Color> onHighlight;
  final ValueChanged<Color> onUnderline;
  final String documentId;

  const PdfSelectionToolbar({
    super.key,
    required this.selectionCenter,
    required this.selectionTop,
    required this.selectionBottom,
    required this.screenWidth,
    required this.screenHeight,
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

  // Arrow direction: true means arrow on top (menu below text), false means arrow on bottom (menu above text)
  bool _arrowOnTop = false;

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
    _calculatePosition();
  }

  void _calculatePosition() {
    // Toolbar dimensions
    const toolbarHeight = 52.0;
    const arrowHeight = 8.0;

    // Calculate available space above and below selection
    final safeTopMargin = 60.0;
    final safeBottomMargin = 40.0;

    // Use actual selection positions (not clamped) to determine direction
    // This ensures the toolbar appears on the correct side of the selection
    final spaceAbove = widget.selectionTop - safeTopMargin;
    final spaceBelow = widget.screenHeight - widget.selectionBottom - safeBottomMargin;
    final spaceNeededAbove = toolbarHeight + arrowHeight;
    final spaceNeededBelow = toolbarHeight + arrowHeight;

    // Decide arrow direction based on available space
    // Prefer showing toolbar above selection (more natural for reading)
    // Only show below if there's not enough space above
    if (spaceAbove >= spaceNeededAbove) {
      _arrowOnTop = false; // Toolbar above, arrow points down
    } else if (spaceBelow >= spaceNeededBelow) {
      _arrowOnTop = true; // Toolbar below, arrow points up
    } else {
      // Not enough space on either side, choose the side with more space
      _arrowOnTop = spaceBelow > spaceAbove;
    }
  }

  Offset _getToolbarPosition() {
    const toolbarWidth = 360.0;
    const toolbarHeight = 52.0;
    const arrowHeight = 8.0;
    const safeTopMargin = 60.0;
    const safeBottomMargin = 40.0;

    // Calculate horizontal position (center on selection)
    double centerX = widget.selectionCenter.dx - toolbarWidth / 2;
    centerX = centerX.clamp(8.0, widget.screenWidth - toolbarWidth - 8.0);

    // Calculate vertical position based on arrow direction
    double toolbarY;
    if (_arrowOnTop) {
      // Toolbar below selection, arrow on top pointing up to text
      toolbarY = widget.selectionBottom + arrowHeight;
    } else {
      // Toolbar above selection, arrow on bottom pointing down to text
      toolbarY = widget.selectionTop - toolbarHeight - arrowHeight;
    }

    // Final clamp to ensure toolbar stays within screen bounds
    // But prioritize being close to the selection
    toolbarY = toolbarY.clamp(safeTopMargin, widget.screenHeight - toolbarHeight - safeBottomMargin);

    return Offset(centerX, toolbarY);
  }

  Offset _getArrowPosition() {
    final toolbarPos = _getToolbarPosition();
    const toolbarWidth = 360.0;
    const arrowHeight = 8.0;
    const toolbarHeight = 52.0;

    // Arrow should point to selection center horizontally
    double arrowX = widget.selectionCenter.dx;
    // Clamp arrow to be within toolbar bounds
    final minX = toolbarPos.dx + 20;
    final maxX = toolbarPos.dx + toolbarWidth - 20;
    arrowX = arrowX.clamp(minX, maxX);

    // Arrow Y position: on the side of toolbar that faces the selection
    double arrowY;
    if (_arrowOnTop) {
      // Arrow on top of toolbar, pointing up to selection above
      arrowY = toolbarPos.dy - arrowHeight;
    } else {
      // Arrow on bottom of toolbar, pointing down to selection below
      arrowY = toolbarPos.dy + toolbarHeight;
    }

    return Offset(arrowX, arrowY);
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
            widget.onHighlight(color);
          } else {
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
        width: 24,
        height: 24,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.5),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: isSelected ? 4 : 2,
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
    final toolbarPos = _getToolbarPosition();
    final arrowPos = _getArrowPosition();

    return Stack(
      children: [
        // Arrow pointing to selection
        Positioned(
          left: arrowPos.dx - 10,
          top: arrowPos.dy,
          child: CustomPaint(
            size: const Size(20, 8),
            painter: _ArrowPainter(
              color: isDark ? const Color(0xFF161520).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
              arrowOnTop: _arrowOnTop,
            ),
          ),
        ),
        // Main toolbar
        Positioned(
          left: toolbarPos.dx,
          top: toolbarPos.dy,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Material(
              type: MaterialType.transparency,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161520).withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Highlight Action - icon only
                        _CompactToolButton(
                          icon: Icons.border_color_rounded,
                          color: _activeColor,
                          onPressed: () => widget.onHighlight(_activeColor),
                        ),

                        const SizedBox(width: 4),

                        // Underline Action - icon only
                        _CompactToolButton(
                          icon: Icons.format_underlined_rounded,
                          color: _activeColor,
                          onPressed: () => widget.onUnderline(_activeColor),
                        ),

                        const SizedBox(width: 4),
                        Container(
                          height: 16,
                          width: 1.0,
                          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.12),
                        ),
                        const SizedBox(width: 4),

                        // 4 Preset Colors
                        ...List.generate(4, (index) => _buildPresetColorButton(context, index)),

                        const SizedBox(width: 4),

                        // Palette / Color Picker Button
                        GestureDetector(
                          onTapDown: (details) {
                            _showColorPickerPopover(context, details.globalPosition, null);
                          },
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.palette_outlined,
                              size: 14,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
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

/// Compact tool button with icon only.
class _CompactToolButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _CompactToolButton({
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}

/// Arrow painter for the toolbar.
class _ArrowPainter extends CustomPainter {
  final Color color;
  final bool arrowOnTop;

  _ArrowPainter({
    required this.color,
    required this.arrowOnTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    if (arrowOnTop) {
      // Arrow pointing up (triangle with tip at top)
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.close();
    } else {
      // Arrow pointing down (triangle with tip at bottom)
      path.moveTo(0, 0);
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.arrowOnTop != arrowOnTop;
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
                    color: isDark ? const Color(0xFF1E1E2E).withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
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
                                      : Colors.white.withValues(alpha: 0.8),
                                  width: isSelected ? 2.5 : 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.25),
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