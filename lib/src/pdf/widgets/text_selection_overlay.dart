/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

import 'dart:ui';
import 'package:flutter/material.dart';

class PdfSelectionToolbar extends StatefulWidget {
  final Offset position;
  final VoidCallback onDismiss;
  final ValueChanged<Color> onHighlight;
  final VoidCallback onExcerpt;

  const PdfSelectionToolbar({
    super.key,
    required this.position,
    required this.onDismiss,
    required this.onHighlight,
    required this.onExcerpt,
  });

  @override
  State<PdfSelectionToolbar> createState() => _PdfSelectionToolbarState();
}

class _PdfSelectionToolbarState extends State<PdfSelectionToolbar> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Widget _buildColorDot(Color color, String name) {
    return Tooltip(
      message: name,
      child: GestureDetector(
        onTap: () => widget.onHighlight(color),
        child: Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.4),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.position.dx - 120, // Center the toolbar horizontally (roughly)
      top: widget.position.dy,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          type: MaterialType.transparency,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF161520).withOpacity(0.85),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Markup Colors
                    _buildColorDot(const Color(0xFFFFD60A), 'Yellow'),
                    _buildColorDot(const Color(0xFF30D158), 'Green'),
                    _buildColorDot(const Color(0xFF0A84FF), 'Blue'),
                    _buildColorDot(const Color(0xFFFF375F), 'Pink'),
                    
                    const SizedBox(width: 8),
                    Container(
                      height: 20,
                      width: 1.5,
                      color: Colors.white.withOpacity(0.15),
                    ),
                    const SizedBox(width: 8),

                    // Excerpt Button
                    TextButton.icon(
                      onPressed: widget.onExcerpt,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFFFC800),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: const Icon(
                        Icons.format_indent_increase_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        'Excerpt',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        color: Colors.white.withOpacity(0.6),
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
