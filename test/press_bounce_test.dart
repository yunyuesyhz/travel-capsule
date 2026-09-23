import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trail_capsule/main.dart';

void main() {
  testWidgets('styled button compresses and springs back after a tap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: FilledButton(
              style: glassFilledButtonStyle(),
              onPressed: () => taps++,
              child: const Text('收进胶囊'),
            ),
          ),
        ),
      ),
    );

    final button = find.text('收进胶囊');
    final bounce = find.ancestor(
      of: button,
      matching: find.byType(PressBounce),
    );
    expect(bounce, findsOneWidget);
    double scale() => tester
        .widget<ScaleTransition>(
          find.descendant(of: bounce, matching: find.byType(ScaleTransition)),
        )
        .scale
        .value;

    final gesture = await tester.startGesture(tester.getCenter(button));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(scale(), closeTo(.96, .005));

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 65));
    await tester.pump(const Duration(milliseconds: 140));
    expect(taps, 1);
    expect(scale(), greaterThan(.96));

    await tester.pump(const Duration(milliseconds: 500));
    expect(scale(), closeTo(1, .005));
  });

  testWidgets('scrolling a tappable card releases its pressed state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: PressBounce(
              child: InkWell(
                onTap: () {},
                child: const SizedBox(
                  width: 180,
                  height: 80,
                  child: Text('卡片'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final bounce = find.byType(PressBounce);
    final scale = find.descendant(
      of: bounce,
      matching: find.byType(ScaleTransition),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('卡片')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    expect(tester.widget<ScaleTransition>(scale).scale.value, lessThan(1));

    await gesture.moveBy(const Offset(0, -35));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(tester.widget<ScaleTransition>(scale).scale.value, closeTo(1, .005));
    await gesture.up();
  });
}
