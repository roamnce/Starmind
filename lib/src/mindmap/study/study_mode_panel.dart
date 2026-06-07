import 'package:flutter/material.dart';

import 'study_mode_controller.dart';

class StudyModePanel extends StatelessWidget {
  const StudyModePanel({super.key, required this.controller});

  final StudyModeController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final question = controller.currentQuestion;
        return Material(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(value: controller.progress == 0 ? null : controller.progress),
                ),
                const SizedBox(width: 12),
                Text(question == null ? '0/0' : '${question.index + 1}/${question.total}'),
                const SizedBox(width: 12),
                IconButton(
                  tooltip: 'Previous',
                  onPressed: controller.previousQuestion,
                  icon: const Icon(Icons.chevron_left),
                ),
                IconButton(
                  tooltip: 'Next',
                  onPressed: controller.nextQuestion,
                  icon: const Icon(Icons.chevron_right),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Exit'),
                  onPressed: controller.exitStudyMode,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
