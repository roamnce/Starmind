import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:highlight/languages/all.dart' show allLanguages;

/// Renders a code block with syntax highlighting using flutter_highlight.
///
/// Uses a dark background + monospace font + optional language label bar.
/// Falls back to plaintext rendering when the language is not recognized.
class CodeBlockRenderer extends StatelessWidget {
  /// The source code text to display.
  final String code;

  /// Optional language identifier (e.g. 'dart', 'python', 'javascript').
  final String? language;

  /// Maximum width constraint for the rendered block.
  final double maxWidth;

  const CodeBlockRenderer({
    super.key,
    required this.code,
    this.language,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    final lang = (language ?? '').toLowerCase();

    return Container(
      width: maxWidth,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Language label bar
          if (lang.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0x1AFFFFFF),
                border: Border(
                  bottom: BorderSide(color: Color(0x1AFFFFFF)),
                ),
              ),
              child: Text(
                lang,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          // Code content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: HighlightView(
                code,
                language: allLanguages.containsKey(lang) ? lang : 'plaintext',
                theme: githubTheme,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
