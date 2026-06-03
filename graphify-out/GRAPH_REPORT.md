# Graph Report - lib/src/pdf + lib/src/mindmap  (2026-06-01)

## Corpus Check
- 58 files ， ~46,365 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 752 nodes ， 819 edges ， 40 communities (38 shown, 2 thin omitted)
- Extraction: 100% EXTRACTED ， 0% INFERRED ， 0% AMBIGUOUS
- Token cost: 0 input ， 0 output

## Community Hubs (Navigation)
- [[_COMMUNITY_MindMap Page & Controller|MindMap Page & Controller]]
- [[_COMMUNITY_Interactive Canvas Viewer|Interactive Canvas Viewer]]
- [[_COMMUNITY_Interactive Canvas Viewer|Interactive Canvas Viewer]]
- [[_COMMUNITY_Pen Configuration|Pen Configuration]]
- [[_COMMUNITY_MindMap Sidebar & Toolbar|MindMap Sidebar & Toolbar]]
- [[_COMMUNITY_Lasso & Topic Card|Lasso & Topic Card]]
- [[_COMMUNITY_MindMap Page & Controller|MindMap Page & Controller]]
- [[_COMMUNITY_Community 7|Community 7]]
- [[_COMMUNITY_Tree Layout & Coordinates|Tree Layout & Coordinates]]
- [[_COMMUNITY_Annotation Sidebar|Annotation Sidebar]]
- [[_COMMUNITY_Ink Canvas Layer|Ink Canvas Layer]]
- [[_COMMUNITY_Ink Toolbar|Ink Toolbar]]
- [[_COMMUNITY_Tile & Cache Manager|Tile & Cache Manager]]
- [[_COMMUNITY_Stroke Cache & Session|Stroke Cache & Session]]
- [[_COMMUNITY_Tree Layout & Coordinates|Tree Layout & Coordinates]]
- [[_COMMUNITY_Color Picker Popup|Color Picker Popup]]
- [[_COMMUNITY_Text Selection Overlay|Text Selection Overlay]]
- [[_COMMUNITY_Annotation Renderer|Annotation Renderer]]
- [[_COMMUNITY_Annotation Edit Toolbar|Annotation Edit Toolbar]]
- [[_COMMUNITY_Annotation Controller|Annotation Controller]]
- [[_COMMUNITY_Viewport Transform|Viewport Transform]]
- [[_COMMUNITY_Annotation Toolbar|Annotation Toolbar]]
- [[_COMMUNITY_Stroke Cache & Session|Stroke Cache & Session]]
- [[_COMMUNITY_PDF Export Service|PDF Export Service]]
- [[_COMMUNITY_MindMap Service & Repository|MindMap Service & Repository]]
- [[_COMMUNITY_Info Statistics Modal|Info Statistics Modal]]
- [[_COMMUNITY_Selection Handles Overlay|Selection Handles Overlay]]
- [[_COMMUNITY_Bottom Action Bar|Bottom Action Bar]]
- [[_COMMUNITY_Lasso & Topic Card|Lasso & Topic Card]]
- [[_COMMUNITY_Community 29|Community 29]]
- [[_COMMUNITY_PDF Viewport Controller|PDF Viewport Controller]]
- [[_COMMUNITY_MindMap Service & Repository|MindMap Service & Repository]]
- [[_COMMUNITY_Tree Layout & Coordinates|Tree Layout & Coordinates]]
- [[_COMMUNITY_MindMap Service & Repository|MindMap Service & Repository]]
- [[_COMMUNITY_MindMap Page & Controller|MindMap Page & Controller]]
- [[_COMMUNITY_Community 35|Community 35]]
- [[_COMMUNITY_Community 36|Community 36]]
- [[_COMMUNITY_Community 37|Community 37]]
- [[_COMMUNITY_Community 38|Community 38]]
- [[_COMMUNITY_Community 39|Community 39]]

## God Nodes (most connected - your core abstractions)
1. `package:flutter/material.dart` - 39 edges
2. `dart:ui` - 14 edges
3. `dart:math` - 8 edges
4. `../domain/note.dart` - 8 edges
5. `package:starmind/src/domain/annotation.dart` - 7 edges
6. `mindmap_controller.dart` - 7 edges
7. `../domain/topic.dart` - 6 edges
8. `dart:convert` - 5 edges
9. `tree_layout.dart` - 5 edges
10. `../service/mindmap_service.dart` - 5 edges

