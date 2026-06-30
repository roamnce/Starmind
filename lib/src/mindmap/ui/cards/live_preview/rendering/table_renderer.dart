import 'package:flutter/material.dart';

/// Renders a markdown pipe table as a Flutter Table widget.
///
/// Supports header row bold styling + bottom separator + column alignment.
/// Wraps in a horizontally scrollable container for overflow.
class TableRenderer extends StatelessWidget {
  /// Column header texts.
  final List<String> headers;

  /// Data rows (each row is a list of cell texts).
  final List<List<String>> rows;

  /// Column alignments — one per column.
  final List<TextAlign> columnAligns;

  /// Maximum width constraint for the table.
  final double maxWidth;

  const TableRenderer({
    super.key,
    required this.headers,
    required this.rows,
    required this.columnAligns,
    required this.maxWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: maxWidth,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          border: TableBorder.all(
            color: const Color(0x33FFFFFF),
            width: 0.5,
          ),
          children: [
            // Header row
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0x0FFFFFFF),
              ),
              children: List.generate(
                headers.length,
                (i) => _cell(headers[i], i < columnAligns.length ? columnAligns[i] : TextAlign.left, isHeader: true),
              ),
            ),
            // Data rows
            for (final row in rows)
              TableRow(
                children: List.generate(
                  row.length,
                  (i) => _cell(row[i], i < columnAligns.length ? columnAligns[i] : TextAlign.left),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(String text, TextAlign align, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
          color: const Color(0xFFE6EDF3),
        ),
        textAlign: align,
      ),
    );
  }
}

/// Result of parsing a markdown pipe table.
class TableParseResult {
  final List<String> headers;
  final List<List<String>> rows;
  final List<TextAlign> columnAligns;

  const TableParseResult({
    required this.headers,
    required this.rows,
    required this.columnAligns,
  });

  bool get isEmpty => headers.isEmpty;

  static TableParseResult empty() => const TableParseResult(
        headers: [],
        rows: [],
        columnAligns: [],
      );
}

/// Parses markdown pipe table text into structured data.
class MarkdownTableParser {
  /// Parse pipe table text into headers, rows, and column alignments.
  ///
  /// Input example:
  /// ```
  /// | Name | Age | City |
  /// |------|-----|------|
  /// | Alice | 30 | NYC |
  /// ```
  static TableParseResult parse(String tableText) {
    final lines = tableText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.startsWith('|') && l.endsWith('|'))
        .toList();

    if (lines.length < 2) return TableParseResult.empty();

    final header = _splitRow(lines[0]);
    final aligns = _parseAligns(lines[1], header.length);

    final rows = <List<String>>[];
    for (var i = 2; i < lines.length; i++) {
      final cells = _splitRow(lines[i]);
      if (cells.isNotEmpty && cells.length == header.length) {
        rows.add(cells);
      }
    }

    return TableParseResult(
      headers: header,
      rows: rows,
      columnAligns: aligns,
    );
  }

  static List<String> _splitRow(String line) {
    // Strip leading and trailing | then split by |
    final content = line.substring(1, line.length - 1);
    return content.split('|').map((s) => s.trim()).toList();
  }

  static List<TextAlign> _parseAligns(String alignLine, int count) {
    final cells = _splitRow(alignLine);
    return List.generate(
      count,
      (i) {
        if (i >= cells.length) return TextAlign.left;
        final cell = cells[i].trim();
        if (cell.startsWith(':') && cell.endsWith(':')) {
          return TextAlign.center;
        } else if (cell.endsWith(':')) {
          return TextAlign.right;
        }
        return TextAlign.left;
      },
    );
  }
}
