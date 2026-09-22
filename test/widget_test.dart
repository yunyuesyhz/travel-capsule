import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:trail_capsule/main.dart';
import 'package:trail_capsule/core/models.dart';
import 'package:trail_capsule/data/controller.dart';
import 'package:trail_capsule/data/repository.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  testWidgets('create trip, save note, search and open address card', (
    tester,
  ) async {
    return tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('capsule-ui-');
      final repo = TravelRepository(temp);
      final state = await repo.load();
      final controller = CapsuleController(repo, state);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        platform,
        (call) async => call.method == 'readInbox' ? [] : null,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [controllerProvider.overrideWith((ref) => controller)],
          child: const CapsuleApp(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('创建我的第一段旅行'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('创建我的第一段旅行'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '京都小旅行');
      await tester.enterText(find.byType(TextFormField).at(1), '日本 · 京都');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-save')));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      expect(find.text('今天，安心出发。'), findsOneWidget);
      await tester.tap(find.text('收进胶囊'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      await tester.tap(find.text('文字、链接或地址'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), '酒店地址');
      await tester.enterText(find.byType(TextFormField).at(2), '京都駅');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('editor-save')));
      for (var i = 0; i < 50; i++) {
        if (controller.data.items.isNotEmpty && !controller.busy) break;
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      await tester.pumpAndSettle();
      expect(controller.data.items.single.address, '京都駅');
      await tester.tap(find.text('资料袋'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('酒店地址'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.drag(find.byType(ListView).first, const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(find.text('酒店地址'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      await tester.tap(find.text('给司机看'));
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      expect(find.text('PLEASE SHOW THIS CARD'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repo.close();
      await temp.delete(recursive: true);
    });
  });
  testWidgets('all tabs fit a narrow screen with large text', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('capsule-large-');
      final repo = TravelRepository(temp);
      await repo.load();
      final controller = CapsuleController(
        repo,
        TravelState(
          trips: [
            Trip(id: 't', name: '一段很长名字的旅行，让界面也能从容显示', destination: '京都'),
          ],
          selected: 't',
        ),
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        platform,
        (call) async => [],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [controllerProvider.overrideWith((ref) => controller)],
          child: const CapsuleApp(),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();
      for (final title in ['资料袋', '行程', '应急卡', '路上']) {
        await tester.tap(find.text(title));
        await Future<void>.delayed(const Duration(milliseconds: 80));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      await repo.close();
      await temp.delete(recursive: true);
    });
  });
}
