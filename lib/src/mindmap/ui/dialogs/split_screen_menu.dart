// lib/src/mindmap/ui/dialogs/split_screen_menu.dart
//
// 分屏选择菜单。
//
// 用于选择分屏内容（PDF 文档或思维导图）的弹出菜单组件。

import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../mindmap_controller.dart';
import '../../domain/topic.dart';
import '../../../domain/document.dart';

/// 分屏选择菜单。
///
/// 显示可选的 PDF 文档和思维导图列表，供用户选择分屏内容。
///
/// 使用方式：
/// ```dart
/// await SplitScreenMenu.show(
///   context,
///   controller: controller,
///   pdfDocs: pdfDocuments,
///   getMindmaps: () => controller.getAllTopics(),
/// );
/// ```
class SplitScreenMenu {
  SplitScreenMenu._(); // 私有构造函数，防止实例化

  /// 显示分屏选择菜单。
  ///
  /// [context] - BuildContext
  /// [controller] - MindMapController
  /// [pdfDocs] - 可选的 PDF 文档列表
  /// [getMindmaps] - 获取思维导图列表的异步函数
  static Future<void> show(
    BuildContext context, {
    required MindMapController controller,
    required List<Document> pdfDocs,
    required Future<List<Topic>> Function() getMindmaps,
  }) async {
    final mindmaps = await getMindmaps();

    if (!context.mounted) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'split_screen_menu',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Center(
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: 420,
                constraints: const BoxConstraints(maxHeight: 500),
                decoration: BoxDecoration(
                  color: const Color(0xED16110A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x33FFDC8C), width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                child: _SplitScreenMenuContent(
                  controller: controller,
                  pdfDocs: pdfDocs,
                  mindmaps: mindmaps,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// 菜单内容组件。
class _SplitScreenMenuContent extends StatelessWidget {
  final MindMapController controller;
  final List<Document> pdfDocs;
  final List<Topic> mindmaps;

  const _SplitScreenMenuContent({
    required this.controller,
    required this.pdfDocs,
    required this.mindmaps,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),
          const TabBar(
            tabs: [
              Tab(text: 'PDF 文档'),
              Tab(text: '思维导图'),
            ],
            labelColor: Color(0xFFFFF8E6),
            unselectedLabelColor: Colors.white38,
            indicatorColor: Color(0xFFC8841A),
          ),
          Flexible(
            child: SizedBox(
              height: 300,
              child: TabBarView(
                children: [
                  _buildPdfList(context),
                  _buildMindmapList(context),
                ],
              ),
            ),
          ),
          if (controller.splitType != null) _buildCloseButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, left: 16, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '选择分屏内容',
            style: TextStyle(
              color: Color(0xFFFFF8E6),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white60, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfList(BuildContext context) {
    if (pdfDocs.isEmpty) {
      return const Center(
        child: Text(
          '没有已导入的 PDF',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: pdfDocs.length,
      itemBuilder: (context, idx) {
        final doc = pdfDocs[idx];
        return ListTile(
          leading: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 20),
          title: Text(
            doc.title,
            style: const TextStyle(color: Color(0xFFFFF8E6), fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            Navigator.pop(context);
            controller.openSplitScreen('pdf', doc.id, doc.title, doc.filePath);
          },
        );
      },
    );
  }

  Widget _buildMindmapList(BuildContext context) {
    if (mindmaps.isEmpty) {
      return const Center(
        child: Text(
          '没有其它思维导图',
          style: TextStyle(color: Colors.white38),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: mindmaps.length,
      itemBuilder: (context, idx) {
        final topic = mindmaps[idx];
        return ListTile(
          leading: const Icon(Icons.account_tree_outlined, color: Color(0xFFC8841A), size: 20),
          title: Text(
            topic.title,
            style: const TextStyle(color: Color(0xFFFFF8E6), fontSize: 14),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            Navigator.pop(context);
            controller.openSplitScreen('mindmap', topic.id, topic.title);
          },
        );
      },
    );
  }

  Widget _buildCloseButton(BuildContext context) {
    return Column(
      children: [
        const Divider(color: Color(0x1F2A3547), height: 1),
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.close_fullscreen_rounded, color: Colors.redAccent, size: 16),
              label: const Text('关闭分屏', style: TextStyle(color: Colors.redAccent)),
              onPressed: () {
                Navigator.pop(context);
                controller.closeSplitScreen();
              },
            ),
          ),
        ),
      ],
    );
  }
}