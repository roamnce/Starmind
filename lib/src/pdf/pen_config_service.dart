import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:starmind/src/pdf/pen_config.dart';
import 'package:starmind/src/pdf/pressure_curve.dart';

/// Service for persisting pen configuration.
///
/// Uses SharedPreferences to save and restore pen settings across sessions.
class PenConfigService {
  static const String _keyPenConfig = 'pen_config';

  final SharedPreferences _prefs;

  PenConfigService(this._prefs);

  /// Loads the saved pen configuration.
  ///
  /// Returns default config if no saved config exists.
  PenConfig loadPenConfig() {
    final jsonStr = _prefs.getString(_keyPenConfig);
    if (jsonStr == null) {
      return PenConfig.ballpointPen();
    }

    try {
      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return PenConfig.fromJson(json);
    } catch (_) {
      return PenConfig.ballpointPen();
    }
  }

  /// Saves the pen configuration.
  Future<void> savePenConfig(PenConfig config) async {
    final jsonStr = jsonEncode(config.toJson());
    await _prefs.setString(_keyPenConfig, jsonStr);
  }

  /// Updates only the stabilizer level in the saved config.
  Future<void> updateStabilizerLevel(int level) async {
    final config = loadPenConfig();
    await savePenConfig(config.copyWith(stabilizerLevel: level));
  }

  /// Updates only the pressure curve in the saved config.
  Future<void> updatePressureCurve(PressureCurve curve) async {
    final config = loadPenConfig();
    await savePenConfig(config.copyWith(pressureCurve: curve));
  }
}
