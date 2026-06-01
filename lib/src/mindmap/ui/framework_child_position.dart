// lib/src/mindmap/ui/framework_child_position.dart

/// 框架内子节点的自定义位置
class FrameworkChildPosition {
  /// 行索引（从 0 开始）
  final int row;

  /// 列索引（从 0 开始）
  final int col;

  const FrameworkChildPosition({
    required this.row,
    required this.col,
  });

  /// 从 JSON 创建
  factory FrameworkChildPosition.fromJson(Map<String, dynamic> json) {
    return FrameworkChildPosition(
      row: json['row'] as int,
      col: json['col'] as int,
    );
  }

  /// 转为 JSON
  Map<String, dynamic> toJson() => {
    'row': row,
    'col': col,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FrameworkChildPosition &&
        other.row == row &&
        other.col == col;
  }

  @override
  int get hashCode => Object.hash(row, col);

  @override
  String toString() => 'FrameworkChildPosition(row: $row, col: $col)';
}