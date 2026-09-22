import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:trail_capsule/main.dart' as app;
import 'package:trail_capsule/data/controller.dart';
import 'package:trail_capsule/features/home.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('offline trip, local attachment, backup restore and all tabs', (
    tester,
  ) async {
    await app.main();
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.byType(HomeScreen)),
    );
    final controller = container.read(controllerProvider);
    if (controller.data.activeTrip == null) {
      await tester.scrollUntilVisible(
        find.text('先看看示例旅行'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('先看看示例旅行'));
      await tester.pumpAndSettle();
    }
    await tester.pump(const Duration(seconds: 1));
    if (Platform.isAndroid) await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('01-home');
    await tester.tap(find.text('资料袋'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('02-library');
    await tester.tap(find.text('行程'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('03-itinerary');
    await tester.tap(find.text('应急卡'));
    await tester.pumpAndSettle();
    await binding.takeScreenshot('04-emergency');
    final temp = await getTemporaryDirectory();
    final pdf = File('${temp.path}/smoke.pdf');
    await pdf.writeAsString(samplePdf());
    await controller.importFile(
      pdf.path,
      '离线存储验证.pdf',
      controller.data.activeTrip!.id,
    );
    await pdf.delete();
    expect(
      await controller.repository
          .fileFor(controller.data.items.last.filePath)
          .exists(),
      true,
    );
    final backup = await controller.repository.exportBackup(
      controller.data,
      Directory('${temp.path}/smoke-backup'),
    );
    final before = controller.data.trips.length;
    await controller.restore(backup);
    expect(controller.data.trips.length, greaterThan(before));
    await tester.tap(find.text('路上'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

String samplePdf() {
  const stream = 'BT /F1 18 Tf 40 150 Td (Travel Capsule - Offline Test) Tj ET';
  final objects = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 360 220] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];
  var text = '%PDF-1.4\n';
  final offsets = <int>[0];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(text.length);
    text += '${i + 1} 0 obj\n${objects[i]}\nendobj\n';
  }
  final xref = text.length;
  text += 'xref\n0 ${objects.length + 1}\n0000000000 65535 f \n';
  for (final offset in offsets.skip(1)) {
    text += '${offset.toString().padLeft(10, '0')} 00000 n \n';
  }
  return '$text'
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n';
}
