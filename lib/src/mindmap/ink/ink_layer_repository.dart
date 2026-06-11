import 'dart:convert';
import 'dart:io';

import '../../rust/api/storage.dart' as frb_api;
import '../../rust/storage/ink_layers.dart' as frb;
import '../../utils/type_conversion.dart';
import 'ink_layer.dart';

abstract class InkLayerRepository {
  Future<void> saveInkLayer(InkLayer layer);
  Future<InkLayer?> loadInkLayer(String ownerId, InkLayerOwnerType ownerType);
}

class FfiInkLayerRepository implements InkLayerRepository {
  const FfiInkLayerRepository();

  @override
  Future<InkLayer?> loadInkLayer(String ownerId, InkLayerOwnerType ownerType) async {
    final record = await frb_api.mindmapGetInkLayer(
      ownerId: ownerId,
      layerType: ownerType.name,
    );
    return record == null ? null : _fromRecord(record);
  }

  @override
  Future<void> saveInkLayer(InkLayer layer) async {
    await frb_api.mindmapSaveInkLayer(layer: _toRecord(layer));
  }

  InkLayer _fromRecord(frb.InkLayerRecord record) {
    final strokes = (jsonDecode(record.strokesJson) as List<dynamic>)
        .map((stroke) => InkStroke.fromJson(Map<String, dynamic>.from(stroke as Map)))
        .toList();
    return InkLayer(
      id: record.id,
      ownerType: InkLayerOwnerType.values.byName(record.layerType),
      ownerId: record.ownerId,
      strokes: strokes,
      zIndex: record.zIndex,
      createdAt: DateTime.fromMillisecondsSinceEpoch(i64ToInt(record.createdAt)),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(i64ToInt(record.updatedAt)),
    );
  }

  frb.InkLayerRecord _toRecord(InkLayer layer) {
    return frb.InkLayerRecord(
      id: layer.id,
      layerType: layer.ownerType.name,
      ownerId: layer.ownerId,
      strokesJson: layer.strokesJson,
      zIndex: layer.zIndex,
      createdAt: intToI64(layer.createdAt.millisecondsSinceEpoch),
      updatedAt: intToI64(layer.updatedAt.millisecondsSinceEpoch),
    );
  }
}

class JsonFileInkLayerRepository implements InkLayerRepository {
  JsonFileInkLayerRepository(this.directoryPath);

  final String directoryPath;

  @override
  Future<InkLayer?> loadInkLayer(String ownerId, InkLayerOwnerType ownerType) async {
    final file = File(_path(ownerId, ownerType));
    if (!await file.exists()) return null;
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    return InkLayer.fromJson(json);
  }

  @override
  Future<void> saveInkLayer(InkLayer layer) async {
    await Directory(directoryPath).create(recursive: true);
    await File(_path(layer.ownerId, layer.ownerType)).writeAsString(jsonEncode(layer.toJson()));
  }

  String _path(String ownerId, InkLayerOwnerType ownerType) => '$directoryPath/${ownerType.name}_$ownerId.json';
}

class InMemoryInkLayerRepository implements InkLayerRepository {
  final Map<String, InkLayer> _layers = {};

  @override
  Future<InkLayer?> loadInkLayer(String ownerId, InkLayerOwnerType ownerType) async => _layers[_key(ownerId, ownerType)];

  @override
  Future<void> saveInkLayer(InkLayer layer) async {
    _layers[_key(layer.ownerId, layer.ownerType)] = layer;
  }

  static String _key(String ownerId, InkLayerOwnerType ownerType) => '${ownerType.name}:$ownerId';
}
