import 'package:flutter/material.dart';

import '../domain/note.dart';
import '../domain/note_content.dart' as note_content;
import 'canvas_ink_layer.dart';
import 'ink_layer.dart';
import 'ink_layer_controller.dart';

class NodeNoteContent extends StatelessWidget {
  const NodeNoteContent({
    super.key,
    required this.note,
    required this.inkController,
    this.inkEnabled = true,
    this.onLayerChanged,
  });

  final Note note;
  final InkLayerController inkController;
  final bool inkEnabled;
  final void Function(InkLayer layer)? onLayerChanged;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: _NoteRichText(noteContent: note.content, fallback: note.highlightText ?? note.title),
        ),
        NodeInkOverlay(
          controller: inkController,
          nodeId: note.id,
          enabled: inkEnabled,
          onLayerChanged: onLayerChanged,
        ),
      ],
    );
  }
}

class NodeInkOverlay extends StatelessWidget {
  const NodeInkOverlay({super.key, required this.controller, required this.nodeId, this.enabled = true, this.onLayerChanged});

  final InkLayerController controller;
  final String nodeId;
  final bool enabled;
  final void Function(InkLayer layer)? onLayerChanged;

  @override
  Widget build(BuildContext context) {
    return CanvasInkLayer(
      controller: controller,
      ownerType: InkLayerOwnerType.node,
      ownerId: nodeId,
      enabled: enabled,
      onLayerChanged: onLayerChanged,
    );
  }
}

class _NoteRichText extends StatelessWidget {
  const _NoteRichText({required this.noteContent, required this.fallback});

  final note_content.NoteContent? noteContent;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final segments = noteContent?.segments ?? const <note_content.Segment>[];
    if (segments.isEmpty) return Text(fallback);
    return RichText(
      text: TextSpan(
        style: DefaultTextStyle.of(context).style,
        children: segments.map((segment) => TextSpan(text: segment.text)).toList(),
      ),
    );
  }
}
