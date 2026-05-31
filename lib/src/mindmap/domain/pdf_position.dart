// lib/src/mindmap/domain/pdf_position.dart

/// PDF摘录位置信息（完整支持回溯定位）。
///
/// 设计依据：
/// - MarginNote: ZSTARTPAGE/ZENDPAGE + ZSTARTPOS/ZENDPOS
/// - 支持：页码范围、精确坐标、跨页摘录
class PdfPosition {
  /// 起始页码（0-based）
  final int startPage;

  /// 结束页码（0-based，支持跨页摘录）
  final int? endPage;

  /// 起始坐标（页面坐标系统）
  final PdfPoint startPos;

  /// 结束坐标
  final PdfPoint? endPos;

  const PdfPosition({
    required this.startPage,
    this.endPage,
    required this.startPos,
    this.endPos,
  });

  /// 是否跨页摘录
  bool get isCrossPage => endPage != null && endPage != startPage;

  /// 从 JSON 解析
  factory PdfPosition.fromJson(Map<String, dynamic> json) {
    return PdfPosition(
      startPage: json['start_page'] as int,
      endPage: json['end_page'] as int?,
      startPos: PdfPoint.fromJson(json['start_pos'] as Map<String, dynamic>),
      endPos: json['end_pos'] != null
          ? PdfPoint.fromJson(json['end_pos'] as Map<String, dynamic>)
          : null,
    );
  }

  /// 转为 JSON（用于数据库存储）
  Map<String, dynamic> toJson() => {
        'start_page': startPage,
        if (endPage != null) 'end_page': endPage,
        'start_pos': startPos.toJson(),
        if (endPos != null) 'end_pos': endPos!.toJson(),
      };
}

/// PDF 页面坐标点。
class PdfPoint {
  final double x;
  final double y;

  const PdfPoint({required this.x, required this.y});

  factory PdfPoint.fromJson(Map<String, dynamic> json) {
    return PdfPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}