## Surprising Connections (you probably didn't know these)
- None detected - all connections are within the same source files.

## Communities (40 total, 2 thin omitted)

### Community 0 - "MindMap Page & Controller"
Cohesion: 0.04
Nodes (49): bottom_action_bar.dart, canvas_painter.dart, BackdropFilter, build, _buildBreadcrumbBar, _buildCanvas, _buildEmptyState, _buildLassoGestureOverlay (+41 more)

### Community 1 - "Interactive Canvas Viewer"
Cohesion: 0.05
Nodes (39): _alignAxis, build, ClipRect, didUpdateWidget, dispose, _exceedsBy, Function, _gestureIsSupported (+31 more)

### Community 2 - "Interactive Canvas Viewer"
Cohesion: 0.05
Nodes (39): annotation_edit_toolbar.dart, AnnotationEditToolbar, build, _buildLoadingIndicator, _bytesToImage, Center, _checkAnnotationTap, CircularProgressIndicator (+31 more)

### Community 3 - "Pen Configuration"
Cohesion: 0.06
Nodes (33): ballpointPen, copyWith, eraser, fountainPen, fromString, highlighter, pencil, PenConfig (+25 more)

### Community 4 - "MindMap Sidebar & Toolbar"
Cohesion: 0.06
Nodes (34): build, Container, insertMarkdown, MarkdownEditorToolbar, _showMockToast, SizedBox, _ToolbarIconButton, _ToolbarTextButton (+26 more)

### Community 5 - "Lasso & Topic Card"
Cohesion: 0.06
Nodes (29): _drawDashedLine, _drawDashedRect, LassoPainter, paint, shouldRepaint, build, Card, _formatDate (+21 more)

### Community 6 - "MindMap Page & Controller"
Cohesion: 0.06
Nodes (30): changeLayoutDirection, closeSplitScreen, Color, _colorToHex, _colorToRgba, exportThemeToJson, fitToScreen, jsonEncode (+22 more)

### Community 7 - "Community 7"
Cohesion: 0.07
Nodes (27): initialize, PdfService, cancel, cancelPage, clearAll, _notifyNext, RenderScheduler, _RenderTask (+19 more)

### Community 8 - "Tree Layout & Coordinates"
Cohesion: 0.07
Nodes (27): calculateBounds, _calculateSubtreeLayoutHeight, _calculateSubtreeSize, _collectConnections, Connection, _layoutNestedCardChildren, _layoutSubtrees, _layoutSubtreeSingle (+19 more)

### Community 9 - "Annotation Sidebar"
Cohesion: 0.07
Nodes (29): AnnotationSidebarPanel, _AnnotationSidebarPanelState, build, _buildAnnotationItem, _buildAnnotationList, _buildEmptyState, _buildFilters, _buildHeader (+21 more)

### Community 10 - "Ink Canvas Layer"
Cohesion: 0.08
Nodes (25): build, didUpdateWidget, _drawStroke, _eraseStrokesAt, initState, InkCanvasLayer, _InkCanvasLayerState, InkCanvasPainter (+17 more)

### Community 11 - "Ink Toolbar"
Cohesion: 0.08
Nodes (23): build, Color, _CompactColorButton, _CompactColorPicker, _CompactIconButton, _CompactToolButton, _CompactWidthButton, _CompactWidthSlider (+15 more)

### Community 12 - "Tile & Cache Manager"
Cohesion: 0.09
Nodes (19): Offset, pdfPointToScreen, SelectionOverlayGeometry, _CacheKey, clear, dispose, StaticPictureCache, store (+11 more)

### Community 13 - "Stroke Cache & Session"
Cohesion: 0.09
Nodes (20): clear, clearCache, LruCache, PdfDocSession, put, adoptPicture, clearUndoSnapshots, createCacheSynchronously (+12 more)

