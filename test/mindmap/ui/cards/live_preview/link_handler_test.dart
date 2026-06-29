import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/cards/live_preview/link_handler.dart';

void main() {
  /// Helper that checks if any LinkInfo in [links] contains [offset].
  LinkInfo? linkInRange(List<LinkInfo> links, int offset) {
    return LinkHandler.isLinkAtOffset(links, offset);
  }

  group('LinkHandler', () {
    test('extractLinks finds [text](url) patterns', () {
      final links = LinkHandler.extractLinks('see [example](https://example.com) for details');
      expect(links.length, 1);
      expect(links.first.text, 'example');
      expect(links.first.url, 'https://example.com');
    });

    test('extractLinks returns empty for plain text', () {
      final links = LinkHandler.extractLinks('plain text without links');
      expect(links.isEmpty, true);
    });

    test('isLinkAtOffset detects cursor on link', () {
      final links = LinkHandler.extractLinks('[test](http://x.com)');
      // startOffset=0, endOffset=20 (the full [test](http://x.com))
      expect(linkInRange(links, 0), isNotNull); // '['
      expect(linkInRange(links, 19), isNotNull); // last ')'
      expect(linkInRange(links, 20), isNull);    // past end
    });

    test('extractLinks with multiple links', () {
      final links = LinkHandler.extractLinks('[a](http://a.com) and [b](http://b.com)');
      expect(links.length, 2);
      expect(links[0].url, 'http://a.com');
      expect(links[1].url, 'http://b.com');
    });
  });
}
