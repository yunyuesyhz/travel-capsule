import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trail_capsule/main.dart';

void main() {
  testWidgets('app notice animates in and out', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => showAppNotice(context, '文件上传成功'),
                child: const Text('显示提示'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('显示提示'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final toastText = find.text('文件上传成功');
    final fade = find.ancestor(
      of: toastText,
      matching: find.byType(FadeTransition),
    );
    final slide = find.ancestor(
      of: toastText,
      matching: find.byType(SlideTransition),
    );
    expect(toastText, findsOneWidget);
    expect(fade, findsOneWidget);
    expect(slide, findsOneWidget);
    final renderedText = find.descendant(
      of: toastText,
      matching: find.byType(RichText),
    );
    expect(renderedText, findsOneWidget);
    expect(
      tester.widget<RichText>(renderedText).text.style?.decoration,
      TextDecoration.none,
    );
    final entranceOpacity = tester.widget<FadeTransition>(fade).opacity.value;
    final entranceOffset = tester
        .widget<SlideTransition>(slide)
        .position
        .value
        .dy;
    expect(entranceOpacity, greaterThan(0));
    expect(entranceOpacity, lessThan(1));
    expect(entranceOffset, greaterThan(0));
    expect(entranceOffset, lessThan(.55));

    await tester.pump(const Duration(milliseconds: 2750));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 100));
    final exitOpacity = tester.widget<FadeTransition>(fade).opacity.value;
    final exitOffset = tester.widget<SlideTransition>(slide).position.value.dy;
    expect(exitOpacity, lessThan(entranceOpacity));
    expect(exitOpacity, greaterThan(0));
    expect(exitOffset, greaterThan(entranceOffset));
    expect(exitOffset, lessThan(.55));

    await tester.pump(const Duration(milliseconds: 220));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
    expect(toastText, findsNothing);
  });
}
