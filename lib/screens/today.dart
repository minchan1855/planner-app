import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../widgets/charts.dart';
import '../widgets/fields.dart';
import '../widgets/memo.dart';
import '../widgets/timetable.dart';

const yColor = Color(0xFFE5484D); // Y-time
const bColor = Color(0xFF3E63DD); // B-time

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, required this.store, required this.selected});
  final Store store;
  final ValueNotifier<DateTime> selected;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: selected,
      builder: (context, d, _) => ListenableBuilder(
        listenable: store,
        builder: (context, _) => _DayView(
          key: ValueKey(dateKey(d)),
          store: store,
          date: d,
          selected: selected,
        ),
      ),
    );
  }
}

class _DayView extends StatelessWidget {
  const _DayView({
    super.key,
    required this.store,
    required this.date,
    required this.selected,
  });
  final Store store;
  final DateTime date;
  final ValueNotifier<DateTime> selected;

  DayPlan get p => store.day(date);
  void edit(void Function(DayPlan p) f) {
    final x = p;
    f(x);
    store.saveDay(x);
  }

  @override
  Widget build(BuildContext context) {
    final plan = p;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final isToday = dateKey(date) == dateKey(DateTime.now());
    final week = store.week(mondayOf(date));
    final weekFixed = week.fixed.where((s) => s.trim().isNotEmpty).toList();

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () =>
                selected.value = date.subtract(const Duration(days: 1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final r = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (r != null) selected.value = r;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    Text(
                      DateFormat('yyyy. M. d. (E)', 'ko').format(date),
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (!isToday)
                      TextButton(
                        onPressed: () =>
                            selected.value = dateOnly(DateTime.now()),
                        child: const Text('오늘로'),
                      )
                    else
                      Text(
                        '오늘',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: () => selected.value = date.add(const Duration(days: 1)),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );

    final summary = _Summary(
      plan: plan,
      memoCount: store.memos(date: plan.date).length,
    );

    final affirmation = Section(
      title: '오늘의 확언',
      child: SaveField(
        value: plan.affirmation,
        hint: '오늘 나에게 해주고 싶은 말',
        maxLines: null,
        onChanged: (v) => edit((p) => p.affirmation = v),
      ),
    );

    final dayNote = week.days[date.weekday - 1].trim();
    final fixed = weekFixed.isEmpty && dayNote.isEmpty
        ? null
        : Section(
            title: '이번 주 계획에서',
            color: Colors.blueGrey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (dayNote.isNotEmpty) ...[
                  Text(
                    '${DateFormat('E요일', 'ko').format(date)} 계획',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(dayNote),
                  if (weekFixed.isNotEmpty) const SizedBox(height: 10),
                ],
                if (weekFixed.isNotEmpty) ...[
                  Text(
                    '주간 고정할 일',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final f in weekFixed)
                        Chip(
                          avatar: const Icon(Icons.push_pin, size: 16),
                          label: Text(f),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          );

    final yBox = _TaskSection(
      type: 'Y',
      title: 'Y-time · 반드시 해야 할 일',
      color: yColor,
      plan: plan,
      edit: edit,
    );
    final bBox = _TaskSection(
      type: 'B',
      title: 'B-time · 여유 있게 할 일',
      color: bColor,
      plan: plan,
      edit: edit,
    );
    final dist = _Distribution(plan: plan, edit: edit);
    final hours = _HourTable(plan: plan, edit: edit, wide: wide);
    final memos = _MemoSection(store: store, date: date);

    if (wide) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  header,
                  summary,
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: affirmation),
                      if (fixed != null) Expanded(child: fixed),
                    ],
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 3, child: yBox),
                      Expanded(flex: 3, child: bBox),
                      Expanded(flex: 2, child: dist),
                    ],
                  ),
                  hours,
                  memos,
                ],
              ),
            ),
          ),
        ],
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        header,
        summary,
        affirmation,
        ?fixed,
        yBox,
        bBox,
        dist,
        hours,
        memos,
      ],
    );
  }
}

/// 오늘 한눈에: 완료율 고리 + 시간 도넛 + 시간대 띠
class _Summary extends StatelessWidget {
  const _Summary({required this.plan, required this.memoCount});
  final DayPlan plan;
  final int memoCount;

