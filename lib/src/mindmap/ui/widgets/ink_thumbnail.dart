// lib/src/mindmap/ui/widgets/ink_thumbnail.dart

import 'package:flutter/material.dart';

import '../../ink/ink_layer.dart';
import '../../ink/ink_layer_repository.dart';
import '../painters/ink_thumbnail_cache.dart';

/// 墨迹缩略图组件。
///
/// 异步加载 [InkLayer] 并渲染为 48x48 缩略图，
/// 使用全局 LRU 缓存避免重复渲染。
///
/// 显示规则：
/// - 透明度 0.7
/// - 尺寸 48x48
/// - 无墨迹时不显示
class InkThumbnail extends StatefulWidget {
  /// 墨迹层 ID（对应 Note.inkLayerId）。
  final String inkLayerId;

  /// 所属节点 ID（用于加载墨迹层）。
  final String nodeId;

  /// 墨迹层仓库。
  final InkLayerRepository repository;

  /// 缩略图尺寸；默认 48。
  final double size;

  /// 透明度；默认 0.7。
  final double opacity;

  const InkThumbnail({
    super.key,
    required this.inkLayerId,
    required this.nodeId,
    required this.repository,
    this.size = 48,
    this.opacity = 0.7,
  });

  @override
  State<InkThumbnail> createState() => _InkThumbnailState();
}

class _InkThumbnailState extends State<InkThumbnail> {
  /// 全局缩略图缓存（单例模式）。
  static final InkThumbnailCache _cache = InkThumbnailCache();

  Future<InkLayer?>? _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = widget.repository.loadInkLayer(
      widget.nodeId,
      InkLayerOwnerType.node,
    );
  }

  @override
  void didUpdateWidget(InkThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inkLayerId != widget.inkLayerId ||
        oldWidget.nodeId != widget.nodeId ||
        oldWidget.repository != widget.repository) {
      _loadFuture = widget.repository.loadInkLayer(
        widget.nodeId,
        InkLayerOwnerType.node,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<InkLayer?>(
      future: _loadFuture,
      builder: (context, snapshot) {
        final layer = snapshot.data;
        if (layer == null || layer.strokes.isEmpty) {
          return const SizedBox.shrink();
        }

        return FutureBuilder<RawImage>(
          future: _buildThumbnailImage(layer),
          builder: (context, imageSnapshot) {
            if (!imageSnapshot.hasData) {
              return const SizedBox.shrink();
            }
            return Opacity(
              opacity: widget.opacity,
              child: imageSnapshot.data!,
            );
          },
        );
      },
    );
  }

  /// 构建缩略图图像组件。
  Future<RawImage> _buildThumbnailImage(InkLayer layer) async {
    final image = await _cache.getOrBuild(layer);
    return RawImage(
      image: image,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
    );
  }
}
