// lib/src/rust/type_utils.dart
//
// flutter_rust_bridge 跨平台类型兼容工具。
// 在 Web 平台上，i64 映射为 BigInt，需要显式转换。

/// 将 i64 时间戳转换为 int（跨平台兼容）
///
/// 在桌面平台上，flutter_rust_bridge 返回 int。
/// 在 Web 平台上，返回 BigInt，需要显式转换。
int bigIntToInt(dynamic value) {
  if (value is int) return value;
  if (value is BigInt) return value.toInt();
  throw ArgumentError('Expected int or BigInt, got $value');
}

/// 将 int 转换为 i64 时间戳（跨平台兼容）
dynamic intToBigInt(int value) => value;