### Community 14 - "Tree Layout & Coordinates"
Cohesion: 0.1
Nodes (20): ../annotation_controller.dart, build, _buildSelectionHandles, _buildToolbar, _colorToHex, didUpdateWidget, dispose, initState (+12 more)

### Community 15 - "Color Picker Popup"
Cohesion: 0.1
Nodes (19): AlertDialog, build, Color, _ColorChip, ColorPickerPopup, _ColorSlider, _colorToHex, _FullColorPickerDialog (+11 more)

### Community 16 - "Text Selection Overlay"
Cohesion: 0.1
Nodes (19): _ArrowPainter, build, _buildPresetColorButton, _calculatePosition, Color, _ColorPickerPopoverOverlay, _CompactToolButton, GestureDetector (+11 more)

### Community 17 - "Annotation Renderer"
Cohesion: 0.11
Nodes (17): AnnotationRenderer, Color, _createWavePath, _drawInkStroke, Offset, paint, _paintHighlight, _paintInk (+9 more)

### Community 18 - "Annotation Edit Toolbar"
Cohesion: 0.12
Nodes (15): AnnotationEditToolbar, _AnnotationEditToolbarState, _ArrowPainter, build, _calculatePosition, _CompactToolButton, dispose, _getArrowPosition (+7 more)

### Community 19 - "Annotation Controller"
Cohesion: 0.12
Nodes (15): AnnotationController, clearUndoRedo, CreateAnnotationAction, _createAnnotationWithUndo, DeleteAnnotationAction, _NullAnnotationController, _NullStorageRepository, _rebuildPageIndex (+7 more)

### Community 20 - "Viewport Transform"
Cohesion: 0.13
Nodes (14): constrainBounds, getViewportState, pan, resetViewport, restoreViewportState, setFreePanEnabled, setPalmRejectionEnabled, setPanOffset (+6 more)

### Community 21 - "Annotation Toolbar"
Cohesion: 0.13
Nodes (14): AlertDialog, AnnotationToolbar, build, Color, _ColorButton, ColorPickerDialog, Function, GestureDetector (+6 more)

### Community 22 - "Stroke Cache & Session"
Cohesion: 0.17
Nodes (11): addHighlight, deselectAnnotation, dispose, PdfViewportController, removeHighlight, selectAnnotation, pdf_doc_session.dart, ../pdf_highlight.dart (+3 more)

### Community 23 - "PDF Export Service"
Cohesion: 0.17
Nodes (11): convert, _encode, _escape, FormatException, JsonEncoder, PdfExportService, _prettyJson, package:starmind/src/domain/storage_repository.dart (+3 more)

### Community 24 - "MindMap Service & Repository"
Cohesion: 0.2
Nodes (9): MindMapService, NoteTreeNode, clear, InMemoryMindMapRepository, MindMapRepository, ../domain/note.dart, ../domain/topic.dart, mindmap_repository.dart (+1 more)

### Community 25 - "Info Statistics Modal"
Cohesion: 0.17
Nodes (11): build, _buildStatRow, _calculateMaxDepth, Center, _countContainers, _countNodes, Divider, InfoStatisticsModal (+3 more)

### Community 26 - "Selection Handles Overlay"
Cohesion: 0.18
Nodes (10): build, Function, paint, Positioned, _SelectionHandle, SelectionHandlesOverlay, _SelectionHandleState, shouldRepaint (+2 more)

### Community 27 - "Bottom Action Bar"
Cohesion: 0.18
Nodes (10): BottomActionBar, build, _buildVerticalDivider, ClipRRect, Container, _getLayoutText, Icon, InkWell (+2 more)

### Community 28 - "Lasso & Topic Card"
Cohesion: 0.18
Nodes (10): build, _buildEmptyState, _buildTopicList, Center, Function, Padding, Scaffold, SizedBox (+2 more)

### Community 29 - "Community 29"
Cohesion: 0.2
Nodes (9): _cancelDrawing, GestureDispatcher, isDrawGesture, onPointerCancel, onPointerDown, onPointerMove, onPointerUp, reset (+1 more)

### Community 30 - "PDF Viewport Controller"
Cohesion: 0.2
Nodes (9): AnnotationHitDetector, _hitTestInk, _hitTestNote, _hitTestRects, _isHit, Offset, _screenToPdf, package:starmind/src/domain/annotation.dart (+1 more)

