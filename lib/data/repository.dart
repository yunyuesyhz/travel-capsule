import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import '../core/models.dart';

class CapsuleDatabase extends GeneratedDatabase {
  CapsuleDatabase(super.e);
  @override
  int get schemaVersion => 1;
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => const [];
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await customStatement(
        'CREATE TABLE records (id TEXT PRIMARY KEY, kind TEXT NOT NULL, payload TEXT NOT NULL)',
      );
    },
  );
}

class TravelRepository {
  TravelRepository(this.root, {CapsuleDatabase? database})
    : db =
          database ??
          CapsuleDatabase(
            NativeDatabase(File(p.join(root.path, 'capsule.sqlite'))),
          );
  final Directory root;
  final CapsuleDatabase db;
  static const fileLimit = 50 * 1024 * 1024;
  static const backupLimit = 200 * 1024 * 1024;
  static const extensions = [
    'pdf',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'heic',
    'heif',
  ];
  Future<TravelState> load() async {
    await root.create(recursive: true);
    await Directory(p.join(root.path, 'attachments')).create(recursive: true);
    final rows = await db
        .customSelect('SELECT kind,payload FROM records')
        .get();
    final j = <String, dynamic>{
      'schemaVersion': 1,
      'trips': [],
      'items': [],
      'stops': [],
      'consumed': [],
      'selected': '',
    };
    for (final row in rows) {
      final value = jsonDecode(row.read<String>('payload'));
      final kind = row.read<String>('kind');
      if (kind == 'meta') {
        j['selected'] = value['selected'];
        j['consumed'] = value['consumed'];
      } else {
        (j[kind] as List).add(value);
      }
    }
    final state = TravelState.fromJson(j);
    await cleanup(state);
    return state;
  }

  Future<void> save(TravelState state) async {
    await db.transaction(() async {
      await db.customStatement('DELETE FROM records');
      Future<void> put(String id, String kind, Object value) =>
          db.customStatement(
            'INSERT INTO records(id,kind,payload) VALUES(?,?,?)',
            [id, kind, jsonEncode(value)],
          );
      for (final x in state.trips) {
        await put('trip:${x.id}', 'trips', x.toJson());
      }
      for (final x in state.items) {
        await put('item:${x.id}', 'items', x.toJson());
      }
      for (final x in state.stops) {
        await put('stop:${x.id}', 'stops', x.toJson());
      }
      await put('meta', 'meta', {
        'selected': state.selected,
        'consumed': state.consumed,
      });
    });
  }

  File fileFor(String relative) {
    if (!RegExp(r'^attachments/[a-zA-Z0-9_-]+\.[a-z0-9]+$').hasMatch(relative))
      throw const FormatException('附件路径无效');
    return File(p.join(root.path, relative));
  }

