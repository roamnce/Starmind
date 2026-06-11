import 'ink_layer.dart';
import 'ink_layer_controller.dart';
import 'ink_layer_repository.dart';

/// Bridges InkLayerController's in-memory layers with InkLayerRepository.
///
/// - [hydrate]: Loads persisted layer from repository into controller when entering a page.
/// - [onStrokeEnded]: Saves the current layer to repository after stroke ends.
class InkLayerPersistence {
  InkLayerPersistence({required this.repository, required this.controller});

  /// The repository for persisting ink layers.
  final InkLayerRepository repository;

  /// The controller holding in-memory ink layers.
  final InkLayerController controller;

  /// Loads a persisted layer from the repository into the controller.
  ///
  /// Call this when entering a mindmap page to restore previously drawn strokes.
  ///
  /// @param ownerType The type of owner (canvas or node).
  /// @param ownerId The ID of the owner (topic ID or note ID).
  Future<void> hydrate(InkLayerOwnerType ownerType, String ownerId) async {
    final layer = await repository.loadInkLayer(ownerId, ownerType);
    if (layer != null) controller.loadLayer(layer);
  }

  /// Saves the current layer to the repository after a stroke ends.
  ///
  /// Call this after [InkLayerController.endStroke] returns a non-null stroke
  /// to persist the updated layer.
  ///
  /// @param ownerType The type of owner (canvas or node).
  /// @param ownerId The ID of the owner (topic ID or note ID).
  Future<void> onStrokeEnded(InkLayerOwnerType ownerType, String ownerId) async {
    final layer = controller.getLayer(ownerType, ownerId);
    if (layer == null) return;
    await repository.saveInkLayer(layer);
  }
}
