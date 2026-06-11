// lib/src/mindmap/ui/relation_label_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../domain/mindmap_relation.dart';

/// 关联线文本标签组件
///
/// 显示在关联线中点位置，支持点击选中和双击编辑。
class RelationLabelWidget extends StatelessWidget {
  final MindMapRelation relation;
  final bool isSelected;
  final bool isEditing;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const RelationLabelWidget({
    super.key,
    required this.relation,
    required this.isSelected,
    this.isEditing = false,
    required this.onTap,
    required this.onDoubleTap,
    required this.onCommit,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (isEditing) {
      return _buildEditor();
    }
    return _buildLabel();
  }

  Widget _buildLabel() {
    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFC8841A).withOpacity(0.3)
              : const Color(0xFF242930).withOpacity(0.8),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFC8841A)
                : const Color(0x40C8841A),
            width: 1,
          ),
        ),
        child: Text(
          relation.text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFFFFF8E6)
                : const Color(0xB3FFF8E6),
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildEditor() {
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              onCancel();
              return null;
            },
          ),
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF242930),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFFC8841A),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: TextEditingController(text: relation.text)
              ..selection = TextSelection(
                baseOffset: 0,
                extentOffset: relation.text.length,
              ),
            autofocus: true,
            style: const TextStyle(
              color: Color(0xFFFFF8E6),
              fontSize: 11,
            ),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            ),
            onSubmitted: onCommit,
          ),
        ),
      ),
    );
  }
}
