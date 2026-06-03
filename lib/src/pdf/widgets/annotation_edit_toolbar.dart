import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:starmind/src/domain/annotation.dart';

/// Floating toolbar for editing existing annotations.
///
/// Features:
/// - Appears when an annotation is tapped/selected
/// - Color change (for highlight/underline/wave/ink)
/// - Delete annotation
/// - Edit content (for note annotations)
/// - Dynamic arrow pointing to annotation
/// - Compact, glassmorphic design
class AnnotationEditToolbar extends StatefulWidget {
  final Annotation annotation;
  final Offset annotationCenter;
  final double annotationTop;
  final double annotationBottom;
  final double screenWidth;
  final double screenHeight;
  final VoidCallback onDelete;
  final VoidCallback? onColorChange;
  final VoidCallback? onEditContent;
  final VoidCallback onClose;

  const AnnotationEditToolbar({
    super.key,
    required this.annotation,
    required this.annotationCenter,
    required this.annotationTop,
    required this.annotationBottom,
    required this.screenWidth,
    required this.screenHeight,
    required this.onDelete,
    this.onColorChange,
    this.onEditContent,
    required this.onClose,
  });

  @override
  State<AnnotationEditToolbar> createState() => _AnnotationEditToolbarState();
}

class _AnnotationEditToolbarState extends State<AnnotationEditToolbar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
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
    _calculatePosition();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _calculatePosition() {
    const toolbarHeight = 48.0;
    const arrowHeight = 8.0;
    const marginFromAnnotation = 12.0;

    final spaceAbove = widget.annotationTop;
    final spaceNeededAbove = toolbarHeight + arrowHeight + marginFromAnnotation;

    _arrowOnTop = spaceAbove < spaceNeededAbove;
  }

  Offset _getToolbarPosition() {
    const toolbarWidth = 200.0;
    const toolbarHeight = 48.0;
    const arrowHeight = 8.0;
    const marginFromAnnotation = 12.0;

    double centerX = widget.annotationCenter.dx - toolbarWidth / 2;
    centerX = centerX.clamp(8.0, widget.screenWidth - toolbarWidth - 8.0);

    double toolbarY;
    if (_arrowOnTop) {
      toolbarY = widget.annotationBottom + marginFromAnnotation + arrowHeight;
    } else {
      toolbarY = widget.annotationTop - toolbarHeight - marginFromAnnotation - arrowHeight;
    }

    return Offset(centerX, toolbarY);
  }

  Offset _getArrowPosition() {
    final toolbarPos = _getToolbarPosition();
    const toolbarWidth = 200.0;

    double arrowX = widget.annotationCenter.dx;
    final minX = toolbarPos.dx + 20;
    final maxX = toolbarPos.dx + toolbarWidth - 20;
    arrowX = arrowX.clamp(minX, maxX);

    double arrowY;
    if (_arrowOnTop) {
      arrowY = toolbarPos.dy - 8;
    } else {
      arrowY = toolbarPos.dy + 48;
    }

    return Offset(arrowX, arrowY);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final toolbarPos = _getToolbarPosition();
    final arrowPos = _getArrowPosition();

    return Stack(
      children: [
        // Dismiss on tap outside
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: Container(color: Colors.transparent),
          ),
        ),
        // Arrow pointing to annotation
        Positioned(
          left: arrowPos.dx - 10,
          top: arrowPos.dy,
          child: CustomPaint(
            size: const Size(20, 8),
            painter: _ArrowPainter(
              color: isDark
                  ? const Color(0xFF161520).withValues(alpha: 0.85)
                  : Colors.white.withValues(alpha: 0.85),
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
                borderRadius: BorderRadius.circular(12),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF161520).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.08),
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
                        // Color change button (for highlight/underline/wave/ink)
                        if (widget.onColorChange != null &&
                            widget.annotation.type != AnnotationType.note)
                          _CompactToolButton(
                            icon: Icons.palette_rounded,
                            tooltip: '更改颜色',
                            onPressed: widget.onColorChange!,
                          ),

                        // Edit content button (for note annotations)
                        if (widget.onEditContent != null &&
                            widget.annotation.type == AnnotationType.note)
                          _CompactToolButton(
                            icon: Icons.edit_rounded,
                            tooltip: '编辑内容',
                            onPressed: widget.onEditContent!,
                          ),

                        // Delete button
                        _CompactToolButton(
                          icon: Icons.delete_rounded,
                          tooltip: '删除',
                          onPressed: widget.onDelete,
                          isDestructive: true,
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

/// Compact tool button for annotation toolbar.
class _CompactToolButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool isDestructive;

  const _CompactToolButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDestructive
        ? Colors.red.shade400
        : (isDark ? Colors.white70 : Colors.black87);

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isDestructive
                ? Colors.red.withValues(alpha: 0.15)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
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
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.close();
    } else {
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