import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:trail_capsule/core/models.dart';
import 'package:trail_capsule/data/controller.dart';
import 'package:trail_capsule/data/repository.dart';
import 'package:trail_capsule/main.dart';

void main() {
  setUpAll(tz.initializeTimeZones);

  testWidgets('tab content fades through while the shared indicator moves', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final temp = await Directory.systemTemp.createTemp('capsule-tabs-');
      final repository = TravelRepository(temp);
      await repository.load();
      final controller = CapsuleController(
        repository,
        TravelState(
          trips: [Trip(id: 'trip', name: '京都，慢慢走', destination: '京都')],
          selected: 'trip',
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
      await Future<void>.delayed(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();

      final indicator = find.byKey(const Key('tab-selection-indicator'));
      final initialIndicatorX = tester.getCenter(indicator).dx;
      await tester.tap(find.text('资料袋'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final outgoing = tester.widget<Opacity>(
        find.byKey(const ValueKey('tab-opacity-0')),
      );
      final incoming = tester.widget<Opacity>(
        find.byKey(const ValueKey('tab-opacity-1')),
      );
      expect(outgoing.opacity, closeTo(0, .01));
      expect(incoming.opacity, greaterThan(0));
      expect(incoming.opacity, lessThan(1));
      expect(tester.getCenter(indicator).dx, greaterThan(initialIndicatorX));

      await tester.pumpAndSettle();
      final settledIndicatorX = tester.getCenter(indicator).dx;
      expect(settledIndicatorX, greaterThan(initialIndicatorX));
      expect(find.text('我的资料袋'), findsOneWidget);

      final gesture = await tester.startGesture(const Offset(180, 360));
      await tester.pump();
      await gesture.moveBy(const Offset(22, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(22, 0));
      await tester.pump();
      expect(tester.getCenter(indicator).dx, lessThan(settledIndicatorX));
      await gesture.moveBy(const Offset(28, 0));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(find.text('今天，安心出发。'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        platform,
        null,
      );
      await repository.close();
      await temp.delete(recursive: true);
    });
  });
}
