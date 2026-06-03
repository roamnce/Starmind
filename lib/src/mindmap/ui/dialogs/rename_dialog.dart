// lib/src/mindmap/ui/dialogs/rename_dialog.dart
//
// 重命名对话框。
//
// 用于重命名节点标题的对话框组件。

import 'package:flutter/material.dart';

/// 重命名对话框。
///
/// 用于修改思维导图节点的标题。
///
/// 使用方式：
/// ```dart
/// final result = await RenameDialog.show(context, initialTitle: '旧标题');
/// if (result != null) {
///   // 更新节点标题
/// }
/// ```
class RenameDialog {
  RenameDialog._(); // 私有构造函数，防止实例化

  /// 显示重命名对话框。
  ///
  /// [context] - BuildContext
  /// [initialTitle] - 当前节点标题（作为默认值）
  ///
  /// 返回用户输入的新标题，如果取消则返回 null。
  static Future<String?> show(BuildContext context, {required String initialTitle}) async {
    final textController = TextEditingController(text: initialTitle);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Node'),
        content: TextField(
          controller: textController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new title',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    return result;
  }
}