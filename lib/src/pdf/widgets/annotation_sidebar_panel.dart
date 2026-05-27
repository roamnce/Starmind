import 'package:flutter/material.dart';
import 'package:starmind/src/domain/annotation.dart';
import 'package:starmind/src/pdf/annotation_controller.dart';

/// Sidebar panel for viewing and managing all annotations.
///
/// Features:
/// - Grouped by page
/// - Filter by type
/// - Navigation to annotation location
/// - Delete/edit actions
class AnnotationSidebarPanel extends StatefulWidget {
  final AnnotationController annotationController;
  final int currentPageIndex;
  final void Function(int pageIndex, Annotation annotation)? onNavigate;

  const AnnotationSidebarPanel({
    super.key,
    required this.annotationController,
    required this.currentPageIndex,
    this.onNavigate,
  });

  @override
  State<AnnotationSidebarPanel> createState() => _AnnotationSidebarPanelState();
}

class _AnnotationSidebarPanelState extends State<AnnotationSidebarPanel> {
  AnnotationType? _filterType;
  bool _showCurrentPageOnly = false;

  @override
  void initState() {
    super.initState();
    widget.annotationController.addListener(_onAnnotationsChanged);
  }

  @override
  void dispose() {
    widget.annotationController.removeListener(_onAnnotationsChanged);
    super.dispose();
  }

