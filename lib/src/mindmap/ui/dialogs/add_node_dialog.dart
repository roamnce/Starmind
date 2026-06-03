// lib/src/mindmap/ui/dialogs/add_node_dialog.dart
//
// 添加节点对话框。
//
// 用于创建子节点或同级节点的对话框组件。

import 'package:flutter/material.dart';

/// 添加节点对话框。
///
/// 用于创建新的思维导图节点（子节点或同级节点）。
///
/// 使用方式：
/// ```dart
/// final result = await AddNodeDialog.show(context, isChild: true);
/// if (result != null) {
///   // 创建节点
/// }
/// ```
class AddNodeDialog {
  AddNodeDialog._(); // 私有构造函数，防止实例化

  /// 显示添加节点对话框。
  ///
  /// [context] - BuildContext
  /// [isChild] - true 创建子节点，false 创建同级节点
  ///
  /// 返回用户输入的标题，如果取消则返回 null。
  static Future<String?> show(BuildContext context, {required bool isChild}) async {
    final textController = TextEditingController();
    final titleText = isChild ? 'Create Child Node' : 'Create Sibling Node';

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titleText),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter node title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    return result;
  }
}