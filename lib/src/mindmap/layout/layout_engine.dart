// lib/src/mindmap/layout/layout_engine.dart

import 'layout_config.dart';
import 'layout_result.dart';
import '../service/mindmap_service.dart';

/// 布局引擎抽象接口
///
/// 定义布局计算的通用接口，支持不同的布局算法实现
abstract class LayoutEngine {
  /// 计算节点树的布局
  ///
  /// [root] 根节点
  /// [config] 布局配置
  /// 返回布局结果，包含节点位置、尺寸和连线数据
  LayoutResult layout(NoteTreeNode root, LayoutConfig config);

  /// 计算布局边界框
  ///
  /// [root] 根节点
  /// [config] 布局配置
  /// 返回内容边界框
  Rect calculateBounds(NoteTreeNode root, LayoutConfig config) {
    final result = layout(root, config);
    return result.contentBounds;
  }
}
