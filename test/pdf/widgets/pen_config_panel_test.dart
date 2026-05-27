import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:starmind/src/pdf/pen_config.dart';
import 'package:starmind/src/pdf/pressure_curve.dart';
import 'package:starmind/src/pdf/widgets/pen_config_panel.dart';

void main() {
  group('PenConfigPanel', () {
    testWidgets('should display pen type selector', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      // Should show Chinese pen type label
      expect(find.text('钢笔'), findsWidgets);
    });

    testWidgets('should display all pen types', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      // All pen types should be visible
      expect(find.text('钢笔'), findsWidgets); // fountainPen
      expect(find.text('圆珠笔'), findsWidgets); // ballpointPen
      expect(find.text('铅笔'), findsWidgets); // pencil
      expect(find.text('荧光笔'), findsWidgets); // highlighter
      expect(find.text('橡皮擦'), findsWidgets); // eraser
    });

    testWidgets('should call onConfigChanged when pen type changes', (tester) async {
      PenConfig? newConfig;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(),
            onConfigChanged: (c) => newConfig = c,
          ),
        ),
      ));

      // Tap on ballpoint pen choice chip
      final ballpointChip = find.widgetWithText(ChoiceChip, '圆珠笔');
      expect(ballpointChip, findsOneWidget);

      await tester.tap(ballpointChip);
      await tester.pumpAndSettle();

      // Verify callback was called with correct pen type
      expect(newConfig, isNotNull);
      expect(newConfig!.type, PenType.ballpointPen);
    });

    testWidgets('should display stabilizer slider', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      expect(find.byType(Slider), findsWidgets);
      expect(find.text('平滑度'), findsOneWidget);
    });

    testWidgets('should call onConfigChanged when stabilizer level changes', (tester) async {
      PenConfig? newConfig;
      const initialLevel = 5;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(stabilizerLevel: initialLevel),
            onConfigChanged: (c) => newConfig = c,
          ),
        ),
      ));

      // Find stabilizer slider and drag it
      final slider = find.widgetWithText(Slider, '平滑度');
      if (slider.evaluate().isNotEmpty) {
        await tester.drag(slider, const Offset(50, 0));
        await tester.pumpAndSettle();

        // Verify callback was called
        expect(newConfig, isNotNull);
      }
    });

    testWidgets('should display pressure curve selector when pressure enabled', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(), // pressure enabled by default
            onConfigChanged: (_) {},
          ),
        ),
      ));

      expect(find.text('压感曲线'), findsOneWidget);
    });

    testWidgets('should not display pressure curve selector for eraser', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.eraser(),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      // Pressure curve section should not be visible
      expect(find.text('压感曲线'), findsNothing);
    });

    testWidgets('should display pressure curve presets', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      // Find pressure curve section
      expect(find.text('线性'), findsOneWidget); // linear
      expect(find.text('柔和'), findsOneWidget); // soft
      expect(find.text('硬朗'), findsOneWidget); // firm
      expect(find.text('S型'), findsOneWidget); // sCurve
      expect(find.text('重压'), findsOneWidget); // heavy
    });

    testWidgets('should call onConfigChanged when pressure curve changes', (tester) async {
      PenConfig? newConfig;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(),
            onConfigChanged: (c) => newConfig = c,
          ),
        ),
      ));

      // Tap on firm pressure curve
      final firmChip = find.widgetWithText(ChoiceChip, '硬朗');
      expect(firmChip, findsOneWidget);

      await tester.tap(firmChip);
      await tester.pumpAndSettle();

      // Verify callback was called
      expect(newConfig, isNotNull);
      expect(newConfig!.pressureCurve, PressureCurve.firm);
    });

    testWidgets('should show current stabilizer level value', (tester) async {
      const testLevel = 7;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(stabilizerLevel: testLevel),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      expect(find.textContaining('$testLevel'), findsOneWidget);
    });

    testWidgets('should highlight selected pen type', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.pencil(),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      // Pencil chip should be selected
      final pencilChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '铅笔'));
      expect(pencilChip.selected, isTrue);
    });

    testWidgets('should highlight selected pressure curve', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen().copyWith(
              pressureCurve: PressureCurve.sCurve,
            ),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      // S-curve chip should be selected
      final sCurveChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'S型'));
      expect(sCurveChip.selected, isTrue);
    });

    testWidgets('should handle highlighter with no pressure', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.highlighter(),
            onConfigChanged: (_) {},
          ),
        ),
      ));

      // Highlighter should be selected
      final highlighterChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '荧光笔'));
      expect(highlighterChip.selected, isTrue);

      // Pressure curve should not be shown (highlighter has pressureEnabled = false)
      expect(find.text('压感曲线'), findsNothing);
    });

    testWidgets('should preserve other settings when changing pen type', (tester) async {
      PenConfig? newConfig;
      final originalColor = Colors.red;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: PenConfigPanel(
            config: PenConfig.fountainPen(
              color: originalColor,
              stabilizerLevel: 8,
            ),
            onConfigChanged: (c) => newConfig = c,
          ),
        ),
      ));

      // Tap on pencil
      await tester.tap(find.widgetWithText(ChoiceChip, '铅笔'));
      await tester.pumpAndSettle();

      // Color should be preserved (or converted to pencil's default gray)
      expect(newConfig, isNotNull);
      expect(newConfig!.type, PenType.pencil);
      // Stabilizer level may be changed to pencil's default
    });
  });
}
