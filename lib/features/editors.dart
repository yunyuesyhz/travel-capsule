import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/models.dart';
import '../main.dart';

Future<T?> editor<T>(BuildContext context, Widget child) => Navigator.of(
  context,
).push<T>(MaterialPageRoute(builder: (_) => child, fullscreenDialog: true));
Widget gap([double n = 18]) => SizedBox(height: n);
Widget hintNote(String text, {IconData icon = Icons.lightbulb_outline}) =>
    GlassPanel(
      padding: const EdgeInsets.all(14),
      borderRadius: BorderRadius.circular(16),
      tint: sky,
      opacity: .54,
      blurSigma: 12,
      borderOpacity: .52,
      shadows: const [],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: ocean, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: ink, height: 1.45, fontSize: 13),
            ),
          ),
        ],
      ),
    );

class EditScaffold extends StatelessWidget {
  const EditScaffold({
    super.key,
    required this.title,
    required this.children,
    required this.save,
  });
  final String title;
  final List<Widget> children;
  final VoidCallback save;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            children: [
              GlassPanel(
                padding: const EdgeInsets.all(20),
                borderRadius: BorderRadius.circular(24),
                opacity: .64,
                blurSigma: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: GlassPanel(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
        borderRadius: BorderRadius.zero,
        tint: paper,
        opacity: .64,
        blurSigma: 14,
        borderOpacity: .52,
        shadows: const [],
        child: FilledButton.icon(
          key: const Key('editor-save'),
          onPressed: save,
          icon: const Icon(Icons.check_rounded),
          label: const Text('保存'),
        ),
      ),
    ),
  );
}

class TripEditor extends StatefulWidget {
  const TripEditor({super.key, this.trip});
  final Trip? trip;
  @override
  State<TripEditor> createState() => _TripEditorState();
}

class _TripEditorState extends State<TripEditor> {
  final key = GlobalKey<FormState>();
  late TextEditingController name, destination;
  late String zone;
  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.trip?.name);
    destination = TextEditingController(text: widget.trip?.destination);
    zone = widget.trip?.zone ?? 'Asia/Shanghai';
  }

  @override
  void dispose() {
    name.dispose();
    destination.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: key,
    child: EditScaffold(
      title: widget.trip == null ? '装好行囊，出发吧' : '编辑旅行',
      children: [
        const Text('从目的地开始，为这段旅程留一个位置。', style: TextStyle(color: muted)),
        gap(28),
        TextFormField(
          controller: name,
          maxLength: 80,
          decoration: const InputDecoration(
            labelText: '旅行名称',
            hintText: '例如：去京都，慢慢走',
          ),
          validator: requiredText,
        ),
        gap(),
        TextFormField(
          controller: destination,
          maxLength: 100,
          decoration: const InputDecoration(
            labelText: '目的地',
            hintText: '例如：日本 · 京都',
          ),
          validator: requiredText,
        ),
        gap(),
        zonePicker(zone, (v) => setState(() => zone = v)),
        gap(),
        hintNote(
          '这里选择的是旅行默认时区；跨国航班或火车可在单段行程中另行设置。',
          icon: Icons.schedule_outlined,
        ),
      ],
      save: () {
        if (!key.currentState!.validate()) return;
        final t = widget.trip == null
            ? Trip(
                id: newId(),
                name: name.text.trim(),
                destination: destination.text.trim(),
                zone: zone,
              )
            : Trip.fromJson(widget.trip!.toJson());
        t.name = name.text.trim();
        t.destination = destination.text.trim();
        t.zone = zone;
        Navigator.pop(context, t);
      },
    ),
  );
}

String? requiredText(String? v) =>
    v == null || v.trim().isEmpty ? '请填写这一项' : null;

