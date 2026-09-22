import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';

String newId() => const Uuid().v4();
const categories = ['全部', '交通', '住宿', '攻略', '其他'];
const commonZones = [
  'Asia/Shanghai',
  'Asia/Tokyo',
  'Asia/Seoul',
  'Asia/Bangkok',
  'Asia/Singapore',
  'Europe/Paris',
  'Europe/London',
  'America/New_York',
  'America/Los_Angeles',
  'Australia/Sydney',
  'Pacific/Auckland',
];

typedef Json = Map<String, dynamic>;

class Trip {
  Trip({
    required this.id,
    required this.name,
    required this.destination,
    this.zone = 'Asia/Shanghai',
    this.archived = false,
    this.contact = '',
    this.phone = '',
    this.insurance = '',
    this.help = '请帮我联系我的紧急联系人。\nPlease help me contact my emergency contact.',
  });
  final String id;
  String name, destination, zone, contact, phone, insurance, help;
  bool archived;
  Json toJson() => {
    'id': id,
    'name': name,
    'destination': destination,
    'zone': zone,
    'archived': archived,
    'contact': contact,
    'phone': phone,
    'insurance': insurance,
    'help': help,
  };
  factory Trip.fromJson(Json j) => Trip(
    id: j['id'],
    name: j['name'],
    destination: j['destination'],
    zone: j['zone'],
    archived: j['archived'] ?? false,
    contact: j['contact'] ?? '',
    phone: j['phone'] ?? '',
    insurance: j['insurance'] ?? '',
    help: j['help'] ?? '',
  );
}

class TravelItem {
  TravelItem({
    required this.id,
    required this.tripId,
    required this.title,
    this.category = '其他',
    this.body = '',
    this.address = '',
    this.fileName = '',
    this.filePath = '',
    this.digest = '',
    this.bytes = 0,
    this.createdAt = 0,
  });
  final String id;
  String tripId, title, category, body, address, fileName, filePath, digest;
  int bytes, createdAt;
  bool get hasFile => filePath.isNotEmpty;
  bool get isPdf => fileName.toLowerCase().endsWith('.pdf');
  Json toJson() => {
    'id': id,
    'tripId': tripId,
    'title': title,
    'category': category,
    'body': body,
    'address': address,
    'fileName': fileName,
    'filePath': filePath,
    'digest': digest,
    'bytes': bytes,
    'createdAt': createdAt,
  };
  factory TravelItem.fromJson(Json j) => TravelItem(
    id: j['id'],
    tripId: j['tripId'],
    title: j['title'],
    category: j['category'] ?? '其他',
    body: j['body'] ?? '',
    address: j['address'] ?? '',
    fileName: j['fileName'] ?? '',
    filePath: j['filePath'] ?? '',
    digest: j['digest'] ?? '',
    bytes: j['bytes'] ?? 0,
    createdAt: j['createdAt'] ?? 0,
  );
}

class Stop {
  Stop({
    required this.id,
    required this.tripId,
    required this.title,
    required this.startUtc,
    required this.zone,
    this.endUtc,
    this.endZone,
    this.itemId = '',
    this.note = '',
    this.done = false,
    this.cancelled = false,
    this.pinned = false,
  });
  final String id;
  String tripId, title, zone, itemId, note;
  String? endZone;
  DateTime startUtc;
  DateTime? endUtc;
  bool done, cancelled, pinned;
  Json toJson() => {
    'id': id,
    'tripId': tripId,
    'title': title,
    'startUtc': startUtc.toUtc().toIso8601String(),
    'endUtc': endUtc?.toUtc().toIso8601String(),
    'zone': zone,
    'endZone': endZone,
    'itemId': itemId,
    'note': note,
    'done': done,
    'cancelled': cancelled,
    'pinned': pinned,
  };
  factory Stop.fromJson(Json j) => Stop(
    id: j['id'],
    tripId: j['tripId'],
    title: j['title'],
    startUtc: DateTime.parse(j['startUtc']).toUtc(),
    endUtc: j['endUtc'] == null ? null : DateTime.parse(j['endUtc']).toUtc(),
    zone: j['zone'],
    endZone: j['endZone'],
    itemId: j['itemId'] ?? '',
    note: j['note'] ?? '',
    done: j['done'] ?? false,
    cancelled: j['cancelled'] ?? false,
    pinned: j['pinned'] ?? false,
  );
}

