import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Renders LaTeX math formulas using flutter_math_fork.
///
/// Block math ($$...$$) is rendered centered with a subtle background.
/// Inline math ($...$) is rendered inline with smaller text size.
class MathRenderer extends StatelessWidget {
  /// The LaTeX expression to render.
  final String tex;

  /// Whether this is a block-level (true) or inline (false) formula.
  final bool isBlock;

  /// Maximum width constraint.
  final double maxWidth;

  const MathRenderer({
    super.key,
    required this.tex,
    required this.isBlock,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (isBlock) {
      return Container(
        width: maxWidth,
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x0FFFFFFF),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Math.tex(
            tex,
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Math.tex(
      tex,
      textStyle: const TextStyle(fontSize: 14),
    );
  }
}

/// Extracts LaTeX math expressions from markdown text.
class MathExtractor {
  /// Extract inline math expressions ($...$) excluding block math ($$...$$).
  static List<MathMatch> extractInline(String text) {
    final matches = <MathMatch>[];
    final re = RegExp(r'(?<!\$)\$([^$\n]+?)\$(?!\$)');
    for (final m in re.allMatches(text)) {
      matches.add(MathMatch(
        tex: m.group(1)!,
        isBlock: false,
        startOffset: m.start,
        endOffset: m.end,
      ));
    }
    return matches;
  }

  /// Extract block math expressions ($$...$$).
  static List<MathMatch> extractBlock(String text) {
    final matches = <MathMatch>[];
    final re = RegExp(r'\$\$([^$]+)\$\$');
    for (final m in re.allMatches(text)) {
      matches.add(MathMatch(
        tex: m.group(1)!,
        isBlock: true,
        startOffset: m.start,
        endOffset: m.end,
      ));
    }
    return matches;
  }
}

/// Represents a single math expression match in text.
class MathMatch {
  /// The LaTeX content (without $ delimiters).
  final String tex;

  /// Whether this is block (true) or inline (false) math.
  final bool isBlock;

  /// Start offset in the source text.
  final int startOffset;

  /// End offset in the source text.
  final int endOffset;

  const MathMatch({
    required this.tex,
    required this.isBlock,
    required this.startOffset,
    required this.endOffset,
  });
}
