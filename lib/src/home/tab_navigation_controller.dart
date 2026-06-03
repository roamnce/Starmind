import 'package:flutter/material.dart';
import 'package:starmind/src/home/tab_layout.dart';
import 'package:starmind/src/domain/document.dart';

/// Manages multi-tab navigation and split panel layout.
///
/// Provides tab open/close/switch operations for the workspace.
class TabNavigationController extends ChangeNotifier {
  late SplitNode _rootLayoutNode;

  SplitNode get rootLayoutNode => _rootLayoutNode;

  /// Initialize with default home tab.
  void init() {
    _rootLayoutNode = LeafNode(
      id: 'default_leaf',
      tabs: [
        TabItem(id: 'home', type: TabType.home, title: '首页'),
      ],
      activeIndex: 0,
    );
  }

  /// Opens a Document in a new tab or switches to it if already open.
  void openDocument(Document doc) {
    if (_rootLayoutNode is LeafNode) {
      final leaf = _rootLayoutNode as LeafNode;
      final existingIndex = leaf.tabs.indexWhere((t) => t.id == doc.id && t.type == TabType.pdf);

      if (existingIndex != -1) {
        _rootLayoutNode = leaf.copyWith(activeIndex: existingIndex);
      } else {
        final updatedTabs = List<TabItem>.from(leaf.tabs)
          ..add(TabItem(
            id: doc.id,
            type: TabType.pdf,
            title: doc.title,
            filePath: doc.filePath,
          ));
        _rootLayoutNode = leaf.copyWith(
          tabs: updatedTabs,
          activeIndex: updatedTabs.length - 1,
        );
      }
      notifyListeners();
    }
  }

  /// Opens a MindMap in a new tab or switches to it if already open.
  void openMindMap(String topicId, String title) {
    if (_rootLayoutNode is LeafNode) {
      final leaf = _rootLayoutNode as LeafNode;
      final existingIndex = leaf.tabs.indexWhere((t) => t.id == topicId && t.type == TabType.mindmap);

      if (existingIndex != -1) {
        _rootLayoutNode = leaf.copyWith(activeIndex: existingIndex);
      } else {
        final updatedTabs = List<TabItem>.from(leaf.tabs)
          ..add(TabItem(
            id: topicId,
            type: TabType.mindmap,
            title: title,
          ));
        _rootLayoutNode = leaf.copyWith(
          tabs: updatedTabs,
          activeIndex: updatedTabs.length - 1,
        );
      }
      notifyListeners();
    }
  }

  void closeTab(int index) {
    if (_rootLayoutNode is LeafNode) {
      final leaf = _rootLayoutNode as LeafNode;
      if (index == 0) return; // Cannot close home tab
      if (index >= leaf.tabs.length) return;

      final updatedTabs = List<TabItem>.from(leaf.tabs)..removeAt(index);

      int newActive = leaf.activeIndex;
      if (leaf.activeIndex >= index) {
        newActive = (leaf.activeIndex - 1).clamp(0, updatedTabs.length - 1);
      }

      _rootLayoutNode = leaf.copyWith(
        tabs: updatedTabs,
        activeIndex: newActive,
      );
      notifyListeners();
    }
  }

  void closeTabById(String docId) {
    if (_rootLayoutNode is LeafNode) {
      final leaf = _rootLayoutNode as LeafNode;
      final index = leaf.tabs.indexWhere((t) => t.id == docId && t.type == TabType.pdf);
      if (index != -1) {
        closeTab(index);
      }
    }
  }

  void selectTab(int index) {
    if (_rootLayoutNode is LeafNode) {
      final leaf = _rootLayoutNode as LeafNode;
      if (index >= 0 && index < leaf.tabs.length) {
        _rootLayoutNode = leaf.copyWith(activeIndex: index);
        notifyListeners();
      }
    }
  }
}