class TravelState {
  TravelState({
    List<Trip>? trips,
    List<TravelItem>? items,
    List<Stop>? stops,
    List<String>? consumed,
    String? selected,
  }) : trips = trips ?? [],
       items = items ?? [],
       stops = stops ?? [],
       consumed = consumed ?? [],
       selected = selected ?? '';
  final List<Trip> trips;
  final List<TravelItem> items;
  final List<Stop> stops;
  final List<String> consumed;
  String selected;
  Trip? get activeTrip {
    final active = trips.where((t) => !t.archived).toList();
    for (final t in active) {
      if (t.id == selected) return t;
    }
    return active.isEmpty ? null : active.first;
  }

  Json toJson() => {
    'schemaVersion': 1,
    'trips': trips.map((x) => x.toJson()).toList(),
    'items': items.map((x) => x.toJson()).toList(),
    'stops': stops.map((x) => x.toJson()).toList(),
    'consumed': consumed,
    'selected': selected,
  };
  factory TravelState.fromJson(Json j) {
    if (j['schemaVersion'] != 1) throw const FormatException('不支持的备份版本');
    final state = TravelState(
      trips: (j['trips'] as List)
          .map((x) => Trip.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      items: (j['items'] as List)
          .map((x) => TravelItem.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      stops: (j['stops'] as List)
          .map((x) => Stop.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      consumed: List<String>.from(j['consumed'] ?? []),
      selected: j['selected'],
    );
    final ids = state.trips.map((t) => t.id).toSet();
    if (ids.length != state.trips.length ||
        state.items.map((i) => i.id).toSet().length != state.items.length ||
        state.stops.map((i) => i.id).toSet().length != state.stops.length)
      throw const FormatException('备份包含重复记录');
    for (final t in state.trips) {
      tz.getLocation(t.zone);
    }
    for (final i in state.items) {
      if (i.tripId.isNotEmpty && !ids.contains(i.tripId))
        throw const FormatException('资料关联的旅行不存在');
    }
    for (final s in state.stops) {
      tz.getLocation(s.zone);
      tz.getLocation(s.endZone ?? s.zone);
      if (!ids.contains(s.tripId) ||
          (s.endUtc != null && s.endUtc!.isBefore(s.startUtc)))
        throw const FormatException('行程数据无效');
    }
    return state;
  }
  TravelState copy() => TravelState.fromJson(toJson());
}

Stop? nextStop(Iterable<Stop> stops, DateTime now) {
  final list = stops.where((s) => !s.done && !s.cancelled).toList()
    ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  for (final s in list) {
    if (s.pinned) return s;
  }
  for (final s in list) {
    if (!s.startUtc.isAfter(now) && s.endUtc != null && s.endUtc!.isAfter(now))
      return s;
  }
  for (final s in list) {
    if (!s.startUtc.isBefore(now)) return s;
  }
  return null;
}

// Enumerate valid offsets, rejecting DST gaps and requiring an explicit fold choice.
List<DateTime> localInstants(DateTime wall, String zone) {
  final loc = tz.getLocation(zone);
  final naive = DateTime.utc(
    wall.year,
    wall.month,
    wall.day,
    wall.hour,
    wall.minute,
  );
  final offsets = <int>{};
  for (var h = -36; h <= 36; h += 3) {
    offsets.add(
      tz.TZDateTime.from(
        naive.add(Duration(hours: h)),
        loc,
      ).timeZoneOffset.inMilliseconds,
    );
  }
  final values = <DateTime>[];
  for (final offset in offsets) {
    final utc = naive.subtract(Duration(milliseconds: offset));
    final z = tz.TZDateTime.from(utc, loc);
    if (z.year == wall.year &&
        z.month == wall.month &&
        z.day == wall.day &&
        z.hour == wall.hour &&
        z.minute == wall.minute)
      values.add(utc);
  }
  values.sort();
  return values;
}

String clockText(DateTime utc, String zone, {bool date = true}) {
  final v = tz.TZDateTime.from(utc, tz.getLocation(zone));
  String d(int n) => n.toString().padLeft(2, '0');
  return '${date ? '${d(v.month)}月${d(v.day)}日 · ' : ''}${d(v.hour)}:${d(v.minute)}';
}

String zoneLabel(String z) =>
    {
      'Asia/Shanghai': '中国 · 上海',
      'Asia/Tokyo': '日本 · 东京',
      'Asia/Seoul': '韩国 · 首尔',
      'Asia/Bangkok': '泰国 · 曼谷',
      'Asia/Singapore': '新加坡',
      'Europe/Paris': '法国 · 巴黎',
      'Europe/London': '英国 · 伦敦',
      'America/New_York': '美国 · 纽约',
      'America/Los_Angeles': '美国 · 洛杉矶',
      'Australia/Sydney': '澳大利亚 · 悉尼',
      'Pacific/Auckland': '新西兰 · 奥克兰',
    }[z] ??
    z;
