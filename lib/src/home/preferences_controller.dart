import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Manages user preferences with persistence via SharedPreferences.
///
/// Supports dependency injection for testing via [injectPrefs].
class PreferencesController extends ChangeNotifier {
  SharedPreferences? _prefs;
  bool _isDarkMode = true;
  bool _autoSave = true;
  bool _sidebarOpen = true;
  bool _hideSystemStatusBar = false;
  bool _isImmersiveMode = false;

  // PDF Viewport preferences
  bool _freePanEnabled = false;  // 自由平移模式
  bool _palmRejectionEnabled = false;  // 防误触模式

  bool get isDarkMode => _isDarkMode;
  bool get autoSave => _autoSave;
  bool get sidebarOpen => _sidebarOpen;
  bool get hideSystemStatusBar => _hideSystemStatusBar;
  bool get isImmersiveMode => _isImmersiveMode;
  bool get freePanEnabled => _freePanEnabled;
  bool get palmRejectionEnabled => _palmRejectionEnabled;

  /// Initialize from SharedPreferences. Call once at startup.
  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _autoSave = _prefs!.getBool('autoSave') ?? true;
    _isDarkMode = _prefs!.getBool('isDarkMode') ?? true;
    _sidebarOpen = _prefs!.getBool('sidebarOpen') ?? true;
    _hideSystemStatusBar = _prefs!.getBool('hideSystemStatusBar') ?? false;
    _freePanEnabled = _prefs!.getBool('freePanEnabled') ?? false;
    _palmRejectionEnabled = _prefs!.getBool('palmRejectionEnabled') ?? false;
  }

  /// Inject SharedPreferences for testing (bypasses plugin channel).
  void injectPrefs(SharedPreferences prefs) {
    _prefs = prefs;
  }

  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    await _prefs?.setBool('autoSave', value);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    await _prefs?.setBool('isDarkMode', value);
    notifyListeners();
  }

  Future<void> setSidebarOpen(bool value) async {
    _sidebarOpen = value;
    await _prefs?.setBool('sidebarOpen', value);
    notifyListeners();
  }

  Future<void> setHideSystemStatusBar(bool value) async {
    _hideSystemStatusBar = value;
    await _prefs?.setBool('hideSystemStatusBar', value);
    notifyListeners();
  }

  void setImmersiveMode(bool value) {
    if (_isImmersiveMode != value) {
      _isImmersiveMode = value;
      notifyListeners();
    }
  }

  /// Enables or disables free pan mode for PDF viewport.
  Future<void> setFreePanEnabled(bool value) async {
    _freePanEnabled = value;
    await _prefs?.setBool('freePanEnabled', value);
    notifyListeners();
  }

  /// Enables or disables palm rejection for PDF drawing.
  Future<void> setPalmRejectionEnabled(bool value) async {
    _palmRejectionEnabled = value;
    await _prefs?.setBool('palmRejectionEnabled', value);
    notifyListeners();
  }
}
