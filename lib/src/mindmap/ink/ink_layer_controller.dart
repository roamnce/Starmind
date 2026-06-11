import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'ink_layer.dart';
import 'stroke_stabilizer.dart';

/// Maximum number of history states to keep per owner (circular buffer size).
const int _maxHistorySize = 20;

class InkLayerController extends ChangeNotifier {
  InkLayerController({String? Function()? idFactory}) : _idFactory = idFactory ?? const Uuid().v4;

  final String? Function() _idFactory;
  final Map<String, InkLayer> _layers = {};
  InkTool _tool = InkTool.pen;
  int _color = Colors.amber.value;
  double _width = 3;
  InkStroke? _currentStroke;
  StrokeStabilizer _stabilizer = StrokeStabilizer(level: 3);

  /// History storage per owner key. Each entry is a list of layer states.
  final Map<String, List<InkLayer?>> _history = {};

  /// Current position in history per owner key.
  final Map<String, int> _historyIndex = {};

  InkTool get tool => _tool;
  int get color => _color;
  double get width => _width;
  InkStroke? get currentStroke => _currentStroke;
  int get stabilizerLevel => _stabilizer.level;

  List<InkLayer> get layers => List.unmodifiable(_layers.values);

  void setTool(InkTool tool) {
    _tool = tool;
    notifyListeners();
  }

  void setStabilizerLevel(int level) {
    _stabilizer.level = level;
    notifyListeners();
  }

  void setStyle({int? color, double? width}) {
    _color = color ?? _color;
    _width = width ?? _width;
    notifyListeners();
  }

  InkLayer ensureLayer(InkLayerOwnerType ownerType, String ownerId) {
    final key = _key(ownerType, ownerId);
    return _layers.putIfAbsent(key, () {
      final now = DateTime.now();
      return InkLayer(
        id: _idFactory() ?? '${ownerType.name}-$ownerId',
        ownerType: ownerType,
        ownerId: ownerId,
        createdAt: now,
        updatedAt: now,
      );
    });
  }

  InkLayer? getLayer(InkLayerOwnerType ownerType, String ownerId) => _layers[_key(ownerType, ownerId)];

  void loadLayer(InkLayer layer) {
    _layers[_key(layer.ownerType, layer.ownerId)] = layer;
    notifyListeners();
  }