### Community 31 - "MindMap Service & Repository"
Cohesion: 0.2
Nodes (9): build, Container, Function, NavigationRadar, paint, _RadarContentPainter, _RadarViewportPainter, shouldRepaint (+1 more)

### Community 32 - "Tree Layout & Coordinates"
Cohesion: 0.2
Nodes (9): _createBezierPath, _createPath, _createSteppedPath, _createStraightPath, MindMapCanvasPainter, paint, Path, shouldRepaint (+1 more)

### Community 33 - "MindMap Service & Repository"
Cohesion: 0.25
Nodes (7): _convertNote, _convertTopic, FfiMindMapRepository, Note, Topic, ../../rust/frb_generated.dart, ../../rust/storage/mindmap.dart

### Community 34 - "MindMap Page & Controller"
Cohesion: 0.25
Nodes (7): BoxShadow, build, GestureDetector, NodeWidget, SizedBox, Spacer, mindmap_controller.dart

### Community 35 - "Community 35"
Cohesion: 0.33
Nodes (5): copyWith, Note, _unset, dart:convert, note_content.dart

### Community 36 - "Community 36"
Cohesion: 0.4
Nodes (4): AnnotationAction, clear, push, UndoRedoStack

### Community 37 - "Community 37"
Cohesion: 0.5
Nodes (3): NoteContent, Segment, TextStyle

## Knowledge Gaps
- **660 isolated node(s):** `AnnotationController`, `_NullAnnotationController`, `_NullStorageRepository`, `CreateAnnotationAction`, `DeleteAnnotationAction` (+655 more)
  These have ＋1 connection - possible missing edges or undocumented components.
- **2 thin communities (<3 nodes) omitted from report** ！ run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `package:flutter/material.dart` connect `Lasso & Topic Card` to `MindMap Page & Controller`, `Interactive Canvas Viewer`, `Interactive Canvas Viewer`, `Pen Configuration`, `MindMap Sidebar & Toolbar`, `MindMap Page & Controller`, `Community 7`, `Tree Layout & Coordinates`, `Annotation Sidebar`, `Ink Canvas Layer`, `Ink Toolbar`, `Tile & Cache Manager`, `Stroke Cache & Session`, `Tree Layout & Coordinates`, `Color Picker Popup`, `Text Selection Overlay`, `Annotation Renderer`, `Annotation Edit Toolbar`, `Annotation Controller`, `Viewport Transform`, `Annotation Toolbar`, `Stroke Cache & Session`, `Info Statistics Modal`, `Selection Handles Overlay`, `Bottom Action Bar`, `Lasso & Topic Card`, `PDF Viewport Controller`, `MindMap Service & Repository`, `Tree Layout & Coordinates`, `MindMap Page & Controller`?**
  _High betweenness centrality (0.746) - this node is a cross-community bridge._
- **Why does `dart:ui` connect `Tile & Cache Manager` to `MindMap Page & Controller`, `Interactive Canvas Viewer`, `Community 7`, `Tree Layout & Coordinates`, `Stroke Cache & Session`, `Text Selection Overlay`, `Annotation Edit Toolbar`, `Info Statistics Modal`, `Bottom Action Bar`?**
  _High betweenness centrality (0.113) - this node is a cross-community bridge._
- **Why does `../domain/note.dart` connect `MindMap Service & Repository` to `MindMap Page & Controller`, `MindMap Service & Repository`, `MindMap Page & Controller`, `MindMap Sidebar & Toolbar`, `MindMap Page & Controller`?**
  _High betweenness centrality (0.039) - this node is a cross-community bridge._
- **What connects `AnnotationController`, `_NullAnnotationController`, `_NullStorageRepository` to the rest of the system?**
  _660 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `MindMap Page & Controller` be split into smaller, more focused modules?**
  _Cohesion score 0.04 - nodes in this community are weakly interconnected._
- **Should `Interactive Canvas Viewer` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._
- **Should `Interactive Canvas Viewer` be split into smaller, more focused modules?**
  _Cohesion score 0.05 - nodes in this community are weakly interconnected._