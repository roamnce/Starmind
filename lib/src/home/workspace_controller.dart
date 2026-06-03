import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:starmind/src/domain/storage_repository.dart';
import 'package:starmind/src/domain/document.dart';
import 'package:starmind/src/domain/folder.dart';
import 'package:starmind/src/domain/tag.dart';
import 'package:starmind/src/home/tab_layout.dart';
import 'package:starmind/src/home/preferences_controller.dart';
import 'package:starmind/src/home/metadata_controller.dart';
import 'package:starmind/src/home/document_query_controller.dart';
import 'package:starmind/src/home/tab_navigation_controller.dart';

/// Coordinates sub-controllers for workspace management.
///
/// Provides a unified interface while delegating to focused controllers:
/// - [preferences]: User settings (theme, sidebar, etc.)
/// - [metadata]: Folder and tag trees
/// - [documents]: Document queries and filtering
/// - [tabs]: Multi-tab navigation
///
/// Backward-compatible convenience getters are provided for migration.
class WorkspaceController extends ChangeNotifier {
  WorkspaceController(this.repository);

  final StorageRepository repository;

  // Sub-controllers
  late final PreferencesController preferences;
  late final MetadataController metadata;
  late final DocumentQueryController documentQuery;
  late final TabNavigationController tabs;

  // Test injection - injected prefs stored before init
  SharedPreferences? _injectedPrefs;
  String? _injectedDbPath;
  String? _injectedSandboxDir;

  /// Inject SharedPreferences for testing (bypasses plugin channel).
  void injectPrefs(SharedPreferences prefs) {
    _injectedPrefs = prefs;
  }

  /// Inject paths for testing (bypasses path_provider).
  void injectPaths({String? dbPath, String? sandboxDir}) {
    _injectedDbPath = dbPath;
    _injectedSandboxDir = sandboxDir;
  }

  bool _initialized = false;
  bool get initialized => _initialized;

  /// Initializes storage and all sub-controllers.
  Future<void> init() async {
    if (_initialized) return;

    // Initialize sub-controllers
    preferences = PreferencesController();
    metadata = MetadataController(repository);
    documentQuery = DocumentQueryController(repository);
    tabs = TabNavigationController();

    // Apply injected prefs if provided (for testing)
    if (_injectedPrefs != null) {
      preferences.injectPrefs(_injectedPrefs!);
    }

    // Initialize preferences
    await preferences.init();

    // Initialize storage paths
    String dbPath;
    String sandboxDir;
    if (_injectedDbPath != null && _injectedSandboxDir != null) {
      dbPath = _injectedDbPath!;
      sandboxDir = _injectedSandboxDir!;
    } else {
      final appDir = await getApplicationSupportDirectory();
      dbPath = p.join(appDir.path, 'starmind.db');
      sandboxDir = p.join(appDir.path, 'sandbox');
      await Directory(sandboxDir).create(recursive: true);
    }

    // Initialize repository
    await repository.initialize(dbPath, sandboxDir);

    // Initialize tabs
    tabs.init();

    // Wire up sub-controller notifications to propagate to this controller
    preferences.addListener(notifyListeners);
    metadata.addListener(notifyListeners);
    documentQuery.addListener(notifyListeners);
    tabs.addListener(notifyListeners);

    // Load initial data
    await metadata.refresh();
    await documentQuery.refresh();

    _initialized = true;
    notifyListeners();
  }

  // ── CROSS-CONTROLLER COORDINATION ──

  /// Delete folder and coordinate across controllers.
  Future<void> deleteFolder(String id, bool deleteDocuments) async {
    documentQuery.clearFolderFilterIfMatches(id);
    await metadata.deleteFolder(id, deleteDocuments);
    await documentQuery.refresh();
    notifyListeners();
  }

  /// Delete tag and coordinate across controllers.
  Future<void> deleteTag(String id) async {
    documentQuery.clearTagFilterIfMatches(id);
    await metadata.deleteTag(id);
    await documentQuery.refresh();
    notifyListeners();
  }

  /// Delete document and close its tab.
  Future<void> deleteDoc(String id) async {
    await documentQuery.deleteDoc(id);
    tabs.closeTabById(id);
    notifyListeners();
  }

  // ── BACKWARD-COMPATIBLE CONVENIENCE GETTERS ──
  // These delegate to sub-controllers for gradual migration.

  // Preferences
  bool get isDarkMode => preferences.isDarkMode;
  bool get autoSave => preferences.autoSave;
  bool get sidebarOpen => preferences.sidebarOpen;
  bool get hideSystemStatusBar => preferences.hideSystemStatusBar;
  bool get isImmersiveMode => preferences.isImmersiveMode;
  bool get freePanEnabled => preferences.freePanEnabled;
  bool get palmRejectionEnabled => preferences.palmRejectionEnabled;

  // Metadata
  Folder? get folderTree => metadata.folderTree;
  Tag? get tagTree => metadata.tagTree;

  // Documents
  List<Document> get documents => documentQuery.documents;
  String? get activeFolderFilter => documentQuery.activeFolderFilter;
  String? get activeTagFilter => documentQuery.activeTagFilter;
  String get searchQuery => documentQuery.searchQuery;
  String get sortBy => documentQuery.sortBy;

  // Tabs
  SplitNode get rootLayoutNode => tabs.rootLayoutNode;

  // ── BACKWARD-COMPATIBLE CONVENIENCE METHODS ──

  Future<void> setAutoSave(bool value) => preferences.setAutoSave(value);
  Future<void> setDarkMode(bool value) => preferences.setDarkMode(value);
  Future<void> setSidebarOpen(bool value) => preferences.setSidebarOpen(value);
  Future<void> setHideSystemStatusBar(bool value) => preferences.setHideSystemStatusBar(value);
  void setImmersiveMode(bool value) => preferences.setImmersiveMode(value);
  Future<void> setFreePanEnabled(bool value) => preferences.setFreePanEnabled(value);
  Future<void> setPalmRejectionEnabled(bool value) => preferences.setPalmRejectionEnabled(value);

  Future<void> createFolder(String name, String? parentId) => metadata.createFolder(name, parentId);
  Future<void> renameFolder(String id, String newName) => metadata.renameFolder(id, newName);
  Future<void> createTag(String name, String? parentId, String? colorHex) => metadata.createTag(name, parentId, colorHex);
  Future<void> renameTag(String id, String newName) => metadata.renameTag(id, newName);

  Future<void> setFilters({String? folderFilter, String? tagFilter, bool resetOther = false}) =>
      documentQuery.setFilters(folderFilter: folderFilter, tagFilter: tagFilter, resetOther: resetOther);
  Future<void> setSearchQuery(String query) => documentQuery.setSearchQuery(query);
  Future<void> setSortBy(String sort) => documentQuery.setSortBy(sort);
  Future<void> importPdfFile(String title, String sourcePath, String? folderId) =>
      documentQuery.importPdfFile(title, sourcePath, folderId);
  Future<void> bindTag(String docId, String tagId) => documentQuery.bindTag(docId, tagId);
  Future<void> unbindTag(String docId, String tagId) => documentQuery.unbindTag(docId, tagId);

  void openDocument(Document doc) => tabs.openDocument(doc);
  void openMindMap(String topicId, String title) => tabs.openMindMap(topicId, title);
  void closeTab(int index) => tabs.closeTab(index);
  void closeTabById(String docId) => tabs.closeTabById(docId);
  void selectTab(int index) => tabs.selectTab(index);
}