  @override
  Widget build(BuildContext context) {
    final named = plan.tasks.where((t) => t.title.trim().isNotEmpty).toList();
    final done = named.where((t) => t.done).length;
    final rate = named.isEmpty ? 0.0 : done / named.length;
    final total = plan.activeMinutes,
        y = plan.minutesOf('Y'),
        b = plan.minutesOf('B');
    final free = (total - y - b).clamp(0, 24 * 60);
    final taskHours = {
      for (final t in plan.tasks.where((t) => t.title.trim().isNotEmpty))
        ...t.hours,
    };
    bool hasPlan(HourSlot s) =>
        s.plan.trim().isNotEmpty || taskHours.contains(s.hour);
    final planned = plan.slots.where(hasPlan).length;
    final hint = Theme.of(context).hintColor;

    String ratingAt(HourSlot s) {
      if (s.rating.isNotEmpty) return s.rating;
      for (final t in plan.tasks) {
        if (t.rating.isNotEmpty && t.hours.contains(s.hour)) return t.rating;
      }
      return '';
    }

    Color slotColor(HourSlot s) => switch (ratingAt(s)) {
      'O' => const Color(0xFF30A46C),
      '△' => const Color(0xFFF5A623),
      'X' => yColor,
      _ =>
        hasPlan(s) ? bColor.withValues(alpha: .35) : hint.withValues(alpha: .1),
    };

    return Section(
      title: '오늘 한눈에',
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Ring(
                value: rate,
                color: yColor,
                size: 104,
                label: '할 일 $done/${named.length}',
              ),
              Donut(
                size: 104,
                stroke: 14,
                parts: [
                  (y.toDouble(), yColor),
                  (b.toDouble(), bColor),
                  (free.toDouble(), Colors.grey.shade300),
                ],
                center: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      fmtMinutes(total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text('활동시간', style: TextStyle(fontSize: 11, color: hint)),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatTile(value: '$planned', label: '계획한 시간', color: bColor),
                  const SizedBox(height: 10),
                  StatTile(value: '$memoCount', label: '메모', color: voiceColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final s in plan.slots)
                Expanded(
                  child: Tooltip(
                    message:
                        '${s.hour}시 ${s.plan}${s.rating.isEmpty ? '' : ' (${s.rating})'}',
                    child: Container(
                      height: 14,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: slotColor(s),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${plan.slots.isEmpty ? '' : plan.slots.first.hour}시',
                style: TextStyle(fontSize: 11, color: hint),
              ),
              const Spacer(),
              for (final (c, l) in [
                (const Color(0xFF30A46C), 'O'),
                (const Color(0xFFF5A623), '△'),
                (yColor, 'X'),
                (bColor.withValues(alpha: .35), '계획'),
              ]) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Text(' $l  ', style: TextStyle(fontSize: 11, color: hint)),
              ],
              const Spacer(),
              Text(
                '${plan.slots.isEmpty ? '' : plan.slots.last.hour + 1}시',
                style: TextStyle(fontSize: 11, color: hint),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MemoSection extends StatelessWidget {
  const _MemoSection({required this.store, required this.date});
  final Store store;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final list = store.memos(date: dateKey(date)).reversed.toList();
    return Section(
      title: '오늘의 메모',
      color: voiceColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MemoButtons(store: store, date: date),
          const SizedBox(height: 8),
          for (final m in list)
            MemoCard(key: ValueKey(m.id), store: store, memo: m),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.type,
    required this.title,
    required this.color,
    required this.plan,
    required this.edit,
  });
  final String type;
  final String title;
  final Color color;
  final DayPlan plan;
  final void Function(void Function(DayPlan)) edit;

  @override
  Widget build(BuildContext context) {
    final list = plan.tasksOf(type);
    return Section(
      title: title,
      color: color,
      trailing: IconButton(
        tooltip: '추가',
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => edit((p) {
          final t = PlanTask(type: type, priority: list.length + 1);
          _TaskRowState.justAdded.add(t.id);
          p.tasks.add(t);
        }),
      ),
      child: list.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '＋ 버튼으로 할 일을 추가하세요',
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ReorderableListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  buildDefaultDragHandles: false,
                  proxyDecorator: (child, _, _) => Material(
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
                    child: child,
                  ),
                  onReorderItem: (from, to) => edit((p) {
                    final ordered = p.tasksOf(type);
                    final t = ordered.removeAt(from);
                    ordered.insert(to, t);
                    for (var i = 0; i < ordered.length; i++) {
                      ordered[i].priority = i + 1;
                    }
                  }),
                  children: [
                    for (var i = 0; i < list.length; i++)
                      ReorderableDelayedDragStartListener(
                        key: ValueKey(list[i].id),
                        index: i,
                        child: _TaskRow(
                          task: list[i],
                          color: color,
                          edit: edit,
                        ),
                      ),
                  ],
                ),
                if (list.length > 1)
                  Text(
                    '꾹 눌러서 위아래로 옮기면 순위가 바뀌어요',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TaskRow extends StatefulWidget {
  const _TaskRow({required this.task, required this.color, required this.edit});
  final PlanTask task;
  final Color color;
  final void Function(void Function(DayPlan)) edit;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow> {
  /// 방금 + 로 추가한 할 일만 바로 입력창을 엽니다 (스크롤해서 다시 보일 때는 열지 않아요).
  static final Set<String> justAdded = {};
  late bool _editing = justAdded.remove(widget.task.id);

  PlanTask get task => widget.task;
  Color get color => widget.color;
  void _set(void Function(PlanTask t) f) =>
      widget.edit((p) => f(p.tasks.firstWhere((x) => x.id == task.id)));

  @override
  Widget build(BuildContext context) {
    final titleStyle = task.done
        ? const TextStyle(
            decoration: TextDecoration.lineThrough,
            color: Colors.grey,
          )
        : null;
    return Container(
      color: Colors.transparent,
      child: Row(
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: color.withValues(alpha: .15),
            child: Text(
              '${task.priority}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _editing
                ? SaveField(
                    value: task.title,
                    hint: '할 일',
                    dense: true,
                    autofocus: true,
                    style: titleStyle,
                    onChanged: (v) => _set((t) => t.title = v),
                    onSubmitted: (_) => setState(() => _editing = false),
                    onFocusLost: () {
                      if (mounted) setState(() => _editing = false);
                    },
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _editing = true),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        task.title.isEmpty ? '할 일' : task.title,
                        style: (titleStyle ?? const TextStyle()).copyWith(
                          color: task.title.isEmpty
                              ? Theme.of(context).hintColor
                              : null,
                        ),
                      ),
                    ),
                  ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final r = await pickRange(
                context,
                start: task.start,
                end: task.end,
              );
              if (r == null) return;
              _set((t) {
                if (r.$1.isEmpty) {
                  t.start = null;
                  t.end = null;
                } else {
                  if (t.alarm != null && t.alarm == t.start) t.alarm = r.$1;
                  t.start = r.$1;
                  t.end = r.$2;
                  t.minutes = parseHm(r.$2)! - parseHm(r.$1)!;
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: task.rangeText == null
                  ? Icon(
                      Icons.schedule,
                      size: 20,
                      color: Theme.of(context).hintColor,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          task.start!,
                          style: TextStyle(
                            fontSize: 11,
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          task.end!,
                          style: TextStyle(fontSize: 11, color: color),
                        ),
                      ],
                    ),
            ),
          ),
          IconButton(
            tooltip: task.alarm == null ? '알람 켜기' : '알람 ${task.alarm} 끄기',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              task.alarm == null
                  ? Icons.notifications_none
                  : Icons.notifications_active,
              size: 20,
              color: task.alarm == null ? Theme.of(context).hintColor : color,
            ),
            onPressed: () async {
              if (task.alarm != null) return _set((t) => t.alarm = null);
              var at = task.start;
              at ??= await pickTime(context, null);
              if (at == null) return;
              _set((t) => t.alarm = at);
              if (context.mounted) {
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    SnackBar(
                      content: Text('$at 알람을 켰어요'),
                      duration: const Duration(seconds: 2),
                    ),
                  );
              }
            },
          ),
          Checkbox(
            value: task.done,
            activeColor: color,
            onChanged: (v) => _set((t) => t.done = v ?? false),
          ),
          IconButton(
            tooltip: '삭제',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () =>
                widget.edit((p) => p.tasks.removeWhere((x) => x.id == task.id)),
          ),
        ],
      ),
    );
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.plan, required this.edit});
  final DayPlan plan;
  final void Function(void Function(DayPlan)) edit;

  @override
  Widget build(BuildContext context) {
    final total = plan.activeMinutes,
        y = plan.minutesOf('Y'),
        b = plan.minutesOf('B');
    final free = total - y - b;
    Widget row(String label, Widget value, [Color? c]) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          if (c != null)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
          Expanded(child: Text(label)),
          value,
        ],
      ),
    );
    Widget timeBtn(String v, void Function(String) set) => TextButton(
      onPressed: () async {
        final r = await pickTime(context, v);
        if (r != null) set(r);
      },
      child: Text(v),
    );
    return Section(
      title: '시간 분배',
      child: Column(
        children: [
          row('기상시간', timeBtn(plan.wake, (v) => edit((p) => p.wake = v))),
          row('취침시간', timeBtn(plan.sleep, (v) => edit((p) => p.sleep = v))),
          const Divider(),
          row(
            '총 활동시간',
            Text(
              fmtMinutes(total),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          row('Y-time', Text(fmtMinutes(y)), yColor),
          row('B-time', Text(fmtMinutes(b)), bColor),
          row(
            'Free time',
            Text(
              fmtMinutes(free),
              style: TextStyle(color: free < 0 ? Colors.red : null),
            ),
            Colors.grey,
          ),
          if (total > 0) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (y > 0)
                      Expanded(
                        flex: y,
                        child: Container(color: yColor),
                      ),
                    if (b > 0)
                      Expanded(
                        flex: b,
                        child: Container(color: bColor),
                      ),
                    if (free > 0)
                      Expanded(
                        flex: free,
                        child: Container(color: Colors.grey.shade300),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HourTable extends StatelessWidget {
  const _HourTable({
    required this.plan,
    required this.edit,
    required this.wide,
  });
  final DayPlan plan;
  final void Function(void Function(DayPlan)) edit;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final table = DayTimetable(plan: plan, edit: edit, hourHeight: wide ? 60 : 54);
    return Section(
      title: '오늘 계획표',
      trailing: IconButton(tooltip: '계획 추가', icon: const Icon(Icons.add_circle_outline), onPressed: () => table.openAdd(context)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('＋ 로 계획을 추가하고, 블록을 누르면 평가·알람을 정해요', style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
        const SizedBox(height: 8),
        table,
      ]),
    );
  }
}