class SelectOption<T> {
  const SelectOption(this.value, this.label, {this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

class SelectionField<T> extends StatelessWidget {
  const SelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<SelectOption<T>> options;
  final ValueChanged<T> onChanged;

  Future<void> _showOptions(BuildContext context) async {
    final selected = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .72,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '选择$label',
                  style: const TextStyle(
                    color: ink,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                gap(6),
                Text(
                  '当前：${options.firstWhere((o) => o.value == value).label}',
                  style: const TextStyle(color: muted, fontSize: 13),
                ),
                gap(12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (ctx, index) {
                      final option = options[index];
                      final selected = option.value == value;
                      return PressBounce(
                        child: Material(
                          color: selected ? sky : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: selected ? ocean : line),
                            ),
                            leading: Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.circle_outlined,
                              color: selected ? ocean : muted,
                            ),
                            title: Text(option.label),
                            subtitle: option.subtitle == null
                                ? null
                                : Text(option.subtitle!),
                            onTap: () =>
                                Navigator.pop(sheetContext, option.value),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = options.firstWhere((o) => o.value == value).label;
    return Semantics(
      button: true,
      label: '$label，$selectedLabel',
      child: PressBounce(
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showOptions(context),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.expand_more_rounded),
            ),
            child: Text(
              selectedLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ink, fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}

Widget zonePicker(String value, ValueChanged<String> change) =>
    SelectionField<String>(
      label: '当地时区',
      value: value,
      options: {
        ...commonZones,
        value,
      }.map((z) => SelectOption(z, zoneLabel(z))).toList(),
      onChanged: change,
    );

Widget categoryPicker(String value, ValueChanged<String> change) =>
    SelectionField<String>(
      label: '资料分类（可选）',
      value: value,
      options: {
        ...categories.skip(1),
        value,
      }.map((category) => SelectOption(category, category)).toList(),
      onChanged: change,
    );

Future<String?> chooseImportCategory(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width),
      builder: (ctx) => SizedBox(
        width: MediaQuery.sizeOf(ctx).width,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '给这批资料选个分类',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700),
                ),
                gap(6),
                const Text(
                  '可以跳过，之后也能在资料详情中修改。',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
                gap(16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories
                      .skip(1)
                      .map(
                        (category) => PressBounce(
                          child: ActionChip(
                            avatar: Icon(
                              category == '交通'
                                  ? Icons.train_outlined
                                  : category == '住宿'
                                  ? Icons.hotel_outlined
                                  : category == '攻略'
                                  ? Icons.menu_book_outlined
                                  : Icons.folder_outlined,
                            ),
                            label: Text(category),
                            onPressed: () => Navigator.pop(ctx, category),
                          ),
                        ),
                      )
                      .toList(),
                ),
                gap(12),
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.more_horiz),
                  label: const Text('跳过，归类到其他'),
                ),
              ],
            ),
          ),
        ),
      ),
    );

class ItemEditor extends StatefulWidget {
  const ItemEditor({super.key, required this.tripId, this.item});
  final String tripId;
  final TravelItem? item;
  @override
  State<ItemEditor> createState() => _ItemEditorState();
}

class _ItemEditorState extends State<ItemEditor> {
  final key = GlobalKey<FormState>();
  late TextEditingController title, body, address;
  late String category;
  @override
  void initState() {
    super.initState();
    title = TextEditingController(text: widget.item?.title);
    body = TextEditingController(text: widget.item?.body);
    address = TextEditingController(text: widget.item?.address);
    category = widget.item?.category ?? '其他';
  }

  @override
  void dispose() {
    title.dispose();
    body.dispose();
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Form(
    key: key,
    child: EditScaffold(
      title: widget.item == null ? '收好一份资料' : '编辑资料',
      children: [
        TextFormField(
          controller: title,
          maxLength: 160,
          decoration: const InputDecoration(
            labelText: '标题',
            hintText: '酒店、车票，或一个好去处',
          ),
          validator: requiredText,
        ),
        gap(),
        categoryPicker(category, (v) => setState(() => category = v)),
        gap(),
        TextFormField(
          controller: body,
          maxLines: 6,
          maxLength: 20000,
          decoration: const InputDecoration(
            labelText: '文字 / 链接 / 备注',
            alignLabelWithHint: true,
            hintText: '粘贴攻略、订单信息或网址',
          ),
        ),
        gap(),
        TextFormField(
          controller: address,
          maxLines: 3,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: '当地语言地址',
            alignLabelWithHint: true,
            hintText: '填写后可生成给司机看的大字卡片',
          ),
        ),
        gap(),
        hintNote(
          '文字会保存在本机并支持离线查看；网址对应的网页内容不会自动下载。',
          icon: Icons.offline_pin_outlined,
        ),
        if (widget.item?.hasFile ?? false) ...[
          gap(),
          Text('已保存附件：${widget.item!.fileName}'),
        ],
      ],
      save: () {
        if (!key.currentState!.validate()) return;
        final item = widget.item == null
            ? TravelItem(
                id: newId(),
                tripId: widget.tripId,
                title: title.text.trim(),
                createdAt: DateTime.now().millisecondsSinceEpoch,
              )
            : TravelItem.fromJson(widget.item!.toJson());
        item.title = title.text.trim();
        item.body = body.text.trim();
        item.address = address.text.trim();
        item.category = category;
        Navigator.pop(context, item);
      },
    ),
  );
}