  void _onAnnotationsChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final annotations = _getFilteredAnnotations();

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
        children: [
          _buildHeader(theme),
          _buildFilters(theme),
          Expanded(
            child: annotations.isEmpty
                ? _buildEmptyState(theme)
                : _buildAnnotationList(theme, annotations),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.note_alt,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            '注释',
            style: theme.textTheme.titleMedium,
          ),
          const Spacer(),
          Text(
            '${widget.annotationController.annotations.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Type filter dropdown
          Expanded(
            child: _buildTypeFilterDropdown(theme),
          ),
          const SizedBox(width: 8),
          // Current page toggle
          FilterChip(
            label: const Text('当前页'),
            selected: _showCurrentPageOnly,
            onSelected: (selected) {
              setState(() {
                _showCurrentPageOnly = selected;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTypeFilterDropdown(ThemeData theme) {
    return DropdownButton<AnnotationType?>(
      value: _filterType,
      isExpanded: true,
      hint: const Text('全部类型'),
      items: [
        const DropdownMenuItem(
          value: null,
          child: Text('全部类型'),
        ),
        DropdownMenuItem(
          value: AnnotationType.highlight,
          child: Row(
            children: [
              Icon(Icons.highlight, size: 16),
              const SizedBox(width: 8),
              const Text('高亮'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: AnnotationType.underline,
          child: Row(
            children: [
              Icon(Icons.format_underlined, size: 16),
              const SizedBox(width: 8),
              const Text('下划线'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: AnnotationType.wave,
          child: Row(
            children: [
              Icon(Icons.show_chart, size: 16),
              const SizedBox(width: 8),
              const Text('波浪线'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: AnnotationType.ink,
          child: Row(
            children: [
              Icon(Icons.edit, size: 16),
              const SizedBox(width: 8),
              const Text('墨迹'),
            ],
          ),
        ),
        DropdownMenuItem(
          value: AnnotationType.note,
          child: Row(
            children: [
              Icon(Icons.note, size: 16),
              const SizedBox(width: 8),
              const Text('笔记'),
            ],
          ),
        ),
      ],
      onChanged: (type) {
        setState(() {
          _filterType = type;
        });
      },
    );
  }

  List<Annotation> _getFilteredAnnotations() {
    var annotations = widget.annotationController.annotations;

    if (_filterType != null) {
      annotations = annotations.where((a) => a.type == _filterType).toList();
    }

    if (_showCurrentPageOnly) {
      annotations = annotations.where((a) => a.pageIndex == widget.currentPageIndex).toList();
    }

    return annotations;
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.note_add,
            size: 48,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无注释',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnotationList(ThemeData theme, List<Annotation> annotations) {
    final groupedAnnotations = _groupByPage(annotations);

    return ListView.builder(
      itemCount: groupedAnnotations.length,
      itemBuilder: (context, index) {
        final pageGroup = groupedAnnotations[index];
        return _buildPageGroup(theme, pageGroup);
      },
    );
  }

  List<_PageAnnotationGroup> _groupByPage(List<Annotation> annotations) {
    final Map<int, List<Annotation>> pageMap = {};

    for (final annotation in annotations) {
      pageMap.putIfAbsent(annotation.pageIndex, () => []);
      pageMap[annotation.pageIndex]!.add(annotation);
    }

    return pageMap.entries
        .map((e) => _PageAnnotationGroup(pageIndex: e.key, annotations: e.value))
        .toList()
        ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
  }

  Widget _buildPageGroup(ThemeData theme, _PageAnnotationGroup group) {
    final isCurrentPage = group.pageIndex == widget.currentPageIndex;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Page header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isCurrentPage
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
              : null,
          child: Row(
            children: [
              Text(
                '第 ${group.pageIndex + 1} 页',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: isCurrentPage
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${group.annotations.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),

        // Annotation items
        for (final annotation in group.annotations)
          _buildAnnotationItem(theme, annotation),

        const Divider(height: 1),
      ],
    );
  }

  Widget _buildAnnotationItem(ThemeData theme, Annotation annotation) {
    final typeIcon = _getTypeIcon(annotation.type);
    final typeLabel = _getTypeLabel(annotation.type);
    final preview = _getPreviewText(annotation);

    return ListTile(
      dense: true,
      leading: Icon(
        typeIcon,
        size: 20,
        color: _parseColor(annotation.colorHex),
      ),
      title: Text(typeLabel),
      subtitle: preview != null ? Text(preview, maxLines: 1) : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Navigate button
          if (widget.onNavigate != null)
            IconButton(
              icon: const Icon(Icons.location_searching),
              iconSize: 18,
              tooltip: '定位',
              onPressed: () {
                widget.onNavigate?.call(annotation.pageIndex, annotation);
              },
            ),
          // Delete button
          IconButton(
            icon: const Icon(Icons.delete),
            iconSize: 18,
            tooltip: '删除',
            onPressed: () {
              _deleteAnnotation(annotation);
            },
          ),
        ],
      ),
      onTap: () {
        widget.onNavigate?.call(annotation.pageIndex, annotation);
      },
    );
  }

  IconData _getTypeIcon(AnnotationType type) {
    switch (type) {
      case AnnotationType.highlight:
        return Icons.highlight;
      case AnnotationType.underline:
        return Icons.format_underlined;
      case AnnotationType.wave:
        return Icons.show_chart;
      case AnnotationType.strikeOut:
        return Icons.strikethrough_s;
      case AnnotationType.ink:
        return Icons.edit;
      case AnnotationType.note:
        return Icons.note;
    }
  }

  String _getTypeLabel(AnnotationType type) {
    switch (type) {
      case AnnotationType.highlight:
        return '高亮';
      case AnnotationType.underline:
        return '下划线';
      case AnnotationType.wave:
        return '波浪线';
      case AnnotationType.strikeOut:
        return '删除线';
      case AnnotationType.ink:
        return '墨迹';
      case AnnotationType.note:
        return '笔记';
    }
  }

  String? _getPreviewText(Annotation annotation) {
    switch (annotation.type) {
      case AnnotationType.highlight:
      case AnnotationType.underline:
      case AnnotationType.wave:
      case AnnotationType.strikeOut:
        return annotation.selectedText;
      case AnnotationType.ink:
        return '${annotation.strokes?.length ?? 0} 条笔画';
      case AnnotationType.note:
        return annotation.noteContent ?? '空笔记';
    }
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  void _deleteAnnotation(Annotation annotation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除注释'),
        content: Text('确定要删除此${_getTypeLabel(annotation.type)}吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              widget.annotationController.deleteAnnotation(annotation.id);
              Navigator.of(context).pop();
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }
}

class _PageAnnotationGroup {
  final int pageIndex;
  final List<Annotation> annotations;

  _PageAnnotationGroup({
    required this.pageIndex,
    required this.annotations,
  });
}