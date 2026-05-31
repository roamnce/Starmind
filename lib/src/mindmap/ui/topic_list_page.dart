// lib/src/mindmap/ui/topic_list_page.dart

import 'package:flutter/material.dart';
import 'mindmap_controller.dart';
import 'topic_card.dart';

/// 笔记本列表页面。
///
/// 显示所有笔记本，支持创建、删除、进入笔记本。
class TopicListPage extends StatelessWidget {
  final MindMapController controller;
  final void Function(dynamic topic)? onTopicSelected;

  const TopicListPage({
    super.key,
    required this.controller,
    this.onTopicSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('思维导图'),
        centerTitle: true,
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : controller.topics.isEmpty
              ? _buildEmptyState(context)
              : _buildTopicList(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.account_tree_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '暂无笔记本',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右下角按钮创建第一个笔记本',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicList(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.topics.length,
      itemBuilder: (context, index) {
        final topic = controller.topics[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: TopicCard(
            topic: topic,
            onTap: () {
              controller.selectTopic(topic);
              onTopicSelected?.call(topic);
            },
            onDelete: () => _confirmDelete(context, topic.id),
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final textController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('创建笔记本'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '输入笔记本标题',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('创建'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await controller.createTopic(result);
    }
  }

  Future<void> _confirmDelete(BuildContext context, String topicId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除笔记本'),
        content: const Text('确定要删除这个笔记本吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await controller.trashTopic(topicId);
    }
  }
}