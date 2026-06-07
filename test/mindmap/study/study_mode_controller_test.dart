import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/domain/note.dart';
import 'package:starmind/src/mindmap/domain/note_content.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';
import 'package:starmind/src/mindmap/study/study_mode_controller.dart';
import 'package:starmind/src/mindmap/study/study_mode_shortcut_handler.dart';

void main() {
  test('StudyModeController navigates questions and shortcuts', () {
    final controller = StudyModeController(service: MindMapService(InMemoryMindMapRepository()));
    final now = DateTime.utc(2026, 6, 3);
    controller.enterWithQuestions([
      Note(
        id: '1-a',
        topicId: '0-topic',
        title: 'A',
        content: const NoteContent(segments: [Segment(type: SegmentType.text, text: 'Question A')]),
        createdAt: now,
        updatedAt: now,
      ),
      Note(
        id: '1-b',
        topicId: '0-topic',
        title: 'B',
        content: const NoteContent(segments: [Segment(type: SegmentType.text, text: 'Question B')]),
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final shortcuts = StudyModeShortcutHandler(controller);

    expect(controller.isStudyMode, isTrue);
    expect(controller.currentQuestion!.note.title, 'A');
    expect(shortcuts.handleKey(LogicalKeyboardKey.arrowRight), isTrue);
    expect(controller.currentQuestion!.note.title, 'B');
    expect(shortcuts.handleKey(LogicalKeyboardKey.arrowLeft), isTrue);
    expect(controller.currentQuestion!.note.title, 'A');
    shortcuts.handleKey(LogicalKeyboardKey.escape);
    expect(controller.isStudyMode, isFalse);
  });
}
