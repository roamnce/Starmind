import 'package:flutter/material.dart';
import 'mermaid/widgets/mermaid_diagram.dart' as mermaid_widgets;

/// Renders Mermaid diagrams in the card overlay.
///
/// Delegates to the marktext-plus Mermaid engine for drawing.
class MermaidRenderer extends StatelessWidget {
  /// The Mermaid diagram source code (without ``` fences).
  final String definition;

  /// Maximum width constraint for the rendered widget.
  final double maxWidth;

  const MermaidRenderer({
    super.key,
    required this.definition,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: maxWidth,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x0FFFFFFF),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x1AFFFFFF)),
      ),
      child: mermaid_widgets.MermaidDiagram(
        code: definition,
        width: maxWidth - 16,
      ),
    );
  }
}
