// lib/src/mindmap/ui/node_tag_picker.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'mindmap_controller.dart';

/// 节点标签选择器
///
/// 显示在选中节点附近，允许输入标签名并绑定。
class NodeTagPicker extends StatefulWidget {
  final MindMapController controller;
  final VoidCallback onClose;

  const NodeTagPicker({
    super.key,
    required this.controller,
    required this.onClose,
  });

  @override
  State<NodeTagPicker> createState() => _NodeTagPickerState();
}

class _NodeTagPickerState extends State<NodeTagPicker> {
  final _textController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    // 使用标签名作为 tagId（简化实现）
    widget.controller.bindTagToSelectedNode(trimmed);
    _textController.clear();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              widget.onClose();
              return null;
            },
          ),
        },
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1710),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0x14FFDC8C),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 已绑定标签列表
              if (widget.controller.selectedNote != null)
                _buildBoundTags(),
              // 输入框
              TextField(
                controller: _textController,
                focusNode: _focusNode,
                autofocus: true,
                style: const TextStyle(
                  color: Color(0xFFFFF8E6),
                  fontSize: 12,
                ),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: '输入标签名...',
                  hintStyle: TextStyle(
                    color: const Color(0xFFFFF8E6).withOpacity(0.4),
                    fontSize: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0x14FFDC8C)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                onSubmitted: _handleSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoundTags() {
    final noteId = widget.controller.selectedNote!.id;
    final tags = widget.controller.tagsByNoteId[noteId] ?? [];

    if (tags.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: tags.map((tag) {
          return Chip(
            label: Text(
              tag.name,
              style: const TextStyle(
                color: Color(0xFFFFF8E6),
                fontSize: 10,
              ),
            ),
            backgroundColor: const Color(0xFFC8841A).withOpacity(0.2),
            deleteIcon: const Icon(Icons.close, size: 12),
            deleteIconColor: const Color(0xFFFFF8E6).withOpacity(0.6),
            onDeleted: () {
              widget.controller.unbindTagFromNode(noteId, tag.id);
            },
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
          );
        }).toList(),
      ),
    );
  }
}
