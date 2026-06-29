import 'dart:io';

import 'package:flutter/material.dart';

/// Renders a local image file within a LivePreview card.
///
/// Validates that [imagePath] points to an existing file. If the file does not
/// exist or fails to load, an error indicator ("[图片加载失败]") is shown
/// instead of a broken image.
class ImageRenderer extends StatefulWidget {
  final String imagePath;
  final double maxWidth;

  const ImageRenderer({
    super.key,
    required this.imagePath,
    required this.maxWidth,
  });

  @override
  State<ImageRenderer> createState() => _ImageRendererState();
}

class _ImageRendererState extends State<ImageRenderer> {
  File? _file;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _validateFile();
  }

  @override
  void didUpdateWidget(ImageRenderer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _hasError = false;
      _validateFile();
    }
  }

  void _validateFile() {
    final file = File(widget.imagePath);
    if (file.existsSync()) {
      _file = file;
    } else {
      _file = null;
      _hasError = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _file == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          '[图片加载失败]',
          style: TextStyle(color: Colors.red, fontSize: 13),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.maxWidth,
        maxHeight: 400,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.file(
          _file!,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Text(
              '[图片加载失败]',
              style: TextStyle(color: Colors.red, fontSize: 13),
            );
          },
        ),
      ),
    );
  }
}