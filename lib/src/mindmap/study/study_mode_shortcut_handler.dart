import 'package:flutter/services.dart';

import 'study_mode_controller.dart';

class StudyModeShortcutHandler {
  const StudyModeShortcutHandler(this.controller);

  final StudyModeController controller;

  bool handleKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowRight || key == LogicalKeyboardKey.space) {
      controller.nextQuestion();
      return true;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      controller.previousQuestion();
      return true;
    }
    if (key == LogicalKeyboardKey.escape) {
      controller.exitStudyMode();
      return true;
    }
    return false;
  }
}
