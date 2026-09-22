import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:trail_capsule/core/models.dart';

void main() {
  setUpAll(tz.initializeTimeZones);
  final now = DateTime.utc(2026, 9, 22, 8);
  Stop stop(
    String id,
    int minutes, {
    bool pin = false,
    bool done = false,
    int? end,
  }) => Stop(
    id: id,
    tripId: 't',
    title: id,
    startUtc: now.add(Duration(minutes: minutes)),
    endUtc: end == null ? null : now.add(Duration(minutes: end)),
    zone: 'Asia/Tokyo',
    pinned: pin,
    done: done,
  );
  test(
    'next station prioritizes pin, ongoing, future and excludes completed',
    () {
      final ongoing = stop('ongoing', -20, end: 20),
          future = stop('future', 40),
          pin = stop('pin', 80, pin: true);
      expect(nextStop([future, ongoing, pin], now)?.id, 'pin');
      pin.pinned = false;
      expect(nextStop([future, ongoing, pin], now)?.id, 'ongoing');
      ongoing.done = true;
      expect(nextStop([future, ongoing, pin], now)?.id, 'future');
      future.cancelled = true;
      pin.done = true;
      expect(nextStop([future, ongoing, pin], now), isNull);
    },
  );
  test('overdue tasks do not block upcoming tasks', () {
    expect(nextStop([stop('old', -1), stop('new', 2)], now)?.id, 'new');
  });
  test('DST gap and fold require explicit resolution', () {
    expect(
      localInstants(DateTime(2026, 3, 8, 2, 30), 'America/New_York'),
      isEmpty,
    );
    final fold = localInstants(
      DateTime(2026, 11, 1, 1, 30),
      'America/New_York',
    );
    expect(fold.length, 2);
    expect(fold.last.difference(fold.first), const Duration(hours: 1));
  });
  test('same instant across zones preserves chronological order', () {
    final shanghai = localInstants(
      DateTime(2026, 9, 23, 0),
      'Asia/Shanghai',
    ).single;
    final tokyo = localInstants(DateTime(2026, 9, 23, 1), 'Asia/Tokyo').single;
    expect(shanghai, tokyo);
    expect(shanghai, DateTime.utc(2026, 9, 22, 16));
  });
  test('state copy detaches edits and rejects unknown version', () {
    final original = TravelState(
      trips: [Trip(id: 't', name: 'Tokyo', destination: 'Tokyo')],
    );
    final copy = original.copy();
    copy.trips.first.name = 'Kyoto';
    expect(original.trips.first.name, 'Tokyo');
    expect(
      () => TravelState.fromJson({'schemaVersion': 999}),
      throwsFormatException,
    );
  });
}
