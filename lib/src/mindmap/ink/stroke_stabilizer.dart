import 'dart:math' as math;
import 'dart:ui';

/// 手写输入稳定器 — String Pulling + Moving Average + Corner Detection
///
/// 三阶段流水线，匹配 Procreate / Clip Studio 质量：
///
/// 1. **String Pulling** — 通过要求最小移动来过滤手部抖动
/// 2. **Weighted Moving Average** — 用滑动窗口平滑输出
/// 3. **Corner Detection** — 检测急剧方向变化并减少平滑以保留有意拐角
///
/// Level 0 = 无平滑（直通）。
/// Level 10 = 极强平滑（40px 弦长，显著拉直）。
class StrokeStabilizer {
  /// 平滑级别（0 = 无，10 = 最大）。
  int _level;

  /// 最后稳定位置（弦的"锚点"）。
  Offset? _lastStabilized;

  /// 速度跟踪。
  Offset? _previousRaw;
  int? _previousTimestamp;
  double _lastSpeed = 0.0;
  int _pointCount = 0;

  /// 移动平均缓冲（最近 N 个稳定点）。
  final List<Offset> _maBuffer = [];

  /// 压力平滑缓冲。
  final List<double> _pressureBuffer = [];

  /// 方向跟踪用于拐角检测。
  Offset? _lastDirection;

  /// 移动平均窗口大小（随级别缩放）。
  int get _maWindow =>
      (_level <= 3)
          ? 3
          : (_level <= 6)
          ? 4
          : 5;

  /// 弦长（逻辑像素），基于级别。
  /// 速度减少弦长（快速 = 响应灵敏）。
  double get _stringLength {
    if (_level == 0) return 0.0;
    final base = _level * 4.0;
    // 快速移动（>1200 px/s）最多减少弦长 60%。
    final velocityFactor = 1.0 - (_lastSpeed / 1200.0).clamp(0.0, 0.6);
    return base * velocityFactor;
  }

  /// 追赶因子：每采样移动多少超出距离。
  /// 使用 easeInOut 曲线而非线性。
  double get _catchup {
    final linear = 0.70 - (_level * 0.035).clamp(0.0, 0.35);
    final t = linear;
    return t * t * (3.0 - 2.0 * t); // Hermite smoothstep
  }

  StrokeStabilizer({int level = 0}) : _level = level.clamp(0, 10);

  /// 当前稳定器级别。
  int get level => _level;

  /// 更新稳定器级别。
  set level(int value) {
    _level = value.clamp(0, 10);
  }

