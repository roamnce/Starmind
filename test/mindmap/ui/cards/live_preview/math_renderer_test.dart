import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:starmind/src/mindmap/ui/cards/live_preview/rendering/math_renderer.dart';

void main() {
  group('MathRenderer', () {
    testWidgets('renders block math display', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MathRenderer(
            tex: r'E = mc^2',
            isBlock: true,
            maxWidth: 400,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MathRenderer), findsOneWidget);
    });

    testWidgets('renders inline math display', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MathRenderer(
            tex: r'\alpha + \beta',
            isBlock: false,
            maxWidth: 400,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(MathRenderer), findsOneWidget);
    });
  });

  group('MathExtractor', () {
    test('extracts inline math', () {
      const text = r'Hello $x + y$ world';
      final matches = MathExtractor.extractInline(text);
      expect(matches.length, 1);
      expect(matches.first.tex, 'x + y');
      expect(matches.first.isBlock, false);
    });

    test('extracts multiple inline math expressions', () {
      const text = r'$a$ and $b$';
      final matches = MathExtractor.extractInline(text);
      expect(matches.length, 2);
    });

    test('does not extract block math as inline', () {
      const text = r'$$E = mc^2$$';
      final matches = MathExtractor.extractInline(text);
      expect(matches.isEmpty, true);
    });

    test('extracts block math', () {
      const text = r'$$E = mc^2$$';
      final matches = MathExtractor.extractBlock(text);
      expect(matches.length, 1);
      expect(matches.first.tex, 'E = mc^2');
      expect(matches.first.isBlock, true);
    });

    test('returns empty for plain text', () {
      const text = 'plain text without math';
      expect(MathExtractor.extractInline(text).isEmpty, true);
      expect(MathExtractor.extractBlock(text).isEmpty, true);
    });
  });
}
