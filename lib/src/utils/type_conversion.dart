// lib/src/utils/type_conversion.dart
//
// flutter_rust_bridge 跨平台类型转换工具。
// 在 Web 平台上，i64 映射为 BigInt，桌面平台映射为 int。

/// 将 i64 (BigInt 或 int) 转换为 Dart int
///
/// 桌面平台: flutter_rust_bridge 返回 int
/// Web 平台: flutter_rust_bridge 返回 BigInt
int i64ToInt(dynamic value) {
  if (value is int) return value;
  if (value is BigInt) return value.toInt();
  throw ArgumentError('Expected int or BigInt, got $value');
}

/// 将 Dart int 转换为 i64 (返回平台兼容类型)
///
/// flutter_rust_bridge 会自动处理类型转换
dynamic intToI64(int value) => value;

/// Convert i32 from FFI to Dart int
int i32ToInt(dynamic value) {
  if (value is int) return value;
  if (value is BigInt) return value.toInt();
  throw ArgumentError('Expected int or BigInt, got ');
}
