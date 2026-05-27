/// 🤖 Generated wholly or partially with Claude Code; Google Antigravity

import 'package:flutter/material.dart';
import 'package:starmind/src/home/workspace_controller.dart';

/// InheritedWidget that provides WorkspaceController to the widget tree.
///
/// This replaces the singleton pattern with explicit dependency injection.
/// Widgets access the controller via:
///   - `WorkspaceControllerProvider.of(context)`
///   - `context.workspaceController`
///
/// Tests can inject a WorkspaceController with InMemoryStorageRepository:
/// ```dart
/// final controller = WorkspaceController.withRepository(InMemoryStorageRepository());
/// await controller.init();
///
/// runApp(WorkspaceControllerProvider(
///   controller: controller,
///   child: MyApp(),
/// ));
/// ```
class WorkspaceControllerProvider extends InheritedWidget {
  const WorkspaceControllerProvider({
    super.key,
    required this.controller,
    required super.child,
  });

  final WorkspaceController controller;

  /// Returns the WorkspaceController from the nearest ancestor.
  /// Throws if no WorkspaceControllerProvider is found in the tree.
  static WorkspaceController of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<WorkspaceControllerProvider>();
    if (provider == null) {
      throw StateError('No WorkspaceControllerProvider found in context. '
          'Wrap your app with WorkspaceControllerProvider(controller: ..., child: ...)');
    }
    return provider.controller;
  }

  /// Returns the WorkspaceController, or null if not found.
  static WorkspaceController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<WorkspaceControllerProvider>()?.controller;
  }

  @override
  bool updateShouldNotify(WorkspaceControllerProvider oldWidget) {
    return controller != oldWidget.controller;
  }
}

/// Extension for convenient access via `context.workspaceController`.
extension WorkspaceControllerExtension on BuildContext {
  WorkspaceController get workspaceController => WorkspaceControllerProvider.of(this);
  WorkspaceController? get maybeWorkspaceController => WorkspaceControllerProvider.maybeOf(this);
}