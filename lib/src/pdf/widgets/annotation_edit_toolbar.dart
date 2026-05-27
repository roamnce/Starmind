import 'package:flutter/material.dart';
import 'package:starmind/src/domain/annotation.dart';

/// Floating toolbar for editing existing annotations.
///
/// Appears when an annotation is tapped/selected, providing:
/// - Color change
/// - Delete
/// - Edit content (for note annotations)
class AnnotationEditToolbar extends StatelessWidget {
  final Annotation annotation;
  final VoidCallback onDelete;
  final VoidCallback? onColorChange;
  final VoidCallback? onEditContent;
  final VoidCallback onClose;

  const AnnotationEditToolbar({
    super.key,
    required this.annotation,
    required this.onDelete,
    this.onColorChange,
    this.onEditContent,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Color change button (for highlight/underline/wave/ink)
            if (onColorChange != null && annotation.type != AnnotationType.note)
              _buildIconButton(
                context,
                icon: Icons.palette,
                tooltip: '更改颜色',
                onTap: onColorChange!,
              ),

            // Edit content button (for note annotations)
            if (onEditContent != null && annotation.type == AnnotationType.note)
              _buildIconButton(
                context,
                icon: Icons.edit,
                tooltip: '编辑内容',
                onTap: onEditContent!,
              ),

            // Delete button
            _buildIconButton(
              context,
              icon: Icons.delete,
              tooltip: '删除',
              onTap: onDelete,
              color: theme.colorScheme.error,
            ),

            const SizedBox(width: 4),
            Container(
              width: 1,
              height: 24,
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
            const SizedBox(width: 4),

            // Close button
            _buildIconButton(
              context,
              icon: Icons.close,
              tooltip: '关闭',
              onTap: onClose,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: color ?? theme.colorScheme.onSurface,
        ),
      ),
    );
  }
}