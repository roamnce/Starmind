import 'package:flutter/material.dart';

/// Information about a single placeholder detected in markdown text.
///
/// Placeholders represent regions of the markdown source that will be replaced
/// by real rendered widgets (e.g., images rendered via Image.network or
/// FileImage, math formulas rendered via a formula renderer). The [charOffset]
/// and [length] refer to positions in the full markdown string so that
/// [PlaceholderTracker] can answer offset-based queries used by the overlay
/// positioning system.
class PlaceholderInfo {
  /// Unique identifier for this placeholder within a single [PlaceholderTracker]
  /// rebuild cycle. Derived from line index and match start so it is stable
  /// across rebuilds of the same markdown.
  final String id;

  /// The 0-based line index (from `markdown.split('\n')`) where this
  /// placeholder was found.
  final int lineIndex;

  /// Absolute character offset in the full markdown string where this
  /// placeholder begins.
  final int charOffset;

  /// Length of the placeholder in characters (raw markdown text length).
  final int length;

  /// The type of placeholder -- e.g. `'image'`, `'math'`.
  final String type;

  /// The raw markdown fragment that this placeholder represents, e.g.
  /// `'![alt](path.png)'`.
  final String rawMarkdown;

  const PlaceholderInfo({
    required this.id,
    required this.lineIndex,
    required this.charOffset,
    required this.length,
    required this.type,
    required this.rawMarkdown,
  });
}

/// Tracks placeholder regions in markdown text that correspond to widgets
/// rendered outside the [EditableText].
///
/// When the card body renders markdown content inside a Flutter [TextField] /
/// [EditableText], certain constructs (images, block math) cannot be rendered
/// inline. The card uses transparent Unicode characters as stand-in text and
/// overlays real widgets at the matching screen positions. This class
/// maintains the mapping from character offsets in the raw markdown to the
/// placeholder regions, and is meant to be consumed by
/// [CardOverlayRenderer] to position the overlay widgets correctly.
///
/// ## Lifecycle
///
/// Call [rebuild] whenever the markdown source changes. The tracker
/// discards the previous placeholder list and re-scans from scratch. This is
/// intentionally cheap -- markdown content is typically short (a few hundred
/// characters) and rebuilds happen on every keystroke during editing.
class PlaceholderTracker {
  final List<PlaceholderInfo> _placeholders = [];

  /// Returns an unmodifiable view of all currently tracked placeholders.
  List<PlaceholderInfo> get placeholders => List.unmodifiable(_placeholders);

  /// Re-scans [markdown] for placeholder patterns and replaces the internal
  /// placeholder list.
  ///
  /// Currently detects:
  /// - **Image placeholders**: `![alt](url)` — inline images.
  /// - **Block math placeholders**: `$$...$$` on its own line.
  /// - **Code block placeholders**: fenced code blocks (```lang / ~~~lang).
  /// - **Table placeholders**: pipe tables (| header | ... |).
  ///
  /// If [markdown] is empty the placeholder list is cleared immediately.
  void rebuild(String markdown) {
    _placeholders.clear();
    if (markdown.isEmpty) return;

    final lines = markdown.split('\n');
    var lineOffset = 0;
    for (var i = 0; i < lines.length; i++) {
      _scanLineForPlaceholders(lines[i], i, lineOffset);
      lineOffset += lines[i].length + 1;
    }

    // Scan for multi-line blocks: code fences and tables.
    _placeholders.addAll(scanCodeFences(markdown));
    _placeholders.addAll(scanTables(markdown));
  }

  /// Scans a single [line] for placeholder patterns.
  ///
  /// [lineIndex] is the 0-based line number and [lineOffset] is the absolute
  /// character offset of this line's first character in the full markdown
  /// string.
  void _scanLineForPlaceholders(String line, int lineIndex, int lineOffset) {
    // Inline images: ![alt](url)
    final imageRe = RegExp(r'!\[([^\]]*)\]\(([^)]+)\)');
    for (final m in imageRe.allMatches(line)) {
      _placeholders.add(PlaceholderInfo(
        id: '${lineIndex}_${m.start}',
        lineIndex: lineIndex,
        charOffset: lineOffset + m.start,
        length: m.end - m.start,
        type: 'image',
        rawMarkdown: m.group(0)!,
      ));
    }

    // Block math: $$...$$ on its own line (after trimming whitespace).
    final blockMathRe = RegExp(r'^\$\$[^$]+\$\$$');
    final blockMathMatch = blockMathRe.firstMatch(line.trim());
    if (blockMathMatch != null) {
      _placeholders.add(PlaceholderInfo(
        id: '${lineIndex}_${blockMathMatch.start}',
        lineIndex: lineIndex,
        charOffset: lineOffset + blockMathMatch.start,
        length: blockMathMatch.end - blockMathMatch.start,
        type: 'math',
        rawMarkdown: line,
      ));
    }
  }

  /// Finds the placeholder that contains the given [absoluteOffset] in the
  /// markdown string, or returns `null` if no placeholder covers that offset.
  PlaceholderInfo? findAtOffset(int absoluteOffset) {
    for (final p in _placeholders) {
      if (absoluteOffset >= p.charOffset &&
          absoluteOffset < p.charOffset + p.length) {
        return p;
      }
    }
    return null;
  }

