import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../core/models.dart';
import 'repository.dart';

const platform = MethodChannel('com.trailcapsule.app/native');
final controllerProvider = ChangeNotifierProvider<CapsuleController>(
  (ref) => throw UnimplementedError('Override at startup'),
);

class CapsuleController extends ChangeNotifier {
  CapsuleController(this.repository, this.data);
  final TravelRepository repository;
  TravelState data;
  bool busy = false;
  String? inboxError;
  static Future<CapsuleController> open() async {
    final root = await getApplicationSupportDirectory();
    await root.create(recursive: true);
    try {
      await platform.invokeMethod('protectStorage', {'path': root.path});
    } on MissingPluginException {
      /* Tests/unsupported host. */
    }
    final repo = TravelRepository(root);
    return CapsuleController(repo, await repo.load());
  }

  Future<T> run<T>(Future<T> Function() task) async {
    if (busy) throw StateError('正在保存，请稍后再试');
    busy = true;
    notifyListeners();
    try {
      return await task();
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> update(void Function(TravelState) edit) => run(() async {
    final next = data.copy();
    edit(next);
    await repository.save(next);
    data = next;
    // Committed metadata is authoritative. Cleanup is retried at next startup.
    try {
      await repository.cleanup(next);
    } on FileSystemException {
      /* retry */
    }
  });
  Future<void> importFile(String path, String name, String tripId) =>
      run(() async {
        final item = await repository.importFile(path, name, tripId);
        final next = data.copy()..items.add(item);
        try {
          await repository.save(next);
          data = next;
        } catch (_) {
          await repository.cleanup(data);
          rethrow;
        }
      });
  Future<void> restore(File file) => run(() async {
    data = await repository.restore(file, data);
  });
  Future<void> readInbox() async {
    if (busy) return;
    try {
      inboxError = null;
      final jobs = await platform.invokeListMethod<dynamic>('readInbox') ?? [];
      if (jobs.isEmpty) {
        notifyListeners();
        return;
      }
      await run(() async {
        final next = data.copy();
        final acknowledged = <String>[];
        for (final raw in jobs) {
          final job = Map<String, dynamic>.from(raw as Map);
          final id = job['id'] as String;
          if (next.consumed.contains(id)) {
            acknowledged.add(id);
            continue;
          }
          try {
            TravelItem item;
            if (job['path'] != null) {
              item = await repository.importFile(
                job['path'],
                job['name'] ?? '资料',
                '',
              );
            } else {
              final text = (job['text'] ?? '') as String;
              if (text.trim().isEmpty) continue;
              item = TravelItem(
                id: newId(),
                tripId: '',
                title: (job['name'] ?? '分享的文字') as String,
                body: text,
                createdAt: DateTime.now().millisecondsSinceEpoch,
              );
            }
            next.items.add(item);
            next.consumed.add(id);
            acknowledged.add(id);
          } catch (_) {
            inboxError = '部分分享资料暂时无法导入，请确认原文件仍可读取后重试。';
          }
        }
        await repository.save(next);
        data = next;
        if (acknowledged.isNotEmpty)
          await platform.invokeMethod('ackInbox', {'ids': acknowledged});
      });
    } on MissingPluginException {
      /* Desktop test host has no native inbox. */
    } catch (_) {
      inboxError = '分享收件箱暂时无法读取，请稍后重试。';
      notifyListeners();
    }
  }
}
