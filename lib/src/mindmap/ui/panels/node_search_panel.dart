// lib/src/mindmap/ui/panels/node_search_panel.dart
//
// 节点搜索面板。
//
// 提供节点搜索、结果列表、点击跳转功能。

import 'package:flutter/material.dart';
import '../mindmap_controller.dart';
import '../../service/mindmap_service.dart' show NoteTreeNode;

/// 节点搜索面板。
///
/// 显示搜索输入框和搜索结果列表。
class NodeSearchPanel extends StatefulWidget {
  final MindMapController controller;

  const NodeSearchPanel({
    super.key,
    required this.controller,
  });

  @override
  State<NodeSearchPanel> createState() => _NodeSearchPanelState();
}

class _NodeSearchPanelState extends State<NodeSearchPanel> {
  final TextEditingController _searchController = TextEditingController();
  List<NoteTreeNode> _searchResults = [];
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    setState(() {
      _query = query;
      _searchResults = widget.controller.searchNodes(query);
    });
  }

  void _onResultTap(NoteTreeNode node) {
    widget.controller.selectNote(node.note);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 搜索输入框
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearch,
            style: const TextStyle(color: Color(0xE6FFF8E6), fontSize: 12),
            decoration: InputDecoration(
              hintText: '输入关键词以检索导图内容...',
              hintStyle: const TextStyle(color: Color(0x4DFFF8E6), fontSize: 12),
              filled: true,
              fillColor: const Color(0x0DFFF8E6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0x14FFDC8C), width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0x14FFDC8C), width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: const BorderSide(color: Color(0xFF5CB8FC), width: 1),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ),

        // 搜索结果列表
        Expanded(
          child: _query.isEmpty
              ? const Center(
                  child: Text(
                    '输入关键词开始搜索',
                    style: TextStyle(color: Color(0x4DFFF8E6), fontSize: 12),
                  ),
                )
              : _searchResults.isEmpty
                  ? const Center(
                      child: Text(
                        '未找到匹配节点',
                        style: TextStyle(color: Color(0x4DFFF8E6), fontSize: 12),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final node = _searchResults[index];
                        return _SearchResultItem(
                          node: node,
                          onTap: () => _onResultTap(node),
                        );
                      },
                    ),
        ),
      ],
    );
  }
}

class _SearchResultItem extends StatelessWidget {
  final NoteTreeNode node;
  final VoidCallback onTap;

  const _SearchResultItem({
    required this.node,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = false; // TODO: 检查是否为当前选中节点

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0x05FFF8E6),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? const Color(0xFFC8841A) : const Color(0x14FFDC8C),
            width: 1,
          ),
        ),
        child: Text(
          node.note.title,
          style: const TextStyle(
            color: Color(0xE6FFF8E6),
            fontSize: 12,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
