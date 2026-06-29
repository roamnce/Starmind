import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/mindmap/ui/cards/live_preview/placeholder_tracker.dart';

void main() {
  group('PlaceholderTracker', () {
    test('rebuild detects image placeholders', () {
      final tracker = PlaceholderTracker();
      tracker.rebuild('text ![alt](path/to/image.png) more text');
      expect(tracker.placeholders.length, 1);
      expect(tracker.placeholders.first.type, 'image');
      expect(
          tracker.placeholders.first.rawMarkdown, '![alt](path/to/image.png)');
    });

    test('rebuild detects multiple placeholders', () {
      final tracker = PlaceholderTracker();
      tracker.rebuild('![a](1.png) text ![b](2.png)');
      expect(tracker.placeholders.length, 2);
    });

    test('rebuild with no placeholders returns empty', () {
      final tracker = PlaceholderTracker();
      tracker.rebuild('plain text without images');
      expect(tracker.placeholders.isEmpty, true);
    });

    test('findAtOffset returns correct placeholder', () {
      final tracker = PlaceholderTracker();
      tracker.rebuild('prefix ![img](a.png) suffix');
      final found = tracker.findAtOffset(8);
      expect(found, isNotNull);
      expect(found!.type, 'image');
    });

    test('findAtOffset returns null for non-placeholder offset', () {
      final tracker = PlaceholderTracker();
      tracker.rebuild('prefix ![img](a.png) suffix');
      final found = tracker.findAtOffset(2);
      expect(found, isNull);
    });

    test('totalPlaceholderChars sums all placeholder lengths', () {
      final tracker = PlaceholderTracker();
      tracker.rebuild('![a](x.png)![b](y.png)');
      expect(tracker.totalPlaceholderChars(), 22);
    });
  });
}
