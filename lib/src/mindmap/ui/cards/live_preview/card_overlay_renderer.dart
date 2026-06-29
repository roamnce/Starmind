import 'package:flutter/material.dart';
import 'placeholder_tracker.dart';
import 'rendering/image_renderer.dart';

/// Renders real Flutter widgets (images, code blocks, etc.) at positions
/// matching their placeholder positions in the markdown text.
///
/// This widget sits on top of the [TextField] in a [Stack] and renders
/// overlay widgets at estimated line positions. Precise positioning will
/// be improved later by reading [TextField] layout metrics.
class CardOverlayRenderer extends StatelessWidget {
  /// The full markdown text being edited.
  final String markdown;

  /// Maximum width for rendered content (e.g., images).
  final double maxWidth;

  /// The [PlaceholderTracker] that holds the current set of detected
  /// placeholders.
  final PlaceholderTracker placeholderTracker;

  /// A [GlobalKey] referencing the underlying [TextField] / [EditableText],
  /// used to obtain layout metrics for precise positioning.
  final GlobalKey textFieldKey;

  const CardOverlayRenderer({
    super.key,
    required this.markdown,
    required this.maxWidth,
    required this.placeholderTracker,
    required this.textFieldKey,
  });

  @override
  Widget build(BuildContext context) {
    final placeholders = placeholderTracker.placeholders;
    if (placeholders.isEmpty) return const SizedBox.shrink();

    final textFieldRenderBox =
        textFieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (textFieldRenderBox == null) return const SizedBox.shrink();

    final widgets = <Widget>[];

    for (final p in placeholders) {
      switch (p.type) {
        case 'image':
          final url = _extractUrl(p.rawMarkdown);
          if (url != null) {
            widgets.add(
              Positioned(
                left: 8,
                top: _estimateLineTop(p.lineIndex),
                right: 8,
                child: ImageRenderer(
                  imagePath: url,
                  maxWidth: maxWidth,
                ),
              ),
            );
          }
      }
    }

    if (widgets.isEmpty) return const SizedBox.shrink();

    return Stack(children: widgets);
  }

  /// Extracts the URL/ path from a markdown image syntax `![alt](url)`.
  String? _extractUrl(String rawMarkdown) {
    final re = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
    final m = re.firstMatch(rawMarkdown);
    return m?.group(2);
  }

  /// Approximate vertical position for a placeholder based on its line index.
  ///
  /// Uses a simple formula: `8 + lineIndex * 24`. Precise positioning will
  /// be improved later when the widget integrates with [TextField] layout
  /// metrics via [textFieldKey].
  double _estimateLineTop(int lineIndex) {
    return 8.0 + lineIndex * 24.0;
  }
}
