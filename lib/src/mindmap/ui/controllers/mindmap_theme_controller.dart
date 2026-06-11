import 'dart:convert';
import 'package:flutter/material.dart';
import '../../utils/color_utils.dart';

/// 画布主题状态。
///
/// 管理背景色、网格、连线样式等主题相关配置。
/// 深度模块：主题持久化逻辑隐藏在接口背后。
class MindMapThemeController extends ChangeNotifier {
  Color _canvasBgColor = const Color(0xFF0C0A07);
  Color _gridColor = const Color(0x05FAD278);
  bool _showGrid = true;
  double _gridSize = 40.0;
  bool _isRainbowBranch = false;

  Color get canvasBgColor => _canvasBgColor;
  Color get gridColor => _gridColor;
  bool get showGrid => _showGrid;
  double get gridSize => _gridSize;
  bool get isRainbowBranch => _isRainbowBranch;

  /// 重置为默认主题
  void reset() {
    _canvasBgColor = const Color(0xFF0C0A07);
    _gridColor = const Color(0x05FAD278);
    _showGrid = true;
    _gridSize = 40.0;
    _isRainbowBranch = false;
    notifyListeners();
  }

  /// 更新主题配置
  void update({
    Color? canvasBgColor,
    Color? gridColor,
    bool? showGrid,
    double? gridSize,
    bool? isRainbowBranch,
  }) {
    if (canvasBgColor != null) _canvasBgColor = canvasBgColor;
    if (gridColor != null) _gridColor = gridColor;
    if (showGrid != null) _showGrid = showGrid;
    if (gridSize != null) _gridSize = gridSize;
    if (isRainbowBranch != null) _isRainbowBranch = isRainbowBranch;
    notifyListeners();
  }

  /// 切换彩虹分支颜色
  void toggleRainbowBranch() {
    _isRainbowBranch = !_isRainbowBranch;
    notifyListeners();
  }

  /// 切换网格显示
  void toggleGrid() {
    _showGrid = !_showGrid;
    notifyListeners();
  }

  /// 从 JSON 加载主题
  void loadFromJson(String? jsonStr) {
    if (jsonStr == null || !jsonStr.startsWith('{"theme":')) return;
    try {
      final data = jsonDecode(jsonStr);
      final theme = data['theme'];
      if (theme != null) {
        if (theme['canvasBg'] != null) {
          _canvasBgColor = ColorUtils.parseColor(theme['canvasBg']);
        }
        if (theme['gridColor'] != null) {
          _gridColor = ColorUtils.parseColor(theme['gridColor']);
        }
        if (theme['gridShow'] != null) {
          _showGrid = theme['gridShow'] as bool;
        }
        if (theme['gridSize'] != null) {
          _gridSize = (theme['gridSize'] as num).toDouble();
        }
        notifyListeners();
      }
    } catch (_) {}
  }

  /// 导出主题为 JSON
  String exportToJson() {
    final themeData = {
      'theme': {
        'canvasBg': ColorUtils.toHex(_canvasBgColor),
        'gridColor': ColorUtils.toRgba(_gridColor),
        'gridShow': _showGrid,
        'gridSize': _gridSize,
      },
    };
    return jsonEncode(themeData);
  }
}