class StopEditor extends StatefulWidget {
  const StopEditor({
    super.key,
    required this.trip,
    required this.items,
    this.stop,
  });
  final Trip trip;
  final List<TravelItem> items;
  final Stop? stop;
  @override
  State<StopEditor> createState() => _StopEditorState();
}

class _StopEditorState extends State<StopEditor> {
  final key = GlobalKey<FormState>();
  late TextEditingController title, note;
  late String zone, endZone;
  late Set<String> itemIds;
  late DateTime wall, endWall;
  late bool withEnd;
  @override
  void initState() {
    super.initState();
    final s = widget.stop;
    title = TextEditingController(text: s?.title);
    note = TextEditingController(text: s?.note);
    zone = s?.zone ?? widget.trip.zone;
    endZone = s?.endZone ?? zone;
    itemIds =
        s?.itemIds.where((id) => widget.items.any((x) => x.id == id)).toSet() ??
        <String>{};
    final z = tz.TZDateTime.from(
      s?.startUtc ?? DateTime.now().add(const Duration(hours: 1)),
      tz.getLocation(zone),
    );
    wall = DateTime(z.year, z.month, z.day, z.hour, z.minute);
    final e = tz.TZDateTime.from(
      s?.endUtc ?? z.add(const Duration(hours: 1)),
      tz.getLocation(endZone),
    );
    endWall = DateTime(e.year, e.month, e.day, e.hour, e.minute);
    withEnd = s?.endUtc != null;
  }

