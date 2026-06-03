// lib/src/mindmap/utils/color_utils.dart
//
// 颜色转换工具类。
//
// 提供颜色解析和格式转换的静态方法，支持 Hex 和 RGBA 格式。

import 'package:flutter/material.dart';

/// 颜色转换工具类。
///
/// 提供颜色字符串解析和格式化的静态方法。
/// 支持 Hex (#RRGGBB) 和 RGBA (rgba(r, g, b, a)) 格式。
class ColorUtils {
  ColorUtils._(); // 私有构造函数，防止实例化

  /// 解析颜色字符串。
  ///
  /// 支持格式：
  /// - Hex: `#RRGGBB` 或 `#AARRGGBB`
  /// - RGBA: `rgba(r, g, b, a)` 其中 a 为 0.0-1.0
  ///
  /// 解析失败返回透明色。
  static Color parseColor(String colorStr) {
    if (colorStr.startsWith('#')) {
      final hex = colorStr.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } else if (colorStr.startsWith('rgba')) {
      final matches = RegExp(r'rgba\((\d+),\s*(\d+),\s*(\d+),\s*([\d.]+)\)').firstMatch(colorStr);
      if (matches != null) {
        final r = int.parse(matches.group(1)!);
        final g = int.parse(matches.group(2)!);
        final b = int.parse(matches.group(3)!);
        final a = (double.parse(matches.group(4)!) * 255).toInt();
        return Color.fromARGB(a, r, g, b);
      }
    }
    return Colors.transparent;
  }

  /// 将颜色转换为 Hex 格式字符串。
  ///
  /// 输出格式：`#RRGGBB`
  static String toHex(Color color) {
    return '#${color.value.toRadixString(16).substring(2).padLeft(6, "0")}';
  }

  /// 将颜色转换为 RGBA 格式字符串。
  ///
  /// 输出格式：`rgba(r, g, b, a)` 其中 a 为 0.00-1.00
  static String toRgba(Color color) {
    return 'rgba(${color.red}, ${color.green}, ${color.blue}, ${(color.alpha / 255).toStringAsFixed(2)})';
  }
}