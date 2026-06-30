import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:starmind/src/mindmap/ui/cards/live_preview/rendering/table_renderer.dart';

void main() {
  group('TableRenderer', () {
    testWidgets('renders simple table', (tester) async {
      final headers = ['Name', 'Age', 'City'];
      final rows = [
        ['Alice', '30', 'NYC'],
      ];
      final aligns = [TextAlign.left, TextAlign.right, TextAlign.center];
      await tester.pumpWidget(
        MaterialApp(
          home: TableRenderer(
            headers: headers,
            rows: rows,
            columnAligns: aligns,
            maxWidth: 400,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Alice'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
    });

    testWidgets('renders multiple rows', (tester) async {
      final headers = ['Col1', 'Col2'];
      final rows = [
        ['a', 'b'],
        ['c', 'd'],
      ];
      final aligns = [TextAlign.left, TextAlign.left];
      await tester.pumpWidget(
        MaterialApp(
          home: TableRenderer(
            headers: headers,
            rows: rows,
            columnAligns: aligns,
            maxWidth: 400,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('a'), findsOneWidget);
      expect(find.text('c'), findsOneWidget);
    });
  });

  group('MarkdownTableParser', () {
    test('parses simple pipe table', () {
      const tableText = '| Name | Age | City |\n'
          '|------|-----|------|\n'
          '| Alice | 30 | NYC |';
      final result = MarkdownTableParser.parse(tableText);
      expect(result.isEmpty, false);
      expect(result.headers, ['Name', 'Age', 'City']);
      expect(result.rows.length, 1);
      expect(result.rows.first, ['Alice', '30', 'NYC']);
    });

    test('parses alignment markers', () {
      const tableText = '| A | B | C |\n'
          '|:---|:---:|---:|\n'
          '| x | y | z |';
      final result = MarkdownTableParser.parse(tableText);
      expect(result.columnAligns[0], TextAlign.left);
      expect(result.columnAligns[1], TextAlign.center);
      expect(result.columnAligns[2], TextAlign.right);
    });

    test('returns empty for insufficient lines', () {
      const tableText = '| single line |';
      final result = MarkdownTableParser.parse(tableText);
      expect(result.isEmpty, true);
    });

    test('parses empty table text as empty', () {
      final result = MarkdownTableParser.parse('');
      expect(result.isEmpty, true);
    });
  });
}