  @override
  void dispose() {
    title.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> pick(bool end) async {
    final current = end ? endWall : wall;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    setState(() {
      final v = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (end) {
        endWall = v;
      } else {
        wall = v;
      }
    });
  }

  Future<void> pickLinkedItems() async {
    final selected = Set<String>.of(itemIds);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, refresh) => SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * .72,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '关联资料',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      gap(4),
                      Text(
                        '可多选，已选 ${selected.length} 份',
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: widget.items.isEmpty
                      ? const Center(child: Text('资料袋里还没有资料'))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: widget.items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 6),
                          itemBuilder: (ctx, index) {
                            final item = widget.items[index];
                            final isSelected = selected.contains(item.id);
                            return PressBounce(
                              child: CheckboxListTile(
                                value: isSelected,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                tileColor: isSelected ? sky : Colors.white,
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${item.category} · ${item.fileName.isEmpty ? '文字资料' : item.fileName}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                secondary: Icon(
                                  item.isPdf
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.folder_outlined,
                                  color: ocean,
                                ),
                                onChanged: (checked) => refresh(() {
                                  if (checked == true) {
                                    selected.add(item.id);
                                  } else {
                                    selected.remove(item.id);
                                  }
                                }),
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pop(sheetContext, selected),
                    icon: const Icon(Icons.check_rounded),
                    label: Text('完成 · ${selected.length} 份'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (result != null && mounted) setState(() => itemIds = result);
  }

  Widget linkedItemsField() {
    final selected = widget.items
        .where((item) => itemIds.contains(item.id))
        .toList();
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: line),
      ),
      child: PressBounce(
        enabled: widget.items.isNotEmpty,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: widget.items.isEmpty ? null : pickLinkedItems,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.folder_copy_outlined, color: ocean),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '关联资料',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      selected.isEmpty ? '可选' : '${selected.length} 份',
                      style: const TextStyle(color: muted),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.expand_more_rounded, color: muted),
                  ],
                ),
                gap(8),
                if (selected.isEmpty)
                  Text(
                    widget.items.isEmpty ? '资料袋里还没有资料' : '点此选择一份或多份资料',
                    style: const TextStyle(color: muted, fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selected
                        .map(
                          (item) => Chip(
                            avatar: Icon(
                              item.isPdf
                                  ? Icons.picture_as_pdf_outlined
                                  : Icons.description_outlined,
                              size: 18,
                              color: ocean,
                            ),
                            label: Text(
                              item.title,
                              overflow: TextOverflow.ellipsis,
                            ),
                            backgroundColor: sky,
                            side: BorderSide.none,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String label(DateTime d) =>
      '${d.year}/${d.month}/${d.day}  ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  Future<DateTime?> resolve(DateTime w, String z) async {
    final options = localInstants(w, z);
    if (options.isEmpty) {
      showAppNotice(context, '这个当地时间因夏令时调整不存在，请修改时间。', isError: true);
      return null;
    }
    if (options.length == 1) return options.first;
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('这个时间出现了两次'),
        children: options
            .map(
              (d) => PressBounce(
                child: SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, d),
                  child: Text(
                    '${label(w)} · UTC${tz.TZDateTime.from(d, tz.getLocation(z)).timeZoneOffset.inHours >= 0 ? '+' : ''}${tz.TZDateTime.from(d, tz.getLocation(z)).timeZoneOffset.inHours}',
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Form(
    key: key,
    child: EditScaffold(
      title: widget.stop == null ? '安排下一站' : '编辑行程',
      children: [
        TextFormField(
          controller: title,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: '这一步要做什么',
            hintText: '例如：搭乘机场快线',
          ),
          validator: requiredText,
        ),
        gap(),
        zonePicker(zone, (v) => setState(() => zone = v)),
        gap(),
        OutlinedButton.icon(
          onPressed: () => pick(false),
          icon: const Icon(Icons.schedule),
          label: Text('开始  ${label(wall)}'),
        ),
        PressBounce(
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('设置结束 / 到达时间'),
            value: withEnd,
            onChanged: (v) => setState(() => withEnd = v),
          ),
        ),
        if (withEnd) ...[
          zonePicker(endZone, (v) => setState(() => endZone = v)),
          gap(),
          OutlinedButton.icon(
            onPressed: () => pick(true),
            icon: const Icon(Icons.flag_outlined),
            label: Text('结束  ${label(endWall)}'),
          ),
          gap(),
        ],
        linkedItemsField(),
        gap(),
        TextFormField(
          controller: note,
          maxLines: 3,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: '备注',
            alignLabelWithHint: true,
          ),
        ),
        gap(),
        hintNote('时间会按所选地点的当地时区保存。即使手机切换时区，行程时刻也不会改变。', icon: Icons.public),
      ],
      save: () async {
        if (!key.currentState!.validate()) return;
        final start = await resolve(wall, zone);
        if (start == null || !mounted) return;
        final end = withEnd ? await resolve(endWall, endZone) : null;
        if (!mounted || !context.mounted || (withEnd && end == null)) return;
        if (end != null && !end.isAfter(start)) {
          showAppNotice(context, '结束时间必须晚于开始时间', isError: true);
          return;
        }
        final s = widget.stop == null
            ? Stop(
                id: newId(),
                tripId: widget.trip.id,
                title: title.text.trim(),
                startUtc: start,
                zone: zone,
              )
            : Stop.fromJson(widget.stop!.toJson());
        s.title = title.text.trim();
        s.startUtc = start;
        s.endUtc = end;
        s.zone = zone;
        s.endZone = endZone;
        s.itemIds = itemIds.toList();
        s.note = note.text.trim();
        Navigator.pop(context, s);
      },
    ),
  );
}

class EmergencyEditor extends StatefulWidget {
  const EmergencyEditor({super.key, required this.trip});
  final Trip trip;
  @override
  State<EmergencyEditor> createState() => _EmergencyEditorState();
}

class _EmergencyEditorState extends State<EmergencyEditor> {
  late final contact = TextEditingController(text: widget.trip.contact),
      phone = TextEditingController(text: widget.trip.phone),
      insurance = TextEditingController(text: widget.trip.insurance),
      help = TextEditingController(text: widget.trip.help);
  @override
  void dispose() {
    for (final c in [contact, phone, insurance, help]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EditScaffold(
    title: '随身应急卡',
    children: [
      hintNote(
        '这些内容只保存在本机。提前填写联系人、保险和求助语，需要时会更从容。',
        icon: Icons.health_and_safety_outlined,
      ),
      gap(),
      TextField(
        controller: contact,
        maxLength: 100,
        decoration: const InputDecoration(labelText: '紧急联系人'),
      ),
      gap(),
      TextField(
        controller: phone,
        maxLength: 40,
        keyboardType: TextInputType.phone,
        decoration: const InputDecoration(labelText: '联系电话（含国家区号）'),
      ),
      gap(),
      TextField(
        controller: insurance,
        maxLength: 3000,
        maxLines: 4,
        decoration: const InputDecoration(
          labelText: '保险公司 / 保单号 / 援助电话',
          alignLabelWithHint: true,
        ),
      ),
      gap(),
      TextField(
        controller: help,
        maxLength: 3000,
        maxLines: 5,
        decoration: const InputDecoration(
          labelText: '求助语（可自行填写多种语言）',
          alignLabelWithHint: true,
        ),
      ),
    ],
    save: () {
      final t = Trip.fromJson(widget.trip.toJson());
      t.contact = contact.text.trim();
      t.phone = phone.text.trim();
      t.insurance = insurance.text.trim();
      t.help = help.text.trim();
      Navigator.pop(context, t);
    },
  );
}
