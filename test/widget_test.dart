/// 🤖 Generated wholly or partially with Gemini Code; Google Antigravity
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/main.dart';

void main() {
  testWidgets('OrbBackground rendering test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: OrbBackground(isDark: true),
        ),
      ),
    );

    expect(find.byType(OrbBackground), findsOneWidget);
  });
}

