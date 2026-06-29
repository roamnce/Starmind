import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:starmind/src/mindmap/ui/cards/live_preview/card_overlay_renderer.dart';
import 'package:starmind/src/mindmap/ui/cards/live_preview/placeholder_tracker.dart';

void main() {
  group('CardOverlayRenderer', () {
    testWidgets('renders nothing when no placeholders', (tester) async {
      final tracker = PlaceholderTracker();
      tracker.rebuild('no placeholders here');
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 400,
            height: 600,
            child: CardOverlayRenderer(
              markdown: 'no placeholders here',
              maxWidth: 380,
              placeholderTracker: tracker,
              textFieldKey: GlobalKey(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CardOverlayRenderer), findsOneWidget);
    });
  });
}