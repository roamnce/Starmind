import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/mindmap_controller.dart';
import 'package:starmind/src/mindmap/service/mindmap_service.dart';
import 'package:starmind/src/mindmap/storage/in_memory_mindmap_repository.dart';
import 'package:starmind/src/mindmap/domain/topic.dart';

void main() {
  group('MindMapController', () {
    late MindMapController controller;

    setUp(() {
      controller = MindMapController(
        MindMapService(InMemoryMindMapRepository()),
      );
    });

    tearDown(() {
      controller.dispose();
    });

    test('initial state has empty topic list', () {
      expect(controller.topics, isEmpty);
      expect(controller.selectedTopic, isNull);
      expect(controller.isLoading, isFalse);
    });

    test('loadTopics populates topic list', () async {
      await controller.createTopic('笔记本1');
      await controller.createTopic('笔记本2');
      await controller.loadTopics();

      expect(controller.topics.length, equals(2));
    });

    test('createTopic adds to list and selects it', () async {
      final topic = await controller.createTopic('新笔记本');

      expect(controller.topics.contains(topic), isTrue);
      expect(controller.selectedTopic, equals(topic));
    });

    test('selectTopic updates selectedTopic', () async {
      final topic = await controller.createTopic('测试笔记本');

      controller.selectTopic(null);
      expect(controller.selectedTopic, isNull);

      controller.selectTopic(topic);
      expect(controller.selectedTopic, equals(topic));
    });

    test('trashTopic removes from list', () async {
      final topic = await controller.createTopic('待删除笔记本');
      expect(controller.topics.contains(topic), isTrue);

      await controller.trashTopic(topic.id);
      expect(controller.topics.contains(topic), isFalse);
    });

    group('Viewport', () {
      test('initial viewport is identity', () {
        expect(controller.viewportScale, equals(1.0));
        expect(controller.viewportOffset, equals(Offset.zero));
      });

      test('zoom in increases scale', () {
        controller.zoomIn();
        expect(controller.viewportScale, greaterThan(1.0));
      });

      test('zoom out decreases scale', () {
        controller.zoomOut();
        expect(controller.viewportScale, lessThan(1.0));
      });

      test('zoom has limits', () {
        // 多次放大
        for (var i = 0; i < 20; i++) {
          controller.zoomIn();
        }
        expect(controller.viewportScale, lessThanOrEqualTo(4.0));

        // 多次缩小
        for (var i = 0; i < 20; i++) {
          controller.zoomOut();
        }
        expect(controller.viewportScale, greaterThanOrEqualTo(0.1));
      });

      test('resetViewport restores identity', () {
        controller.zoomIn();
        controller.pan(const Offset(100, 100));

        controller.resetViewport();

        expect(controller.viewportScale, equals(1.0));
        expect(controller.viewportOffset, equals(Offset.zero));
      });
    });

    group('Note CRUD', () {
      test('createChildNode adds child node to selected parent and selects it', () async {
        await controller.createTopic('Note Topic');
        final parent = await controller.createNote(title: 'Parent Note');
        controller.selectNote(parent);

        final child = await controller.createChildNode(title: 'Child Note');
        expect(child, isNotNull);
        expect(child!.title, equals('Child Note'));
        expect(child.parentId, equals(parent.id));
        expect(controller.selectedNote, equals(child));
      });

      test('createSiblingNode adds sibling node and selects it', () async {
        await controller.createTopic('Note Topic');
        final parent = await controller.createNote(title: 'Parent Note');
        controller.selectNote(parent);
        final child1 = await controller.createChildNode(title: 'Child 1');
        controller.selectNote(child1);

        final child2 = await controller.createSiblingNode(title: 'Child 2');
        expect(child2, isNotNull);
        expect(child2!.title, equals('Child 2'));
        expect(child2.parentId, equals(parent.id));
        expect(controller.selectedNote, equals(child2));
      });
    });

    group('Phase 2 & 3 State and Theme Persistence Tests', () {
      test('default sidebar, interact mode, and theme values', () {
        expect(controller.isSidebarExpanded, isFalse);
        expect(controller.activeSidebarTab, equals(SidebarTab.note));
        expect(controller.interactMode, equals(CanvasInteractMode.drag));
        expect(controller.isLocked, isFalse);
        expect(controller.selectedNoteIds, isEmpty);
        expect(controller.canvasBgColor, equals(const Color(0xFF0C0A07)));
        expect(controller.gridColor, equals(const Color(0x05FAD278)));
        expect(controller.showGrid, isTrue);
        expect(controller.gridSize, equals(40.0));
      });

      test('toggleSidebar expands and collapses correctly', () {
        expect(controller.isSidebarExpanded, isFalse);
        
        controller.toggleSidebar(SidebarTab.style);
        expect(controller.isSidebarExpanded, isTrue);
        expect(controller.activeSidebarTab, equals(SidebarTab.style));

        // Toggling a different tab keeps it expanded but changes tab
        controller.toggleSidebar(SidebarTab.note);
        expect(controller.isSidebarExpanded, isTrue);
        expect(controller.activeSidebarTab, equals(SidebarTab.note));

        // Toggling the same tab collapses it
        controller.toggleSidebar(SidebarTab.note);
        expect(controller.isSidebarExpanded, isFalse);
      });

      test('setInteractMode changes mode and clears selection on drag mode', () {
        controller.setInteractMode(CanvasInteractMode.lasso);
        expect(controller.interactMode, equals(CanvasInteractMode.lasso));

        controller.setSelectedNotes({'note1', 'note2'});
        expect(controller.selectedNoteIds, equals({'note1', 'note2'}));

        // Switching back to drag mode should clear selectedNoteIds
        controller.setInteractMode(CanvasInteractMode.drag);
        expect(controller.interactMode, equals(CanvasInteractMode.drag));
        expect(controller.selectedNoteIds, isEmpty);
      });

      test('toggleLock toggles lock state', () {
        expect(controller.isLocked, isFalse);
        controller.toggleLock();
        expect(controller.isLocked, isTrue);
        controller.toggleLock();
        expect(controller.isLocked, isFalse);
      });

      test('theme parsing handles valid theme JSON in loadThemeFromJson', () {
        const jsonTheme = '{"theme": {"canvasBg": "#141B24", "gridColor": "rgba(250, 210, 120, 0.05)", "gridShow": false, "gridSize": 50.0}}';
        controller.loadThemeFromJson(jsonTheme);
        
        expect(controller.canvasBgColor.value, equals(const Color(0xFF141B24).value));
        expect(controller.gridColor.value, equals(const Color(0x0CFAD278).value));
        expect(controller.showGrid, isFalse);
        expect(controller.gridSize, equals(50.0));
      });

      test('exportThemeToJson creates matching JSON string', () {
        final jsonStr = controller.exportThemeToJson();
        expect(jsonStr, contains('"theme"'));
        expect(jsonStr, contains('"canvasBg":"#0c0a07"'));
        expect(jsonStr, contains('"gridColor":"rgba(250, 210, 120, 0.02)"'));
        expect(jsonStr, contains('"gridShow":true'));
        expect(jsonStr, contains('"gridSize":40.0'));
      });

      test('updateTheme persists and updates theme in database', () async {
        final topic = await controller.createTopic('Theme Topic');
        expect(controller.selectedTopic, equals(topic));

        await controller.updateTheme(
          canvasBgColor: const Color(0xFF0A0515),
          gridColor: const Color(0xFF00FFCC),
          showGrid: false,
          gridSize: 30.0,
        );

        expect(controller.canvasBgColor, equals(const Color(0xFF0A0515)));
        expect(controller.gridColor, equals(const Color(0xFF00FFCC)));
        expect(controller.showGrid, isFalse);
        expect(controller.gridSize, equals(30.0));

        // The serialized theme should be saved in selectedTopic.thumbnailPath
        final jsonStr = controller.selectedTopic!.thumbnailPath;
        expect(jsonStr, isNotNull);
        expect(jsonStr!, startsWith('{"theme":'));
        expect(jsonStr, contains('"canvasBg":"#0a0515"'));
        expect(jsonStr, contains('"gridColor":"rgba(0, 255, 204, 1.00)"'));
        expect(jsonStr, contains('"gridShow":false'));
        expect(jsonStr, contains('"gridSize":30.0'));

        // Try selecting another topic (without theme) and verify it resets to defaults
        final otherTopic = await controller.createTopic('No Theme Topic');
        controller.selectTopic(otherTopic);
        expect(controller.canvasBgColor, equals(const Color(0xFF0C0A07)));

        // Select the themed topic again and verify it restores the theme
        controller.selectTopic(controller.topics.firstWhere((t) => t.id == topic.id));
        expect(controller.canvasBgColor, equals(const Color(0xFF0A0515)));
        expect(controller.gridColor, equals(const Color(0xFF00FFCC)));
        expect(controller.showGrid, isFalse);
        expect(controller.gridSize, equals(30.0));
      });
    });
  });
}