  /// Returns the sum of all placeholder lengths (in characters).
  ///
  /// This is useful for computing the effective "visible text length" of the
  /// markdown after replacing placeholders with stand-in characters.
  int totalPlaceholderChars() {
    int total = 0;
    for (final p in _placeholders) {
      total += p.length;
    }
    return total;
  }

  /// Scans the full markdown for fenced code blocks (```lang / ~~~lang).
  ///
  /// Returns placeholder info for each complete code block found.
  /// The block spans from the opening fence line to the closing fence line.
  List<PlaceholderInfo> scanCodeFences(String markdown) {
    final fences = <PlaceholderInfo>[];
    final lines = markdown.split('\n');
    final fenceRe = RegExp(r'^\s*(```|~~~)(\w*)');
    var inBlock = false;
    var blockStartLine = 0;
    var blockStartOffset = 0;
    var blockLines = <String>[];
    var lineOffset = 0;

    for (var i = 0; i < lines.length; i++) {
      final m = fenceRe.firstMatch(lines[i]);
      if (m != null && !inBlock) {
        // Opening fence
        inBlock = true;
        blockStartLine = i;
        blockStartOffset = lineOffset;
        blockLines = [lines[i]];
      } else if (m != null && inBlock) {
        // Closing fence
        inBlock = false;
        blockLines.add(lines[i]);
        final blockText = blockLines.join('\n');
        fences.add(PlaceholderInfo(
          id: 'code_$blockStartLine',
          lineIndex: blockStartLine,
          charOffset: blockStartOffset,
          length: lineOffset + lines[i].length - blockStartOffset + 1,
          type: 'codeblock',
          rawMarkdown: blockText,
        ));
      } else if (inBlock) {
        blockLines.add(lines[i]);
      }
      lineOffset += lines[i].length + 1;
    }
    return fences;
  }

  /// Scans the full markdown for pipe tables.
  ///
  /// Consecutive lines starting with `|` are grouped as a table block.
  /// Returns placeholder info for each complete table found.
  List<PlaceholderInfo> scanTables(String markdown) {
    final tables = <PlaceholderInfo>[];
    final lines = markdown.split('\n');
    var inTable = false;
    var tableStartLine = 0;
    var tableStartOffset = 0;
    var tableLines = <String>[];
    var lineOffset = 0;

    for (var i = 0; i < lines.length; i++) {
      final isTableRow = lines[i].trimLeft().startsWith('|');
      if (isTableRow && !inTable) {
        inTable = true;
        tableStartLine = i;
        tableStartOffset = lineOffset;
        tableLines = [lines[i]];
      } else if (isTableRow && inTable) {
        tableLines.add(lines[i]);
      } else if (!isTableRow && inTable) {
        inTable = false;
        if (tableLines.length >= 2) {
          final tableText = tableLines.join('\n');
          tables.add(PlaceholderInfo(
            id: 'table_$tableStartLine',
            lineIndex: tableStartLine,
            charOffset: tableStartOffset,
            length: lineOffset - tableStartOffset - 1,
            type: 'table',
            rawMarkdown: tableText,
          ));
        }
      }
      lineOffset += lines[i].length + 1;
    }
    // Handle table at end of text
    if (inTable && tableLines.length >= 2) {
      final tableText = tableLines.join('\n');
      tables.add(PlaceholderInfo(
        id: 'table_$tableStartLine',
        lineIndex: tableStartLine,
        charOffset: tableStartOffset,
        length: lineOffset - tableStartOffset - 1,
        type: 'table',
        rawMarkdown: tableText,
      ));
    }
    return tables;
  }

  /// Scans for Mermaid diagram fences (```mermaid / ```mmd).
  ///
  /// Returns placeholder info for each complete Mermaid block found.
  List<PlaceholderInfo> scanMermaidFences(String markdown) {
    final fences = <PlaceholderInfo>[];
    final lines = markdown.split('\n');
    final mermaidRe = RegExp(r'^\s*```\s*(mermaid|mmd)\s*$', caseSensitive: false);
    final closingRe = RegExp(r'^\s*```\s*$');
    var inBlock = false;
    var blockStartLine = 0;
    var blockStartOffset = 0;
    var blockLines = <String>[];
    var lineOffset = 0;

    for (var i = 0; i < lines.length; i++) {
      final isMermaidOpen = mermaidRe.firstMatch(lines[i]);
      if (isMermaidOpen != null && !inBlock) {
        inBlock = true;
        blockStartLine = i;
        blockStartOffset = lineOffset;
        blockLines = [lines[i]];
      } else if (inBlock && closingRe.firstMatch(lines[i]) != null) {
        // Closing fence
        inBlock = false;
        blockLines.add(lines[i]);
        final blockText = blockLines.join('\n');
        fences.add(PlaceholderInfo(
          id: 'mermaid_$blockStartLine',
          lineIndex: blockStartLine,
          charOffset: blockStartOffset,
          length: lineOffset + lines[i].length - blockStartOffset + 1,
          type: 'mermaid',
          rawMarkdown: blockText,
        ));
      } else if (inBlock) {
        blockLines.add(lines[i]);
      }
      lineOffset += lines[i].length + 1;
    }
    return fences;
  }
}
