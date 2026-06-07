import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'ink_layer.dart';

class InkLayerController extends ChangeNotifier {
  InkLayerController({String? Function()? idFactory}) : _idFactory = idFactory ?? const Uuid().v4;

  final String? Function() _idFactory;
  final Map<String, InkLayer> _layers = {};
  InkTool _tool = InkTool.pen;
  int _color = Colors.amber.value;
  double _width = 3;
  InkStroke? _currentStroke;

  InkTool get tool => _tool;
  int get color => _color;
  double get width => _width;
  InkStroke? get currentStroke => _currentStroke;

  List<InkLayer> get layers => List.unmodifiable(_layers.values);

  void setTool(InkTool tool) {
    _tool = tool;
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
    _currentStroke = InkStroke(
      id: _idFactory() ?? 'stroke-${DateTime.now().microsecondsSinceEpoch}',
      tool: _tool,
      color: _tool == InkTool.highlighter ? Colors.yellow.withValues(alpha: 0.35).value : _color,
      width: _tool == InkTool.highlighter ? _width * 3 : _width,
      points: [InkPoint(point.dx, point.dy, pressure: pressure)],
      createdAt: DateTime.now(),
    );
    notifyListeners();
  }

  void appendPoint(Offset point, {double pressure = 1}) {
    final stroke = _currentStroke;
    if (stroke == null) return;
    _currentStroke = stroke.copyWith(points: [...stroke.points, InkPoint(point.dx, point.dy, pressure: pressure)]);
    notifyListeners();
  }

  InkStroke? endStroke(InkLayerOwnerType ownerType, String ownerId) {
    final stroke = _currentStroke;
    _currentStroke = null;
    if (stroke == null || stroke.points.length < 2) {
      notifyListeners();
      return null;
    }
    final key = _key(ownerType, ownerId);
    final layer = ensureLayer(ownerType, ownerId);
    _layers[key] = layer.addStroke(stroke);
    notifyListeners();
    return stroke;
  }

  void erase(InkLayerOwnerType ownerType, String ownerId, Rect rect) {
    final layer = getLayer(ownerType, ownerId);
    if (layer == null) return;
    _layers[_key(ownerType, ownerId)] = layer.eraseIn(rect);
    notifyListeners();
  }

  void moveSelection(InkLayerOwnerType ownerType, String ownerId, Rect rect, Offset delta) {
    final layer = getLayer(ownerType, ownerId);
    if (layer == null) return;
    _layers[_key(ownerType, ownerId)] = layer.moveIn(rect, delta);
    notifyListeners();
  }

  static String _key(InkLayerOwnerType ownerType, String ownerId) => '${ownerType.name}:$ownerId';
}
