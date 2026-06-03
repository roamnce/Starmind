/// Multi-tab split panel layout models.
/// Supports hierarchical splitting with LeafNode (tabs) and ParentNode (split containers).
library;

/// Base class for layout tree nodes.
abstract class SplitNode {
  final String id;
  SplitNode({required this.id});
}

/// A leaf node containing a list of tabs with one active.
class LeafNode extends SplitNode {
  final List<TabItem> tabs;
  final int activeIndex;

  LeafNode({
    required super.id,
    required this.tabs,
    required this.activeIndex,
  });

  LeafNode copyWith({
    List<TabItem>? tabs,
    int? activeIndex,
  }) {
    return LeafNode(
      id: id,
      tabs: tabs ?? this.tabs,
      activeIndex: activeIndex ?? this.activeIndex,
    );
  }
}

/// Direction for split panels.
enum SplitDirection { horizontal, vertical }

/// A parent node containing two child nodes split horizontally or vertically.
class ParentNode extends SplitNode {
  final SplitDirection direction;
  final SplitNode leftOrTop;
  final SplitNode rightOrBottom;
  final double ratio;

  ParentNode({
    required super.id,
    required this.direction,
    required this.leftOrTop,
    required this.rightOrBottom,
    this.ratio = 0.5,
  });
}

/// Type of content in a tab.
enum TabType { home, pdf, mindmap }

/// A single tab item.
class TabItem {
  final String id; // PDF ID, or "home"
  final TabType type;
  final String title;
  final String? filePath;

  TabItem({
    required this.id,
    required this.type,
    required this.title,
    this.filePath,
  });
}