  /// 稳定原始输入点。返回平滑后的位置。
  ///
  /// 级别 0 时返回原始点不变（零成本快速路径）。
  /// [timestampUs] 可选微秒时间戳（避免热路径上 `DateTime.now` 系统调用）。
  Offset stabilize(Offset rawPoint, {int? timestampUs}) {
    if (_level == 0) return rawPoint;

    // 从连续原始点跟踪速度。
    final nowUs = timestampUs ?? DateTime.now().microsecondsSinceEpoch;
    if (_previousRaw != null && _previousTimestamp != null) {
      final dtSec = (nowUs - _previousTimestamp!) / 1000000.0;
      if (dtSec > 0 && dtSec < 0.1) {
        _lastSpeed = (rawPoint - _previousRaw!).distance / dtSec;
      }
    }
    _previousRaw = rawPoint;
    _previousTimestamp = nowUs;

    // 第一点：锚定在原始位置。
    if (_lastStabilized == null) {
      _lastStabilized = rawPoint;
      _pointCount = 1;
      _maBuffer.clear();
      _maBuffer.add(rawPoint);
      _lastDirection = null;
      return rawPoint;
    }
    _pointCount++;

    // ═══════════════════════════════════════════════════════════════
    // STAGE 1: String Pulling
    // ═══════════════════════════════════════════════════════════════
    final anchor = _lastStabilized!;
    final dx = rawPoint.dx - anchor.dx;
    final dy = rawPoint.dy - anchor.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    // 预热：前 4 点将弦长从 0→100% 渐增。
    const warmupPoints = 4;
    final warmupFactor =
        _pointCount >= warmupPoints ? 1.0 : _pointCount / warmupPoints;

    // ═══════════════════════════════════════════════════════════════
    // STAGE 3: Corner Detection — 急转弯时减少弦长
    // ═══════════════════════════════════════════════════════════════
    double cornerScale = 1.0;
    if (dist > 0.5) {
      final currentDir = Offset(dx / dist, dy / dist);
      if (_lastDirection != null) {
        // 点积：1.0 = 同向，-1.0 = 反向。
        final dot =
            currentDir.dx * _lastDirection!.dx +
            currentDir.dy * _lastDirection!.dy;
        // 急转弯（dot < 0.5 = >60° 变化）→ 将弦长减至 30%。
        if (dot < 0.5) {
          cornerScale = 0.3 + 0.7 * ((dot + 1.0) / 1.5).clamp(0.0, 1.0);
        }
      }
      _lastDirection = currentDir;
    }

    final sLen = _stringLength * warmupFactor * cornerScale;

    Offset stringPulled;
    if (dist <= sLen) {
      // 懒跟随 — 总是向原始点移动一点。
      final baseLazy = 0.30 - (_level * 0.015);
      final lazyRatio = baseLazy * (dist / (sLen + 0.001));
      stringPulled = Offset(
        anchor.dx + dx * lazyRatio,
        anchor.dy + dy * lazyRatio,
      );
    } else {
      // 标准弦拉：移动超出量 * 追赶因子。
      final excess = dist - sLen;
      final move = excess * _catchup;
      final ratio = move / dist;
      stringPulled = Offset(anchor.dx + dx * ratio, anchor.dy + dy * ratio);
    }

    _lastStabilized = stringPulled;

    // ═══════════════════════════════════════════════════════════════
    // STAGE 2: Weighted Moving Average — 平滑输出
    // ═══════════════════════════════════════════════════════════════
    _maBuffer.add(stringPulled);
    final window = _maWindow;
    if (_maBuffer.length > window) {
      _maBuffer.removeAt(0);
    }

    // 加权平均：最近点权重更高。
    // 权重：[1, 2, 3, ...N] → 最新 = 最高。
    double sumX = 0, sumY = 0, sumW = 0;
    for (int i = 0; i < _maBuffer.length; i++) {
      final w = (i + 1).toDouble();
      sumX += _maBuffer[i].dx * w;
      sumY += _maBuffer[i].dy * w;
      sumW += w;
    }

    // 急拐角时减少 MA 混合以保留拐角。
    final maBlend = cornerScale < 0.8 ? cornerScale : 1.0;
    final maResult = Offset(sumX / sumW, sumY / sumW);

    // 混合：拐角时偏向弦拉结果；直线时偏向 MA。
    final result = Offset(
      stringPulled.dx * (1.0 - maBlend) + maResult.dx * maBlend,
      stringPulled.dy * (1.0 - maBlend) + maResult.dy * maBlend,
    );

    return result;
  }

  /// 使用加权移动平均平滑压力（窗口同位置）。
  double stabilizePressure(double rawPressure) {
    if (_level == 0) return rawPressure;

    _pressureBuffer.add(rawPressure);
    final window = _maWindow;
    if (_pressureBuffer.length > window) {
      _pressureBuffer.removeAt(0);
    }

    // 加权平均：最新 = 最高权重。
    double sum = 0, sumW = 0;
    for (int i = 0; i < _pressureBuffer.length; i++) {
      final w = (i + 1).toDouble();
      sum += _pressureBuffer[i] * w;
      sumW += w;
    }
    return sum / sumW;
  }

  /// 从稳定位置 → 实际最终位置生成追赶点。
  /// 在笔画结束时调用以填补稳定器滞后造成的间隙。
  /// 返回 N 个插值 Offset，使用 easeOutQuad 自然减速。
  List<Offset> finalize(Offset finalRawPoint, {int steps = 4}) {
    if (_level == 0 || _lastStabilized == null) return [];

    final from = _lastStabilized!;
    final dx = finalRawPoint.dx - from.dx;
    final dy = finalRawPoint.dy - from.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    // 已足够接近（< 2px 间隙）时跳过。
    if (dist < 2.0) return [];

    final points = <Offset>[];
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      // EaseOutQuad：快起慢停。
      final ease = 1.0 - (1.0 - t) * (1.0 - t);
      points.add(Offset(from.dx + dx * ease, from.dy + dy * ease));
    }
    return points;
  }

  /// 为新笔画重置稳定器。
  void reset() {
    _lastStabilized = null;
    _previousRaw = null;
    _previousTimestamp = null;
    _lastSpeed = 0.0;
    _pointCount = 0;
    _maBuffer.clear();
    _pressureBuffer.clear();
    _lastDirection = null;
  }
}