  void beginStroke(InkLayerOwnerType ownerType, String ownerId, Offset point, {double pressure = 1}) {
    ensureLayer(ownerType, ownerId);
    _stabilizer.reset();
    final stabilized = _stabilizer.stabilize(point);
    final stabilizedPressure = _stabilizer.stabilizePressure(pressure);
    _currentStroke = InkStroke(
      id: _idFactory() ?? 'stroke-${DateTime.now().microsecondsSinceEpoch}',
      tool: _tool,
      color: _tool == InkTool.highlighter ? Colors.yellow.withValues(alpha: 0.35).value : _color,
      width: _tool == InkTool.highlighter ? _width * 3 : _width,
      points: [InkPoint(stabilized.dx, stabilized.dy, pressure: stabilizedPressure)],
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  void appendPoint(Offset point, {double pressure = 1}) {
    final stroke = _currentStroke;
    if (stroke == null) return;
    final stabilized = _stabilizer.stabilize(point);
    final stabilizedPressure = _stabilizer.stabilizePressure(pressure);
    _currentStroke = stroke.copyWith(points: [...stroke.points, InkPoint(stabilized.dx, stabilized.dy, pressure: stabilizedPressure)]);
    notifyListeners();
  }

  InkStroke? endStroke(InkLayerOwnerType ownerType, String ownerId) {
    final stroke = _currentStroke;
    _currentStroke = null;
    if (stroke == null || stroke.points.length < 2) {
      notifyListeners();
      return null;
    }
    // 添加 catch-up points
    final catchUpPoints = _stabilizer.finalize(stroke.points.last.offset);
    final finalStroke = catchUpPoints.isNotEmpty
        ? stroke.copyWith(points: [...stroke.points, ...catchUpPoints.map((p) => InkPoint(p.dx, p.dy))])
        : stroke;

    final key = _key(ownerType, ownerId);
    final layer = ensureLayer(ownerType, ownerId);
    _layers[key] = layer.addStroke(finalStroke);

    // Save state AFTER adding the stroke to history
    _pushHistoryInternal(key, _layers[key]);

    notifyListeners();
    return finalStroke;
  }

  void erase(InkLayerOwnerType ownerType, String ownerId, Rect rect) {
    final layer = getLayer(ownerType, ownerId);
    if (layer == null) return;
    final newLayer = layer.eraseIn(rect);
    _layers[_key(ownerType, ownerId)] = newLayer;
    _pushHistoryInternal(_key(ownerType, ownerId), newLayer);
    notifyListeners();
  }

  void moveSelection(InkLayerOwnerType ownerType, String ownerId, Rect rect, Offset delta) {
    final layer = getLayer(ownerType, ownerId);
    if (layer == null) return;
    final newLayer = layer.moveIn(rect, delta);
    _layers[_key(ownerType, ownerId)] = newLayer;
    _pushHistoryInternal(_key(ownerType, ownerId), newLayer);
    notifyListeners();
  }

  /// Internal method to save layer state to history.
  void _pushHistoryInternal(String key, InkLayer? layer) {
    // Initialize history list if needed
    _history.putIfAbsent(key, () => []);

    // Get current index and truncate any redo states
    final currentIndex = _historyIndex[key] ?? -1;
    final historyList = _history[key]!;

    // Remove any states after current index (discard redo states)
    if (currentIndex >= 0 && currentIndex < historyList.length - 1) {
      historyList.removeRange(currentIndex + 1, historyList.length);
    }

    // Save a copy of current state (the new state after the change)
    historyList.add(layer?.copyWith());

    // Enforce circular buffer size limit
    if (historyList.length > _maxHistorySize) {
      historyList.removeAt(0);
      // Adjust index if we removed an entry before current position
      if (currentIndex > 0) {
        _historyIndex[key] = currentIndex - 1;
      }
    }

    // Update index to point to the latest state
    _historyIndex[key] = historyList.length - 1;
  }

  /// Saves the current layer state to history for the given owner.
  ///
  /// Call this before modifying the layer to enable undo/redo.
  /// Only saves if the layer exists for this owner.
  void pushHistory(InkLayerOwnerType ownerType, String ownerId) {
    final key = _key(ownerType, ownerId);
    final layer = _layers[key];
    _pushHistoryInternal(key, layer);
  }

  /// Undoes the last change for the given owner.
  ///
  /// Returns `true` if undo was successful, `false` if no history available.
  bool undo(InkLayerOwnerType ownerType, String ownerId) {
    final key = _key(ownerType, ownerId);
    final historyList = _history[key];
    if (historyList == null || historyList.isEmpty) return false;

    final currentIndex = _historyIndex[key] ?? -1;
    // We can undo if there's at least one history entry before current
    if (currentIndex <= 0) return false;

    // Move back in history
    final newIndex = currentIndex - 1;
    _historyIndex[key] = newIndex;
    final previousState = historyList[newIndex];

    // Restore state
    if (previousState != null) {
      _layers[key] = previousState;
    } else {
      // If previous state is null, the layer didn't exist yet
      _layers.remove(key);
    }
    notifyListeners();
    return true;
  }

  /// Redoes a previously undone change for the given owner.
  ///
  /// Returns `true` if redo was successful, `false` if no redo available.
  bool redo(InkLayerOwnerType ownerType, String ownerId) {
    final key = _key(ownerType, ownerId);
    final historyList = _history[key];
    if (historyList == null || historyList.isEmpty) return false;

    final currentIndex = _historyIndex[key] ?? -1;
    if (currentIndex >= historyList.length - 1) return false;

    // Move forward in history
    final newIndex = currentIndex + 1;
    _historyIndex[key] = newIndex;
    final nextState = historyList[newIndex];

    // Restore state
    if (nextState != null) {
      _layers[key] = nextState;
    } else {
      _layers.remove(key);
    }
    notifyListeners();
    return true;
  }

  /// Returns `true` if undo is available for the given owner.
  bool canUndo(InkLayerOwnerType ownerType, String ownerId) {
    final key = _key(ownerType, ownerId);
    final historyList = _history[key];
    if (historyList == null || historyList.isEmpty) return false;
    final currentIndex = _historyIndex[key] ?? -1;
    return currentIndex > 0;
  }

  /// Returns `true` if redo is available for the given owner.
  bool canRedo(InkLayerOwnerType ownerType, String ownerId) {
    final key = _key(ownerType, ownerId);
    final historyList = _history[key];
    if (historyList == null || historyList.isEmpty) return false;
    final currentIndex = _historyIndex[key] ?? -1;
    return currentIndex < historyList.length - 1;
  }

  /// Clears all history for the given owner.
  void clearHistory(InkLayerOwnerType ownerType, String ownerId) {
    final key = _key(ownerType, ownerId);
    _history.remove(key);
    _historyIndex.remove(key);
  }

  static String _key(InkLayerOwnerType ownerType, String ownerId) => '${ownerType.name}:$ownerId';
}
