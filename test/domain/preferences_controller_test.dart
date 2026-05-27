import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/home/preferences_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PreferencesController', () {
    late PreferencesController controller;
    late SharedPreferences mockPrefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockPrefs = await SharedPreferences.getInstance();

      controller = PreferencesController();
      controller.injectPrefs(mockPrefs);
      await controller.init();
    });

    test('should have default values', () {
      expect(controller.isDarkMode, isTrue);
      expect(controller.autoSave, isTrue);
      expect(controller.sidebarOpen, isTrue);
      expect(controller.hideSystemStatusBar, isFalse);
      expect(controller.isImmersiveMode, isFalse);
    });

    test('should set dark mode', () async {
      await controller.setDarkMode(false);
      expect(controller.isDarkMode, isFalse);
      expect(mockPrefs.getBool('isDarkMode'), isFalse);
    });

    test('should set auto save', () async {
      await controller.setAutoSave(false);
      expect(controller.autoSave, isFalse);
      expect(mockPrefs.getBool('autoSave'), isFalse);
    });

    test('should set sidebar open', () async {
      await controller.setSidebarOpen(false);
      expect(controller.sidebarOpen, isFalse);
      expect(mockPrefs.getBool('sidebarOpen'), isFalse);
    });

    test('should set hide system status bar', () async {
      await controller.setHideSystemStatusBar(true);
      expect(controller.hideSystemStatusBar, isTrue);
      expect(mockPrefs.getBool('hideSystemStatusBar'), isTrue);
    });

    test('should set immersive mode', () {
      controller.setImmersiveMode(true);
      expect(controller.isImmersiveMode, isTrue);
    });

    test('should not notify when immersive mode unchanged', () {
      var notified = false;
      controller.addListener(() => notified = true);

      controller.setImmersiveMode(false); // Already false
      expect(notified, isFalse);
    });

    test('should load persisted values on init', () async {
      SharedPreferences.setMockInitialValues({
        'isDarkMode': false,
        'autoSave': false,
        'sidebarOpen': false,
        'hideSystemStatusBar': true,
      });
      final prefs = await SharedPreferences.getInstance();

      final ctrl = PreferencesController();
      ctrl.injectPrefs(prefs);
      await ctrl.init();

      expect(ctrl.isDarkMode, isFalse);
      expect(ctrl.autoSave, isFalse);
      expect(ctrl.sidebarOpen, isFalse);
      expect(ctrl.hideSystemStatusBar, isTrue);
    });
  });
}