import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:trail_capsule/core/models.dart';
import 'package:trail_capsule/data/repository.dart';

void main() {
  late Directory temp;
  late TravelRepository repo;
  setUpAll(tz.initializeTimeZones);
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('capsule-test-');
    repo = TravelRepository(Directory('${temp.path}/data'));
    await repo.load();
  });
  tearDown(() async {
    await repo.close();
    await temp.delete(recursive: true);
  });
  test('file survives source deletion and database reopen', () async {
    final source = await File(
      '${temp.path}/ticket.pdf',
    ).writeAsString('%PDF-1.4 test');
    final item = await repo.importFile(source.path, 'ticket.pdf', 't');
    await repo.save(
      TravelState(
        trips: [Trip(id: 't', name: 'Travel', destination: 'Kyoto')],
        items: [item],
      ),
    );
    await source.delete();
    await repo.close();
    repo = TravelRepository(Directory('${temp.path}/data'));
    final loaded = await repo.load();
    expect(loaded.items.single.title, 'ticket');
    expect(
      await repo.fileFor(loaded.items.single.filePath).readAsString(),
      '%PDF-1.4 test',
    );
  });
  test(
    'backup round trip creates new ids and keeps existing records',
    () async {
      final source = await File(
        '${temp.path}/ticket.pdf',
      ).writeAsString('%PDF-1.4 sample');
      final item = await repo.importFile(source.path, 'ticket.pdf', 't');
      final state = TravelState(
        trips: [Trip(id: 't', name: 'Travel', destination: 'Kyoto')],
        items: [item],
        stops: [
          Stop(
            id: 's',
            tripId: 't',
            title: 'Train',
            startUtc: DateTime.utc(2026),
            zone: 'Asia/Tokyo',
            itemId: item.id,
          ),
        ],
      );
      await repo.save(state);
      final backup = await repo.exportBackup(
        state,
        Directory('${temp.path}/out'),
      );
      final restored = await repo.restore(backup, state);
      expect(restored.trips.length, 2);
      expect(restored.items.length, 2);
      expect(restored.trips.last.id, isNot('t'));
      expect(restored.stops.last.itemId, restored.items.last.id);
      expect(restored.items.last.digest, item.digest);
      expect((await repo.load()).trips.length, 2);
    },
  );
  test('restore rejects traversal without modifying persisted data', () async {
    final state = TravelState(
      trips: [Trip(id: 't', name: 'Keep me', destination: 'Kyoto')],
    );
    await repo.save(state);
    final bad = Archive()..addFile(ArchiveFile('../outside.txt', 1, [42]));
    final file = await File(
      '${temp.path}/bad.zip',
    ).writeAsBytes(ZipEncoder().encode(bad));
    await expectLater(repo.restore(file, state), throwsFormatException);
    expect((await repo.load()).trips.single.name, 'Keep me');
    expect(await File('${temp.path}/outside.txt').exists(), false);
  });
  test('restore validates missing attachment before database commit', () async {
    final state = TravelState(
      trips: [Trip(id: 't', name: 'Existing', destination: 'Tokyo')],
    );
    await repo.save(state);
    final broken = TravelState(
      trips: [Trip(id: 'b', name: 'Broken', destination: 'Kyoto')],
      items: [
        TravelItem(
          id: 'i',
          tripId: 'b',
          title: 'Missing',
          filePath: 'attachments/abc.pdf',
          fileName: 'abc.pdf',
          bytes: 10,
          digest: 'missing',
        ),
      ],
    );
    final manifest = utf8.encode(jsonEncode(broken.toJson()));
    final archive = Archive()
      ..addFile(ArchiveFile('manifest.json', manifest.length, manifest));
    final file = await File(
      '${temp.path}/missing.zip',
    ).writeAsBytes(ZipEncoder().encode(archive));
    await expectLater(repo.restore(file, state), throwsFormatException);
    expect((await repo.load()).trips.single.id, 't');
  });
  test('failed write rolls back previous database state', () async {
    final state = TravelState(
      trips: [Trip(id: 't', name: 'Original', destination: 'Tokyo')],
    );
    await repo.save(state);
    final invalid = TravelState(
      trips: [
        ...state.trips,
        Trip(id: 't', name: 'Duplicate', destination: 'Kyoto'),
      ],
    );
    await expectLater(repo.save(invalid), throwsA(isA<Exception>()));
    expect((await repo.load()).trips.single.name, 'Original');
  });
  test(
    'cleanup removes orphan files and imported empty files are rejected',
    () async {
      final empty = await File('${temp.path}/empty.pdf').writeAsBytes([]);
      await expectLater(
        repo.importFile(empty.path, 'empty.pdf', ''),
        throwsFormatException,
      );
      final orphan = await repo
          .fileFor('attachments/orphan.pdf')
          .writeAsString('orphan');
      await repo.cleanup(TravelState());
      expect(await orphan.exists(), false);
    },
  );
}