  Future<TravelItem> importFile(
    String source,
    String originalName,
    String tripId,
  ) async {
    final ext = p.extension(originalName).toLowerCase().replaceFirst('.', '');
    if (!extensions.contains(ext))
      throw const FormatException('支持 PDF、JPG、PNG、WebP 和 HEIC 图片');
    final input = File(source);
    final size = await input.length();
    if (size == 0 || size > fileLimit)
      throw const FormatException('单个文件须大于 0 且不超过 50 MB');
    final id = newId();
    final relative = 'attachments/$id.$ext';
    final target = fileFor(relative);
    await target.parent.create(recursive: true);
    final temp = File('${target.path}.part');
    try {
      final sink = temp.openWrite();
      var bytes = 0;
      try {
        await for (final chunk in input.openRead()) {
          bytes += chunk.length;
          if (bytes > fileLimit) throw const FormatException('文件超过 50 MB');
          sink.add(chunk);
        }
      } finally {
        await sink.close();
      }
      if (bytes == 0) throw const FormatException('文件内容为空');
      final digest = (await sha256.bind(temp.openRead()).first).toString();
      await temp.rename(target.path);
      return TravelItem(
        id: id,
        tripId: tripId,
        title: p.basenameWithoutExtension(originalName),
        fileName: p.basename(originalName),
        filePath: relative,
        digest: digest,
        bytes: bytes,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  }

  Future<void> cleanup(TravelState state) async {
    final keep = state.items
        .where((i) => i.hasFile)
        .map((i) => i.filePath)
        .toSet();
    final dir = Directory(p.join(root.path, 'attachments'));
    if (!await dir.exists()) return;
    await for (final f in dir.list()) {
      if (f is File && !keep.contains(p.relative(f.path, from: root.path))) {
        await f.delete();
      }
    }
  }

  Future<File> exportBackup(TravelState state, Directory output) async {
    final archive = Archive();
    final manifest = utf8.encode(jsonEncode(state.toJson()));
    archive.addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    var total = manifest.length;
    for (final i in state.items.where((i) => i.hasFile)) {
      final f = fileFor(i.filePath);
      final length = await f.length();
      total += length;
      if (total > backupLimit)
        throw const FormatException('首版单次备份上限为 200 MB，请先整理资料');
      final data = await f.readAsBytes();
      if (sha256.convert(data).toString() != i.digest)
        throw FormatException('附件校验失败：${i.title}');
      archive.addFile(ArchiveFile(i.filePath, data.length, data));
    }
    await output.create(recursive: true);
    final result = File(
      p.join(output.path, '旅途胶囊-${DateTime.now().millisecondsSinceEpoch}.zip'),
    );
    await result.writeAsBytes(await compute(_encodeZip, archive), flush: true);
    return result;
  }

  // Restore as new trips: never overwrite existing user records.
  Future<TravelState> restore(File zip, TravelState current) async {
    if (await zip.length() > backupLimit)
      throw const FormatException('备份超过 200 MB');
    final archive = ZipDecoder().decodeBytes(
      await zip.readAsBytes(),
      verify: true,
    );
    var total = 0;
    final names = <String>{};
    for (final entry in archive) {
      if (!entry.isFile || entry.isSymbolicLink || !names.add(entry.name))
        throw const FormatException('备份包含无效条目');
      if (entry.name != 'manifest.json') fileFor(entry.name);
      total += entry.size;
      if (total > backupLimit || entry.size > fileLimit)
        throw const FormatException('备份解压后超过大小限制');
    }
    final manifest = archive.findFile('manifest.json');
    if (manifest == null || manifest.size > 5 * 1024 * 1024)
      throw const FormatException('找不到有效备份清单');
    final restored = TravelState.fromJson(
      jsonDecode(utf8.decode(manifest.content)) as Json,
    );
    final result = current.copy();
    final ids = <String, String>{};
    final written = <File>[];
    try {
      for (final t in restored.trips) {
        final j = t.toJson();
        ids[t.id] = newId();
        j['id'] = ids[t.id];
        j['name'] = '${t.name}（恢复）';
        result.trips.add(Trip.fromJson(j));
      }
      for (final i in restored.items) {
        final j = i.toJson();
        ids[i.id] = newId();
        j['id'] = ids[i.id];
        j['tripId'] = ids[i.tripId] ?? '';
        if (i.hasFile) {
          fileFor(i.filePath);
          final entry = archive.findFile(i.filePath);
          if (entry == null || entry.size != i.bytes)
            throw FormatException('缺少附件：${i.title}');
          final content = entry.content;
          if (sha256.convert(content).toString() != i.digest)
            throw const FormatException('备份附件校验失败');
          final relative = 'attachments/${ids[i.id]}${p.extension(i.filePath)}';
          final file = fileFor(relative);
          await file.writeAsBytes(content, flush: true);
          written.add(file);
          j['filePath'] = relative;
        }
        result.items.add(TravelItem.fromJson(j));
      }
      for (final s in restored.stops) {
        final j = s.toJson();
        j['id'] = newId();
        j['tripId'] = ids[s.tripId];
        j['itemId'] = ids[s.itemId] ?? '';
        result.stops.add(Stop.fromJson(j));
      }
      if (restored.trips.isNotEmpty)
        result.selected = ids[restored.trips.first.id]!;
      await save(result);
      return result;
    } catch (_) {
      for (final f in written) {
        if (await f.exists()) await f.delete();
      }
      rethrow;
    }
  }

  Future<void> close() => db.close();
}

List<int> _encodeZip(Archive archive) => ZipEncoder().encode(archive);
