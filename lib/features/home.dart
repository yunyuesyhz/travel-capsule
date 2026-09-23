import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/models.dart';
import '../data/controller.dart';
import '../data/repository.dart';
import '../main.dart';
import 'editors.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  int tab = 0;
  double _horizontalDrag = 0;
  String category = '全部', query = '';
  Timer? timer;
  CapsuleController get c => ref.read(controllerProvider);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => c.readInbox());
    platform.setMethodCallHandler((call) async {
      if (call.method == 'inboxChanged') await c.readInbox();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    platform.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      c.readInbox();
      setState(() {});
    }
  }

  Future<void> action(Future<void> Function() task, {String? success}) async {
    try {
      await task();
      if (mounted && success != null) toast(success);
    } catch (e) {
      if (mounted) showAppNotice(context, friendlyError(e), isError: true);
    }
  }

  String friendlyError(Object error) {
    if (error is PlatformException) {
      if (error.code == 'PATH') return '找不到这份附件，请确认资料仍在本机后重试。';
      if (error.code == 'INBOX') return '暂时无法读取分享收件箱，请稍后重试。';
      return error.message?.isNotEmpty == true
          ? error.message!
          : '这次没有完成，请稍后重试。';
    }
    if (error is FormatException) return error.message;
    if (error is FileSystemException) return '本机存储暂时不可用，请检查剩余空间后重试。';
    if (error is StateError) return '正在保存上一项内容，请稍后再试。';
    return '这次没有完成，请稍后重试。';
  }

  void toast(String text) {
    showAppNotice(context, text);
  }

  Future<bool> confirm(
    String title,
    String text, {
    String confirmLabel = '继续',
    bool destructive = false,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(text),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('取消'),
            ),
            FilledButton(
              style: glassFilledButtonStyle(
                fill: destructive ? coral : buttonOrange,
                foreground: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> editTrip([Trip? old]) async {
    final t = await editor<Trip>(context, TripEditor(trip: old));
    if (t == null) return;
    await action(
      () => c.update((s) {
        s.trips.removeWhere((x) => x.id == t.id);
        s.trips.add(t);
        s.selected = t.id;
      }),
      success: old == null ? '旅行已创建，准备出发吧。' : '旅行信息已更新。',
    );
  }

  Future<void> editItem([TravelItem? old]) async {
    final t = c.data.activeTrip;
    if (t == null && old == null) {
      await editTrip();
      return;
    }
    final i = await editor<TravelItem>(
      context,
      ItemEditor(tripId: t?.id ?? '', item: old),
    );
    if (i == null) return;
    await action(
      () => c.update((s) {
        s.items.removeWhere((x) => x.id == i.id);
        s.items.add(i);
      }),
      success: old == null ? '资料已收好，离线也能查看。' : '资料已更新。',
    );
  }

  Future<void> editStop([Stop? old]) async {
    final t = c.data.activeTrip;
    if (t == null) return;
    final s = await editor<Stop>(
      context,
      StopEditor(
        trip: t,
        items: c.data.items.where((i) => i.tripId == t.id).toList(),
        stop: old,
      ),
    );
    if (s == null) return;
    await action(
      () => c.update((d) {
        d.stops.removeWhere((x) => x.id == s.id);
        d.stops.add(s);
      }),
      success: old == null ? '行程已加入，下一站准备好了。' : '行程已更新。',
    );
  }

  Future<void> importFiles() async {
    if (c.data.activeTrip == null) {
      await editTrip();
      return;
    }
    await action(() async {
      final tripId = c.data.activeTrip!.id;
      final files = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: TravelRepository.extensions,
        allowMultiple: true,
      );
      if (files == null) return;
      if (!mounted) return;
      final selectedCategory = await chooseImportCategory(context);
      final importCategory = selectedCategory ?? '其他';
      var saved = 0;
      var failed = 0;
      for (final file in files.files) {
        try {
          if (file.path == null) throw const FormatException('文件不可读取');
          await c.importFile(
            file.path!,
            file.name,
            tripId,
            category: importCategory,
          );
          saved++;
        } catch (_) {
          failed++;
        }
      }
      if (!mounted) return;
      if (failed == 0) {
        toast('已导入 $saved 份资料，离线也能打开。');
      } else if (saved == 0) {
        toast('没有文件导入成功，请确认格式和文件大小。');
      } else {
        toast('已导入 $saved 份，另有 $failed 份未成功。');
      }
    });
  }

  void addMenu() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                '收好路上的每一份安心',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
              ),
            ),
            PressBounce(
              child: ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('文字、链接或地址'),
                subtitle: const Text('随手记下，离线查看'),
                onTap: () {
                  Navigator.pop(ctx);
                  editItem();
                },
              ),
            ),
            PressBounce(
              child: ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: const Text('导入图片 / PDF'),
                subtitle: const Text('保存独立副本 · 单份最大 50 MB'),
                onTap: () {
                  Navigator.pop(ctx);
                  importFiles();
                },
              ),
            ),
            PressBounce(
              child: ListTile(
                leading: const Icon(Icons.add_location_alt_outlined),
                title: const Text('添加一段行程'),
                onTap: () {
                  Navigator.pop(ctx);
                  editStop();
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
  void tripSheet() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .65,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '我的旅行',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            gap(),
            ...c.data.trips.map(
              (t) => PressBounce(
                child: ListTile(
                  leading: Icon(
                    t.archived
                        ? Icons.inventory_2_outlined
                        : Icons.luggage_outlined,
                  ),
                  title: Text(t.name),
                  subtitle: Text(
                    '${t.destination}${t.archived ? ' · 已归档' : ''}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) async {
                      Navigator.pop(ctx);
                      if (v == 'edit') {
                        editTrip(t);
                      } else if (v == 'archive') {
                        await action(
                          () => c.update((s) {
                            s.trips.firstWhere((x) => x.id == t.id).archived =
                                !t.archived;
                          }),
                        );
                      } else if (await confirm(
                        '删除这段旅行？',
                        '这会删除“${t.name}”及其资料、附件和行程，无法撤销。',
                        confirmLabel: '删除旅行',
                        destructive: true,
                      )) {
                        await action(
                          () => c.update((s) {
                            s.trips.removeWhere((x) => x.id == t.id);
                            s.items.removeWhere((x) => x.tripId == t.id);
                            s.stops.removeWhere((x) => x.tripId == t.id);
                          }),
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'edit', child: Text('编辑旅行')),
                      PopupMenuItem(
                        value: 'archive',
                        child: Text(t.archived ? '恢复旅行' : '归档旅行'),
                      ),
                      const PopupMenuItem(value: 'delete', child: Text('删除旅行')),
                    ],
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await action(
                      () => c.update((s) {
                        s.trips.firstWhere((x) => x.id == t.id).archived =
                            false;
                        s.selected = t.id;
                      }),
                    );
                  },
                ),
              ),
            ),
            gap(),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                editTrip();
              },
              icon: const Icon(Icons.add),
              label: const Text('开启新的旅行'),
            ),
          ],
        ),
      ),
    ),
  );
  Future<void> demo() async {
    final trip = Trip(
      id: newId(),
      name: '京都，慢慢走',
      destination: '日本 · 京都',
      zone: 'Asia/Tokyo',
    );
    final hotel = TravelItem(
      id: newId(),
      tripId: trip.id,
      title: '京都的落脚处 · 示例',
      category: '住宿',
      body: '这是示例资料，可随时编辑或删除。\n入住 15:00 · 退房 11:00\n出发前记得补充自己的真实订单。',
      address: '京都駅\n京都府京都市下京区東塩小路釜殿町',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    final train = TravelItem(
      id: newId(),
      tripId: trip.id,
      title: '机场到京都 · 示例',
      category: '交通',
      body: '把你的车票截图或 PDF 导入这里，再关联到行程。\n本条不包含实时班次或有效车票。',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await action(
      () => c.update((s) {
        s.trips.add(trip);
        s.selected = trip.id;
        s.items.addAll([hotel, train]);
        s.stops.addAll([
          Stop(
            id: newId(),
            tripId: trip.id,
            title: '乘车前往京都',
            startUtc: DateTime.now().toUtc().add(const Duration(hours: 1)),
            endUtc: DateTime.now().toUtc().add(const Duration(hours: 2)),
            zone: trip.zone,
            itemId: train.id,
            note: '示例行程 · 请替换为真实时间',
          ),
          Stop(
            id: newId(),
            tripId: trip.id,
            title: '办理入住，放下行李',
            startUtc: DateTime.now().toUtc().add(const Duration(hours: 3)),
            zone: trip.zone,
            itemId: hotel.id,
          ),
        ]);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = ref.watch(controllerProvider), trip = ctrl.data.activeTrip;
    final inbox = ctrl.data.items.where((i) => i.tripId.isEmpty).length;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: PressBounce(
          child: InkWell(
            onTap: tripSheet,
            borderRadius: BorderRadius.circular(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.explore_outlined, size: 23, color: ocean),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    trip?.name ?? '旅途胶囊',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, size: 20),
              ],
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: '设置与备份',
            onPressed: settings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [paper, Color(0xFFFFF0E2)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              if (ctrl.busy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: trip == null
                        ? welcome(inbox)
                        : ClipRect(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onHorizontalDragStart: (_) => _horizontalDrag = 0,
                              onHorizontalDragUpdate: (details) {
                                _horizontalDrag += details.delta.dx;
                              },
                              onHorizontalDragEnd: (details) {
                                final drag = _horizontalDrag;
                                _horizontalDrag = 0;
                                final velocity =
                                    details.velocity.pixelsPerSecond.dx;
                                if (drag.abs() < 64 && velocity.abs() < 420)
                                  return;
                                final direction = drag.abs() >= 64
                                    ? drag
                                    : velocity;
                                final next = (tab + (direction < 0 ? 1 : -1))
                                    .clamp(0, 3);
                                if (next != tab) setState(() => tab = next);
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 280),
                                reverseDuration: const Duration(
                                  milliseconds: 220,
                                ),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                layoutBuilder: (current, previous) => Stack(
                                  fit: StackFit.expand,
                                  children: current == null
                                      ? previous
                                      : [...previous, current],
                                ),
                                transitionBuilder: (child, animation) {
                                  final eased = CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeOutCubic,
                                  );
                                  return FadeTransition(
                                    opacity: eased,
                                    child: ScaleTransition(
                                      scale: Tween<double>(
                                        begin: .992,
                                        end: 1,
                                      ).animate(eased),
                                      child: child,
                                    ),
                                  );
                                },
                                child: KeyedSubtree(
                                  key: ValueKey('${trip.id}-$tab'),
                                  child: switch (tab) {
                                    0 => dashboard(trip, inbox),
                                    1 => library(trip),
                                    2 => itinerary(trip),
                                    _ => emergency(trip),
                                  },
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: animation, child: child),
        ),
        child: trip != null && tab != 3
            ? PressBounce(
                key: const ValueKey('add-capsule'),
                enabled: !ctrl.busy,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x2C8E431F),
                        blurRadius: 18,
                        offset: Offset(0, 7),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(32),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: FloatingActionButton.extended(
                        onPressed: ctrl.busy ? null : addMenu,
                        icon: const Icon(Icons.add),
                        label: const Text('收进胶囊'),
                        backgroundColor: buttonOrange.withValues(alpha: .9),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        focusElevation: 0,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('no-add-capsule')),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x145B3623),
                  blurRadius: 22,
                  offset: Offset(0, 7),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: paper.withValues(alpha: .72),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .72),
                    ),
                  ),
                  child: RepaintBoundary(
                    child: Row(
                      children: [
                        _BottomTab(
                          label: '路上',
                          icon: Icons.explore_outlined,
                          selectedIcon: Icons.explore,
                          selected: tab == 0,
                          onTap: () => _selectTab(0),
                        ),
                        _BottomTab(
                          label: '资料袋',
                          icon: Icons.folder_outlined,
                          selectedIcon: Icons.folder,
                          selected: tab == 1,
                          onTap: () => _selectTab(1),
                        ),
                        _BottomTab(
                          label: '行程',
                          icon: Icons.route_outlined,
                          selectedIcon: Icons.route,
                          selected: tab == 2,
                          onTap: () => _selectTab(2),
                        ),
                        _BottomTab(
                          label: '应急卡',
                          icon: Icons.health_and_safety_outlined,
                          selectedIcon: Icons.health_and_safety,
                          selected: tab == 3,
                          onTap: () => _selectTab(3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectTab(int index) {
    if (index != tab) setState(() => tab = index);
  }

  Widget welcome(int inbox) => ListView(
    padding: const EdgeInsets.fromLTRB(28, 35, 28, 36),
    children: [
      const Text(
        'TRAVEL CAPSULE',
        style: TextStyle(
          color: accent,
          fontSize: 12,
          letterSpacing: 3,
          fontWeight: FontWeight.w700,
        ),
      ),
      gap(28),
      const Text(
        '把安心装进口袋。\n去远方，慢慢走。',
        style: TextStyle(
          fontSize: 36,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
      gap(24),
      Container(
        height: 180,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [peach, sky],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Stack(
          children: [
            const Positioned(
              right: 34,
              top: 28,
              child: CircleAvatar(radius: 27, backgroundColor: sun),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: 70,
                decoration: const BoxDecoration(
                  color: Color(0xFFC6E49E),
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(30),
                  ),
                ),
              ),
            ),
            const Center(
              child: Icon(Icons.route_rounded, size: 82, color: accent),
            ),
            const Positioned(
              left: 42,
              top: 30,
              child: Icon(
                Icons.flight_takeoff_rounded,
                size: 34,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
      gap(28),
      const Text(
        '车票、地址、下一站。\n重要的事，没网络也能找到。',
        style: TextStyle(color: muted, fontSize: 17, height: 1.7),
      ),
      gap(28),
      FilledButton.icon(
        onPressed: () => editTrip(),
        icon: const Icon(Icons.add),
        label: const Text('创建我的第一段旅行'),
      ),
      gap(8),
      TextButton(onPressed: demo, child: const Text('先看看示例旅行')),
      if (inbox > 0)
        TextButton(onPressed: showInbox, child: Text('收件箱有 $inbox 份待整理资料')),
    ],
  );
  Widget heading(String eyebrow, String title, {String? subtitle}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        eyebrow,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 2.5,
          color: accent,
          fontWeight: FontWeight.w700,
        ),
      ),
      gap(9),
      Text(title, style: Theme.of(context).textTheme.headlineLarge),
      if (subtitle != null) ...[
        gap(8),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 14)),
      ],
      gap(24),
    ],
  );
  Widget dashboard(Trip t, int inbox) {
    final stops = c.data.stops.where((s) => s.tripId == t.id).toList();
    final next = nextStop(stops, DateTime.now().toUtc());
    final items = c.data.items.where((i) => i.tripId == t.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final overdue = stops
        .where(
          (s) =>
              !s.done &&
              !s.cancelled &&
              (s.endUtc ?? s.startUtc).isBefore(DateTime.now()),
        )
        .length;
    return ListView(
      key: const PageStorageKey('dashboard'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 105),
      children: [
        heading(
          'YOUR POCKET, YOUR JOURNEY',
          '今天，安心出发。',
          subtitle: '${t.destination}  ·  ${zoneLabel(t.zone)}',
        ),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.offline_pin_outlined, size: 16, color: ink),
                const SizedBox(width: 6),
                Text(
                  '${items.length} 份随身资料',
                  style: const TextStyle(fontSize: 12, color: muted),
                ),
              ],
            ),
            const Text(
              '本地保存 · 无需登录',
              style: TextStyle(fontSize: 11, color: muted),
            ),
          ],
        ),
        gap(20),
        GlassPanel(
          padding: const EdgeInsets.all(24),
          borderRadius: BorderRadius.circular(30),
          blurSigma: 16,
          borderColor: Colors.white,
          borderOpacity: .28,
          gradient: const LinearGradient(
            colors: [Color(0xF0D97730), Color(0xF0C55C2B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x35C66A30),
              blurRadius: 25,
              offset: Offset(0, 11),
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.near_me_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    next?.pinned == true ? '手动置顶' : '下一站',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'UP NEXT',
                    style: TextStyle(
                      color: Color(0xDDFFFFFF),
                      fontSize: 10,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              gap(23),
              Text(
                next?.title ?? '给旅程留一点期待',
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.35,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              gap(12),
              Text(
                next == null
                    ? '添加时间和资料，下一步就在手边。'
                    : '${clockText(next.startUtc, next.zone)}\n${zoneLabel(next.zone)}',
                style: const TextStyle(
                  color: Color(0xFFFDF5EC),
                  fontSize: 14,
                  height: 1.7,
                ),
              ),
              gap(22),
              FilledButton(
                onPressed: next == null
                    ? () => editStop()
                    : () => stopSheet(next),
                style: glassFilledButtonStyle(
                  fill: Colors.white,
                  foreground: ink,
                  minimumSize: const Size(double.infinity, 48),
                  fillOpacity: .84,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(child: Text(next == null ? '安排下一站' : '查看行程与资料')),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, size: 17),
                  ],
                ),
              ),
            ],
          ),
        ),
        gap(14),
        Row(
          children: [
            Expanded(
              child: quickAction(
                icon: Icons.folder_copy_outlined,
                title: '随身资料',
                subtitle: '${items.length} 份离线可看',
                tint: sky,
                iconColor: accent,
                onTap: () => setState(() => tab = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: quickAction(
                icon: Icons.route_rounded,
                title: '行程路线',
                subtitle: stops.isEmpty ? '安排下一站' : '${stops.length} 个行程安排',
                tint: seafoam,
                iconColor: leaf,
                onTap: () => setState(() => tab = 2),
              ),
            ),
          ],
        ),
        if (overdue > 0) ...[
          gap(12),
          TextButton.icon(
            onPressed: () => setState(() => tab = 2),
            icon: const Icon(Icons.history, size: 17),
            label: Text('$overdue 段已过时行程待整理'),
          ),
        ],
        if (inbox > 0 || c.inboxError != null) ...[
          gap(18),
          tile(
            interactive: true,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.move_to_inbox_outlined, color: ocean),
              title: Text(inbox > 0 ? '$inbox 份资料等你归档' : '收件箱需要重试'),
              subtitle: Text(c.inboxError ?? '从其他应用分享的内容在这里'),
              trailing: const Icon(Icons.chevron_right),
              onTap: showInbox,
            ),
          ),
        ],
        gap(28),
        Row(
          children: [
            const Expanded(
              child: Text(
                '随手就能找到',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => tab = 1),
              child: const Text('全部资料 →'),
            ),
          ],
        ),
        gap(8),
        if (items.isEmpty)
          empty(Icons.folder_open, '口袋还空着', '把车票、酒店地址和攻略收进来。')
        else
          ...items.take(3).map(itemTile),
        gap(18),
        const Center(
          child: Text(
            '少一点翻找，多一点沿途风景。',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget library(Trip t) {
    final items =
        c.data.items
            .where(
              (i) =>
                  i.tripId == t.id &&
                  (category == '全部' || i.category == category) &&
                  ('${i.title} ${i.body} ${i.address} ${i.fileName}'
                      .toLowerCase()
                      .contains(query.toLowerCase())),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ListView(
      key: const PageStorageKey('library'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 105),
      children: [
        heading(
          'ALL THE LITTLE ESSENTIALS',
          '我的资料袋',
          subtitle: '重要资料，在这里安稳待着。',
        ),
        TextField(
          onChanged: (v) => setState(() => query = v),
          decoration: const InputDecoration(
            hintText: '搜索标题、备注、地址',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        gap(16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories
                .map(
                  (x) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PressBounce(
                      child: ChoiceChip(
                        label: Text(x),
                        selected: category == x,
                        selectedColor: peach,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => category = x),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        gap(16),
        Text(
          '${items.length} 份资料',
          style: const TextStyle(color: muted, fontSize: 12),
        ),
        gap(12),
        if (items.isEmpty)
          empty(
            Icons.folder_open,
            query.isEmpty ? '还没有这类资料' : '没有找到匹配资料',
            query.isEmpty ? '点击“收进胶囊”添加文字或导入文件。' : '试试其他标题、备注或地址关键词。',
          )
        else
          ...items.map(itemTile),
      ],
    );
  }

  Widget itinerary(Trip t) {
    final stops = c.data.stops.where((s) => s.tripId == t.id).toList()
      ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
    return ListView(
      key: const PageStorageKey('itinerary'),
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 105),
      children: [
        heading(
          'ONE STEP AT A TIME',
          '下一步，慢慢来。',
          subtitle: '按真实时刻排序，显示各站当地时间。',
        ),
        if (stops.isEmpty)
          empty(Icons.route_outlined, '旅程由你安排', '添加出发、到达或入住时间。')
        else
          ...stops.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: tile(
                interactive: true,
                child: InkWell(
                  onTap: () => stopSheet(s),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: s.done
                              ? seafoam
                              : s.pinned
                              ? const Color(0xFFFFE4C2)
                              : sky,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          s.done
                              ? Icons.check
                              : s.cancelled
                              ? Icons.close
                              : s.pinned
                              ? Icons.push_pin_outlined
                              : Icons.near_me_outlined,
                          color: s.done
                              ? leaf
                              : s.cancelled
                              ? muted
                              : s.pinned
                              ? accent
                              : accent,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              clockText(s.startUtc, s.zone),
                              style: const TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            gap(6),
                            Text(
                              s.title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: s.done || s.cancelled ? muted : ink,
                                decoration: s.cancelled
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                            gap(4),
                            Text(
                              '${zoneLabel(s.zone)}${s.done
                                  ? ' · 已完成'
                                  : s.cancelled
                                  ? ' · 已取消'
                                  : s.pinned
                                  ? ' · 已置顶'
                                  : ''}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                            if (s.endUtc != null)
                              Text(
                                '至 ${clockText(s.endUtc!, s.endZone ?? s.zone)} · ${zoneLabel(s.endZone ?? s.zone)}',
                                style: const TextStyle(
                                  color: muted,
                                  fontSize: 11,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget emergency(Trip t) => ListView(
    key: const PageStorageKey('emergency'),
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
    children: [
      heading('JUST IN CASE', '多一份安心。', subtitle: '离线可查看，随时找得到。'),
      tile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.favorite_border, color: coral),
            gap(18),
            const Text('紧急联系人', style: TextStyle(color: muted, fontSize: 12)),
            gap(8),
            Text(
              t.contact.isEmpty ? '还未填写联系人' : t.contact,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            if (t.phone.isNotEmpty) ...[
              gap(8),
              SelectableText(t.phone, style: const TextStyle(fontSize: 21)),
              gap(16),
              FilledButton.icon(
                onPressed: () => action(() async {
                  final phone = t.phone.replaceAll(RegExp(r'[^0-9+]'), '');
                  if (phone.isEmpty ||
                      !await launchUrl(Uri(scheme: 'tel', path: phone)))
                    throw const FormatException('设备无法打开拨号界面');
                }),
                icon: const Icon(Icons.phone_outlined),
                label: const Text('打开拨号界面'),
              ),
            ],
          ],
        ),
      ),
      gap(16),
      tile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('保险与援助', style: TextStyle(color: muted, fontSize: 12)),
            gap(10),
            SelectableText(t.insurance.isEmpty ? '提前填写保单与援助电话。' : t.insurance),
          ],
        ),
      ),
      gap(16),
      tile(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '需要帮助时，给对方看',
              style: TextStyle(color: muted, fontSize: 12),
            ),
            gap(10),
            Text(
              t.help.isEmpty ? '添加一句求助语。' : t.help,
              style: const TextStyle(fontSize: 18, height: 1.7),
            ),
            gap(16),
            OutlinedButton.icon(
              onPressed: t.help.isEmpty ? null : () => bigCard('请帮助我', t.help),
              icon: const Icon(Icons.fullscreen),
              label: const Text('大字展示'),
            ),
          ],
        ),
      ),
      gap(20),
      FilledButton.icon(
        onPressed: () async {
          final result = await editor<Trip>(context, EmergencyEditor(trip: t));
          if (result != null)
            await action(
              () => c.update((s) {
                s.trips[s.trips.indexWhere((x) => x.id == t.id)] = result;
              }),
            );
        },
        icon: const Icon(Icons.edit_outlined),
        label: const Text('编辑应急信息'),
      ),
    ],
  );
  Widget tile({required Widget child, bool interactive = false}) {
    final panel = GlassPanel(
      padding: const EdgeInsets.all(19),
      borderRadius: BorderRadius.circular(28),
      opacity: .64,
      blurSigma: 14,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(28),
        child: child,
      ),
    );
    return interactive ? PressBounce(child: panel) : panel;
  }

  Widget quickAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color tint,
    required Color iconColor,
    required VoidCallback onTap,
  }) => PressBounce(
    child: GlassPanel(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(26),
      tint: tint,
      opacity: .54,
      blurSigma: 14,
      borderColor: Colors.white,
      borderOpacity: .62,
      shadows: const [],
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: SizedBox(
            height: 138,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .78),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget empty(IconData icon, String title, String body) => GlassPanel(
    padding: const EdgeInsets.symmetric(vertical: 38, horizontal: 22),
    borderRadius: BorderRadius.circular(28),
    blurSigma: 14,
    borderColor: Colors.white,
    borderOpacity: .72,
    shadows: const [],
    gradient: LinearGradient(
      colors: [sky.withValues(alpha: .68), seafoam.withValues(alpha: .68)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    child: Column(
      children: [
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(color: peach, shape: BoxShape.circle),
          child: Icon(icon, size: 28, color: accent),
        ),
        gap(16),
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        gap(8),
        Text(
          body,
          textAlign: TextAlign.center,
          style: const TextStyle(color: muted),
        ),
      ],
    ),
  );
  IconData iconFor(TravelItem i) => i.category == '住宿'
      ? Icons.bed_outlined
      : i.category == '交通'
      ? Icons.train_outlined
      : i.isPdf
      ? Icons.picture_as_pdf_outlined
      : i.hasFile
      ? Icons.image_outlined
      : i.address.isNotEmpty
      ? Icons.place_outlined
      : Icons.notes_rounded;
  Color itemTint(TravelItem item) => item.category == '交通'
      ? peach
      : item.category == '住宿'
      ? sky
      : item.category == '攻略'
      ? seafoam
      : item.isPdf
      ? const Color(0xFFFFE5DE)
      : item.address.isNotEmpty
      ? const Color(0xFFFFF0C9)
      : const Color(0xFFFFF3E5);
  Color itemAccent(TravelItem item) => item.category == '交通'
      ? ocean
      : item.category == '住宿'
      ? accent
      : item.category == '攻略'
      ? leaf
      : item.isPdf
      ? coral
      : item.address.isNotEmpty
      ? const Color(0xFFAD7620)
      : accent;
  Widget itemTile(TravelItem i) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: tile(
      interactive: true,
      child: InkWell(
        onTap: () => itemDetail(i.id),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 50,
              decoration: BoxDecoration(
                color: itemTint(i),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(iconFor(i), size: 24, color: itemAccent(i)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  gap(5),
                  Text(
                    '${i.category} · ${i.hasFile ? (i.isPdf ? 'PDF' : '图片') : '文字'}${i.hasFile ? ' · ${(i.bytes / 1024).ceil()} KB' : ''}',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_outward, size: 18, color: muted),
          ],
        ),
      ),
    ),
  );
  void bigCard(String title, String body) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        backgroundColor: accent,
        appBar: AppBar(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          title: Text(title),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(28),
            children: [
              gap(30),
              const Text(
                'PLEASE SHOW THIS CARD',
                style: TextStyle(color: sky, letterSpacing: 2, fontSize: 11),
              ),
              gap(28),
              SelectableText(
                body,
                style: const TextStyle(
                  fontSize: 34,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              gap(40),
              OutlinedButton.icon(
                style: glassOutlinedButtonStyle(
                  tint: Colors.white,
                  foreground: Colors.white,
                  borderColor: Colors.white,
                  fillOpacity: .16,
                ),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: body));
                  if (ctx.mounted) showAppNotice(ctx, '已复制');
                },
                icon: const Icon(Icons.copy),
                label: const Text('复制文字'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Future<void> openAttachment(TravelItem item) async {
    await action(() async {
      final file = c.repository.fileFor(item.filePath);
      if (!await file.exists()) throw const FormatException('本地附件缺失，请重新导入');
      if (item.isPdf) {
        await platform.invokeMethod('openPdf', {
          'path': file.path,
          'title': item.title,
        });
      } else if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (ctx) => Scaffold(
              backgroundColor: paper,
              appBar: AppBar(
                backgroundColor: paper,
                foregroundColor: ink,
                title: Text(item.title),
              ),
              body: SafeArea(
                child: InteractiveViewer(
                  minScale: .5,
                  maxScale: 6,
                  child: Center(
                    child: Image.file(
                      file,
                      errorBuilder: (_, e, s) => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          '当前设备无法预览这张图片。可以保留原件，或转换成 JPG / PNG 后重新导入。',
                          style: TextStyle(color: ink),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    });
  }

  void itemDetail(String id) => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final values = ref
              .watch(controllerProvider)
              .data
              .items
              .where((x) => x.id == id);
          if (values.isEmpty)
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('资料已删除')),
            );
          final i = values.first;
          return Scaffold(
            appBar: AppBar(
              title: const Text('随身资料'),
              actions: [
                IconButton(
                  tooltip: '编辑',
                  onPressed: () => editItem(i),
                  icon: const Icon(Icons.edit_outlined),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  i.category,
                  style: const TextStyle(color: accent, fontSize: 12),
                ),
                gap(10),
                Text(
                  i.title,
                  style: const TextStyle(
                    fontSize: 29,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap(20),
                if (i.hasFile) ...[
                  tile(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(iconFor(i)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(i.fileName)),
                          ],
                        ),
                        gap(12),
                        Text(
                          '${(i.bytes / 1024).ceil()} KB · 已保存独立副本',
                          style: const TextStyle(color: muted, fontSize: 12),
                        ),
                        gap(16),
                        FilledButton.icon(
                          onPressed: () => openAttachment(i),
                          icon: const Icon(Icons.open_in_full),
                          label: const Text('打开附件'),
                        ),
                      ],
                    ),
                  ),
                  gap(20),
                ],
                if (i.body.isNotEmpty) ...[
                  SelectableText(
                    i.body,
                    style: const TextStyle(fontSize: 16, height: 1.8),
                  ),
                  gap(20),
                ],
                if (i.address.isNotEmpty) ...[
                  tile(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '当地语言地址',
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                        gap(12),
                        SelectableText(
                          i.address,
                          style: const TextStyle(fontSize: 19, height: 1.6),
                        ),
                        gap(18),
                        FilledButton.icon(
                          onPressed: () => bigCard(i.title, i.address),
                          icon: const Icon(Icons.fullscreen),
                          label: const Text('给司机看'),
                        ),
                      ],
                    ),
                  ),
                  gap(20),
                ],
                if (i.tripId.isEmpty)
                  FilledButton(
                    onPressed: () => assignItem(i, ctx),
                    child: const Text('归档到旅行'),
                  ),
                gap(32),
                TextButton.icon(
                  onPressed: () async {
                    if (!await confirm(
                      '删除这份资料？',
                      '附件副本也会一并删除，此操作无法撤销。',
                      confirmLabel: '删除资料',
                      destructive: true,
                    ))
                      return;
                    await action(
                      () => c.update((s) {
                        s.items.removeWhere((x) => x.id == id);
                        for (final stop in s.stops) {
                          stop.itemIds.remove(id);
                        }
                      }),
                    );
                    if (ctx.mounted && !c.data.items.any((x) => x.id == id))
                      Navigator.pop(ctx);
                  },
                  icon: const Icon(Icons.delete_outline, color: coral),
                  label: const Text('删除资料', style: TextStyle(color: coral)),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
  void stopSheet(Stop stop) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final linkedItems = c.data.items
          .where((item) => stop.itemIds.contains(item.id))
          .toList();
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  stop.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap(12),
                Text(
                  '${clockText(stop.startUtc, stop.zone)} · ${zoneLabel(stop.zone)}',
                ),
                if (stop.note.isNotEmpty) ...[gap(12), Text(stop.note)],
                gap(20),
                if (linkedItems.isNotEmpty) ...[
                  const Text(
                    '关联资料',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  gap(6),
                  ...linkedItems.map(
                    (item) => PressBounce(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          item.isPdf
                              ? Icons.picture_as_pdf_outlined
                              : Icons.folder_outlined,
                          color: ocean,
                        ),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(item.category),
                        trailing: const Icon(Icons.arrow_forward_rounded),
                        onTap: () {
                          Navigator.pop(ctx);
                          itemDetail(item.id);
                        },
                      ),
                    ),
                  ),
                ],
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        action(
                          () => c.update((s) {
                            final x = s.stops.firstWhere(
                              (x) => x.id == stop.id,
                            );
                            x.done = !x.done;
                            x.cancelled = false;
                            x.pinned = false;
                          }),
                        );
                      },
                      icon: Icon(stop.done ? Icons.undo : Icons.check),
                      label: Text(stop.done ? '恢复待办' : '标记完成'),
                    ),
                    OutlinedButton.icon(
                      onPressed: stop.done || stop.cancelled
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              action(
                                () => c.update((s) {
                                  for (final x in s.stops.where(
                                    (x) => x.tripId == stop.tripId,
                                  )) {
                                    x.pinned = x.id == stop.id && !stop.pinned;
                                  }
                                }),
                              );
                            },
                      icon: const Icon(Icons.push_pin_outlined),
                      label: Text(stop.pinned ? '取消置顶' : '置顶'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        editStop(stop);
                      },
                      child: const Text('编辑'),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        action(
                          () => c.update((s) {
                            final x = s.stops.firstWhere(
                              (x) => x.id == stop.id,
                            );
                            x.cancelled = !x.cancelled;
                            x.done = false;
                            x.pinned = false;
                          }),
                        );
                      },
                      child: Text(stop.cancelled ? '恢复行程' : '取消行程'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        if (await confirm(
                          '删除这段行程？',
                          '关联资料会继续保留在资料袋中。',
                          confirmLabel: '删除行程',
                          destructive: true,
                        ))
                          await action(
                            () => c.update(
                              (s) =>
                                  s.stops.removeWhere((x) => x.id == stop.id),
                            ),
                          );
                      },
                      child: const Text('删除', style: TextStyle(color: coral)),
                    ),
                  ],
                ),
                gap(12),
              ],
            ),
          ),
        ),
      );
    },
  );
  Future<void> assignItem(TravelItem i, BuildContext page) async {
    final trips = c.data.trips.where((t) => !t.archived).toList();
    if (trips.isEmpty) {
      toast('请先创建一段旅行');
      return;
    }
    final id = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('放进哪段旅行？'),
        children: trips
            .map(
              (t) => PressBounce(
                child: SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, t.id),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(t.name),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
    if (id == null || !mounted) return;
    final selectedCategory = await chooseImportCategory(context);
    final pickedCategory = selectedCategory ?? '其他';
    await action(
      () => c.update((s) {
        final item = s.items.firstWhere((x) => x.id == i.id);
        item.tripId = id;
        item.category = pickedCategory;
      }),
      success: '已归档',
    );
  }

  void showInbox() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (ctx) => Consumer(
        builder: (ctx, ref, _) {
          final ctrl = ref.watch(controllerProvider);
          final items = ctrl.data.items.where((i) => i.tripId.isEmpty).toList();
          return Scaffold(
            appBar: AppBar(
              title: const Text('待整理收件箱'),
              actions: [
                IconButton(
                  tooltip: '重试读取',
                  onPressed: ctrl.busy
                      ? null
                      : () => action(() => c.readInbox()),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  '分享的内容先保存到这里，再放进合适的旅行。',
                  style: TextStyle(color: muted),
                ),
                gap(20),
                if (ctrl.inboxError != null)
                  Text(ctrl.inboxError!, style: const TextStyle(color: coral)),
                if (items.isEmpty)
                  empty(
                    Icons.mark_email_read_outlined,
                    '都整理好了',
                    '从其他应用的分享菜单选择“旅途胶囊”。',
                  )
                else
                  ...items.map(itemTile),
              ],
            ),
          );
        },
      ),
    ),
  );
  void settings() => Navigator.push(
    context,
    MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
        appBar: AppBar(title: const Text('口袋里的设置')),
        body: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            heading('TRAVEL CAPSULE', '好好保管，每段旅程。'),
            tile(
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '资料只保存在这台设备',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '无需账号，不上传资料。卸载应用会删除本地内容，请提前导出备份。备份包含私人信息，目前不做密码加密。',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            gap(20),
            PressBounce(
              child: ListTile(
                leading: const Icon(Icons.move_to_inbox_outlined),
                title: const Text('待整理收件箱'),
                trailing: const Icon(Icons.chevron_right),
                onTap: showInbox,
              ),
            ),
            PressBounce(
              child: ListTile(
                leading: const Icon(Icons.ios_share),
                title: const Text('导出全部旅行备份'),
                subtitle: const Text('包含资料附件 · 最大 200 MB'),
                onTap: () async {
                  if (!await confirm(
                    '导出全部旅行？',
                    '备份包含附件和私人资料，且未加密。请只保存到你信任的位置。',
                    confirmLabel: '继续导出',
                  ))
                    return;
                  await action(
                    () => c.run(() async {
                      final dir = await getTemporaryDirectory();
                      final file = await c.repository.exportBackup(
                        c.data,
                        Directory('${dir.path}/capsule-backups'),
                      );
                      if (!ctx.mounted) return;
                      final box = ctx.findRenderObject() as RenderBox?;
                      await Share.shareXFiles(
                        [XFile(file.path)],
                        sharePositionOrigin: box == null
                            ? const Rect.fromLTWH(0, 0, 1, 1)
                            : box.localToGlobal(Offset.zero) & box.size,
                      );
                    }),
                  );
                },
              ),
            ),
            PressBounce(
              child: ListTile(
                leading: const Icon(Icons.settings_backup_restore),
                title: const Text('从备份恢复'),
                subtitle: const Text('创建新的旅行副本，不覆盖现有内容'),
                onTap: () => action(() async {
                  final picked = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['zip'],
                  );
                  if (picked == null || picked.files.single.path == null)
                    return;
                  await c.restore(File(picked.files.single.path!));
                  if (mounted) toast('已恢复为新的旅行副本');
                }),
              ),
            ),
            gap(30),
            const Divider(),
            gap(16),
            const Text(
              '旅途胶囊  1.1.9',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            gap(8),
            const Text(
              '少一点翻找，多一点沿途风景。\n图片和 PDF 正文暂不参与搜索；链接不自动缓存网页；无自动跨设备同步。',
              style: TextStyle(color: muted, height: 1.8),
            ),
          ],
        ),
      ),
    ),
  );
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressBounce(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 72,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  width: selected ? 58 : 48,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected ? ocean : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      reverseDuration: const Duration(milliseconds: 190),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final eased = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        );
                        return FadeTransition(
                          opacity: eased,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: .78,
                              end: 1,
                            ).animate(eased),
                            child: child,
                          ),
                        );
                      },
                      child: Icon(
                        selected ? selectedIcon : icon,
                        key: ValueKey(selected),
                        color: selected ? ink : muted,
                        size: selected ? 23 : 22,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  style: TextStyle(
                    color: selected ? ink : muted,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
