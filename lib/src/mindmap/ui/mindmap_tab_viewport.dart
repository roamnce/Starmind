import 'package:flutter/material.dart';
import 'package:starmind/src/pdf/pdf_viewport_controller.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/ui/mindmap_page.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/ffi_mindmap_repository.dart';
import 'package:starmind/src/home/workspace_controller.dart';
import 'package:starmind/src/home/workspace_controller_provider.dart';
import 'package:starmind/src/pdf/widgets/pdf_tab_viewport.dart';

/// A tab viewport widget that displays a mindmap with optional split panel support.
///
/// Supports splitting the view to show a PDF or another mindmap side by side.
class MindMapTabViewport extends StatefulWidget {
  /// The topic ID of the mindmap to display.
  final String topicId;

  /// The title of the mindmap tab.
  final String title;

  /// The controller managing the mindmap state.
  final MindMapController controller;

  /// Creates a [MindMapTabViewport].
  const MindMapTabViewport({
    super.key,
    required this.topicId,
    required this.title,
    required this.controller,
  });

  @override
  State<MindMapTabViewport> createState() => _MindMapTabViewportState();
}

class _MindMapTabViewportState extends State<MindMapTabViewport> {
  final Map<String, PdfViewportController> _splitPdfControllers = {};
  final Map<String, MindMapController> _splitMindMapControllers = {};

  // Cache workspace controller to avoid accessing deactivated context in build()
  WorkspaceController? _workspaceController;
  bool _isDark = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Safely capture workspaceController in didChangeDependencies
    _workspaceController = context.maybeWorkspaceController;
    _isDark = _workspaceController?.isDarkMode ?? true;
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onMindMapChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onMindMapChanged);
    for (final ctrl in _splitPdfControllers.values) {
      ctrl.dispose();
    }
    for (final ctrl in _splitMindMapControllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _onMindMapChanged() {
    if (mounted) setState(() {});
  }

  PdfViewportController _getOrBuildSplitPdfController(
    String docId,
    String filePath,
  ) {
    if (!_splitPdfControllers.containsKey(docId)) {
      final ctrl = PdfViewportController();
      ctrl.loadDoc(filePath);
      _splitPdfControllers[docId] = ctrl;
    }
    return _splitPdfControllers[docId]!;
  }

  MindMapController _getOrBuildSplitMindMapController(String topicId) {
    if (!_splitMindMapControllers.containsKey(topicId)) {
      final service = MindMapService(FfiMindMapRepository());
      final ctrl = MindMapController(service, topicId);
      ctrl.loadTopic();
      _splitMindMapControllers[topicId] = ctrl;
    }
    return _splitMindMapControllers[topicId]!;
  }

  @override
  Widget build(BuildContext context) {
    // Use cached _isDark instead of accessing context.workspaceController
    // to avoid "Looking up a deactivated widget's ancestor is unsafe" error
    final isDark = _isDark;
    final splitType = widget.controller.splitType;
    final splitId = widget.controller.splitId;
    final splitFilePath = widget.controller.splitFilePath;

    Widget buildViewport() {
      if (splitType == null || splitId == null) {
        return MindMapPage(controller: widget.controller);
      }

      if (splitType == 'pdf') {
        final pdfCtrl = _getOrBuildSplitPdfController(
          splitId,
          splitFilePath ?? '',
        );
        return Row(
          children: [
            Expanded(child: MindMapPage(controller: widget.controller)),
            const VerticalDivider(width: 1, color: Color(0x1F2A3547)),
            Expanded(
              child: PdfTabViewport(
                docId: splitId,
                filePath: splitFilePath ?? '',
                pdfController: pdfCtrl,
              ),
            ),
          ],
        );
      }

      if (splitType == 'mindmap') {
        final mindmapCtrl = _getOrBuildSplitMindMapController(splitId);
        return Row(
          children: [
            Expanded(child: MindMapPage(controller: widget.controller)),
            const VerticalDivider(width: 1, color: Color(0x1F2A3547)),
            Expanded(child: MindMapPage(controller: mindmapCtrl)),
          ],
        );
      }

      return MindMapPage(controller: widget.controller);
    }

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0C0A07)
          : const Color(0xFFFAF8F5),
      body: buildViewport(),
    );
  }
}
