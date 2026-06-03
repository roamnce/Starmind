import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Global render scheduler for PDF page rendering.
///
/// Limits concurrent rendering tasks to prevent memory exhaustion.
/// Uses a simple semaphore-like approach.
class RenderScheduler {
  static final RenderScheduler _instance = RenderScheduler._internal();
  factory RenderScheduler() => _instance;
  RenderScheduler._internal();

  /// Maximum concurrent render tasks.
  static const int maxConcurrent = 3;

  /// Current running tasks count.
  int _runningCount = 0;

  /// Queue of waiting tasks.
  final List<_RenderTask> _waiting = [];

  /// Schedule a render task.
  Future<ui.Image?> scheduleRender({
    required int pageIndex,
    required Future<ui.Image?> Function() render,
    required double priority,
    VoidCallback? onCancel,
  }) async {
    final task = _RenderTask(
      pageIndex: pageIndex,
      priority: priority,
      render: render,
      onCancel: onCancel,
    );

    // If at capacity, add to queue and wait
    if (_runningCount >= maxConcurrent) {
      _waiting.add(task);
      _waiting.sort((a, b) => a.priority.compareTo(b.priority));

      // Wait for our turn
      await task.completer.future;

      // Remove from waiting list
      _waiting.remove(task);
    }

    if (task.isCancelled) {
      return null;
    }

    // Run the render
    _runningCount++;
    try {
      final image = await render();
      return image;
    } catch (e) {
      debugPrint('[RenderScheduler] Render error for page $pageIndex: $e');
      return null;
    } finally {
      _runningCount--;
      _notifyNext();
    }
  }

  /// Notify the next waiting task.
  void _notifyNext() {
    if (_waiting.isEmpty) return;
    if (_runningCount >= maxConcurrent) return;

    final next = _waiting.first;
    if (!next.isCancelled && !next.completer.isCompleted) {
      next.completer.complete();
    }
  }

  /// Cancel all tasks for a specific page.
  void cancelPage(int pageIndex) {
    for (final task in _waiting) {
      if (task.pageIndex == pageIndex) {
        task.cancel();
      }
    }
    // Also remove cancelled tasks
    _waiting.removeWhere((t) => t.isCancelled);
  }

  /// Clear all pending tasks.
  void clearAll() {
    for (final task in _waiting) {
      task.cancel();
    }
    _waiting.clear();
  }

  int get runningCount => _runningCount;
  int get waitingCount => _waiting.length;
}

/// Internal render task.
class _RenderTask {
  final int pageIndex;
  final double priority;
  final Future<ui.Image?> Function() render;
  final VoidCallback? onCancel;
  final Completer<void> completer = Completer();
  bool _isCancelled = false;

  _RenderTask({
    required this.pageIndex,
    required this.priority,
    required this.render,
    this.onCancel,
  });

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
    onCancel?.call();
    if (!completer.isCompleted) {
      completer.complete();
    }
  }
}
