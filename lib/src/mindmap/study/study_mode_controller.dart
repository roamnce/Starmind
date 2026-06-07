import 'package:flutter/foundation.dart';

import '../domain/note.dart';
import '../domain/note_content.dart';
import '../service/mindmap_service.dart';

class StudyQuestion {
  const StudyQuestion({required this.note, required this.index, required this.total});

  final Note note;
  final int index;
  final int total;
}

class StudyModeController extends ChangeNotifier {
  // ignore: prefer_initializing_formals
  StudyModeController({required MindMapService service}) : _service = service;

  final MindMapService _service;
  final List<Note> _questions = [];
  bool _isStudyMode = false;
  int _currentIndex = 0;

  bool get isStudyMode => _isStudyMode;
  int get currentIndex => _currentIndex;
  List<Note> get questions => List.unmodifiable(_questions);
  double get progress => _questions.isEmpty ? 0 : (_currentIndex + 1) / _questions.length;

  StudyQuestion? get currentQuestion {
    if (!_isStudyMode || _questions.isEmpty) return null;
    return StudyQuestion(note: _questions[_currentIndex], index: _currentIndex, total: _questions.length);
  }

  Future<void> enterStudyMode(String topicId) async {
    final notes = await _service.getNotesByTopic(topicId);
    _questions
      ..clear()
      ..addAll(notes.where(_isStudyCandidate));
    _currentIndex = 0;
    _isStudyMode = _questions.isNotEmpty;
    notifyListeners();
  }

  void enterWithQuestions(List<Note> notes) {
    _questions
      ..clear()
      ..addAll(notes.where(_isStudyCandidate));
    _currentIndex = 0;
    _isStudyMode = _questions.isNotEmpty;
    notifyListeners();
  }

  void exitStudyMode() {
    _isStudyMode = false;
    notifyListeners();
  }

  void nextQuestion() {
    if (!_isStudyMode || _questions.isEmpty) return;
    _currentIndex = (_currentIndex + 1).clamp(0, _questions.length - 1);
    notifyListeners();
  }

  void previousQuestion() {
    if (!_isStudyMode || _questions.isEmpty) return;
    _currentIndex = (_currentIndex - 1).clamp(0, _questions.length - 1);
    notifyListeners();
  }

  void jumpTo(int index) {
    if (!_isStudyMode || _questions.isEmpty) return;
    _currentIndex = index.clamp(0, _questions.length - 1);
    notifyListeners();
  }

  bool _isStudyCandidate(Note note) {
    if (note.highlightText?.trim().isNotEmpty ?? false) return true;
    if (note.mediaIds.isNotEmpty) return true;

    final content = note.content;
    if (content == null) return false;
    return content.segments.any((segment) {
      if (segment.type == SegmentType.image) return true;
      if (segment.style?.cloze ?? false) return true;
      return segment.text?.trim().isNotEmpty ?? false;
    });
  }
}
