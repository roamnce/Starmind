// lib/src/mindmap/ui/info_statistics_modal.dart

import 'dart:ui';
import 'package:flutter/material.dart';
import 'mindmap_controller.dart';
import '../service/mindmap_service.dart' show NoteTreeNode;

class InfoStatisticsModal extends StatelessWidget {
  final MindMapController controller;
  final VoidCallback onClose;

  const InfoStatisticsModal({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    // Traverse and calculate stats
    final nodeCount = _countNodes(controller.noteTree);
    final charStats = _countCharacters(controller.noteTree);
    final containerCount = _countContainers(controller.noteTree);
    final maxDepth = _calculateMaxDepth(controller.noteTree);
    final pdfCount = controller.selectedTopic?.pdfIds.length ?? 0;

    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 280,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xD91C222B),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x1F2A3547), width: 1.0),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '关于导图',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white60, size: 20),
                      onPressed: onClose,
                    ),
                  ],
                ),
                const Divider(color: Color(0x15FFFFFF), height: 20),
                _buildStatRow('节点总数', '$nodeCount 个'),
                _buildStatRow('嵌套容器', '$containerCount 个'),
                _buildStatRow('标题字数', '${charStats['title']} 字'),
                _buildStatRow('笔记字数', '${charStats['content']} 字'),
                _buildStatRow('总字数统计', '${charStats['total']} 字'),
                _buildStatRow('最大深度', '$maxDepth 层'),
                _buildStatRow('关联文档', '$pdfCount 篇'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  int _countNodes(List<NoteTreeNode> roots) {
    return roots.fold(0, (sum, root) => sum + root.totalNodes);
  }

  Map<String, int> _countCharacters(List<NoteTreeNode> roots) {
    int title = 0;
    int content = 0;
    void traverse(NoteTreeNode n) {
      title += n.note.title.length;
      content += (n.note.content?.plainText.length ?? 0);
      for (final child in n.children) {
        traverse(child);
      }
    }
    for (final root in roots) {
      traverse(root);
    }
    return {'title': title, 'content': content, 'total': title + content};
  }

  int _countContainers(List<NoteTreeNode> roots) {
    int count = 0;
    void traverse(NoteTreeNode n) {
      if (n.note.highlightStyle == 'nestedCard') count++;
      for (final child in n.children) {
        traverse(child);
      }
    }
    for (final root in roots) {
      traverse(root);
    }
    return count;
  }

  int _calculateMaxDepth(List<NoteTreeNode> roots) {
    return roots.isEmpty ? 0 : roots.map((r) => r.maxDepth).reduce((a, b) => a > b ? a : b);
  }
}
