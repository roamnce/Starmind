import 'package:flutter/material.dart';

import '../ink/ink_layer.dart';
import '../ink/ink_layer_controller.dart';
import '../ink/node_note_content.dart';
import 'study_mode_controller.dart';

class StudyNoteWidget extends StatelessWidget {
  const StudyNoteWidget({super.key, required this.question, required this.inkController, this.onLayerChanged});

  final StudyQuestion question;
  final InkLayerController inkController;
  final void Function(InkLayer layer)? onLayerChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${question.index + 1}/${question.total}  ${question.note.title}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: NodeNoteContent(
              note: question.note,
              inkController: inkController,
              onLayerChanged: onLayerChanged,
            ),
          ),
        ],
      ),
    );
  }
}
