import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../widgets/charts.dart';
import '../widgets/fields.dart';
import 'today.dart' show yColor, bColor;

const _days = ['월', '화', '수', '목', '금', '토', '일'];

class WeekScreen extends StatefulWidget {
  const WeekScreen({super.key, required this.store, required this.openDay});
  final Store store;
  final void Function(DateTime d) openDay;

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  DateTime monday = mondayOf(DateTime.now());

  Store get store => widget.store;
  void edit(void Function(WeekPlan w) f) {
    final w = store.week(monday);
    f(w);
    store.saveWeek(w);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: store, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final w = store.week(monday);
    final wom = weekOfMonth(monday);
    final m = store.month(wom.month);
    final monthFixed = m.fixed.where((s) => s.trim().isNotEmpty).toList();
    final fromMonth = wom.week <= 5 ? m.weeks[wom.week - 1].where((s) => s.trim().isNotEmpty).toList() : <String>[];
    final sunday = monday.add(const Duration(days: 6));
    final wide = MediaQuery.sizeOf(context).width >= 900;

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(children: [
        IconButton(onPressed: () => setState(() => monday = monday.subtract(const Duration(days: 7))), icon: const Icon(Icons.chevron_left)),
        Expanded(
          child: Column(children: [
            Text('${wom.month.month}월 ${wom.week}주차', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            Text('${DateFormat('M.d').format(monday)} ~ ${DateFormat('M.d').format(sunday)}', style: TextStyle(color: Theme.of(context).hintColor)),
          ]),
        ),
        IconButton(onPressed: () => setState(() => monday = monday.add(const Duration(days: 7))), icon: const Icon(Icons.chevron_right)),
      ]),
    );

    final affirmation = Section(
      title: '이번 주 확언',
      child: SaveField(key: ValueKey('wa-${w.start}'), value: w.affirmation, hint: '이번 주 나에게 하는 말', maxLines: null, onChanged: (v) => edit((x) => x.affirmation = v)),
    );

    final goals = Section(
      title: '이번 주 목표',
      trailing: IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => edit((x) => x.goals.add(''))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (monthFixed.isNotEmpty) ...[
          Text('${wom.month.month}월 고정된 일', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final f in monthFixed) Chip(avatar: const Icon(Icons.push_pin, size: 16), label: Text(f), visualDensity: VisualDensity.compact),
          ]),
          const SizedBox(height: 8),
        ],
        if (fromMonth.isNotEmpty) ...[
          Text('월 계획 ${wom.week}주차 할 일', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          for (final s in fromMonth) Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text('• $s')),
          const SizedBox(height: 6),
        ],
        for (var i = 0; i < w.goals.length; i++)
          Row(children: [
            const Text('•  '),
            Expanded(child: SaveField(key: ValueKey('wg-${w.start}-$i-${w.goals.length}'), value: w.goals[i], dense: true, hint: '목표', onChanged: (v) => edit((x) => x.goals[i] = v))),
            IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: () => edit((x) => x.goals.removeAt(i))),
          ]),
        if (w.goals.isEmpty && fromMonth.isEmpty && monthFixed.isEmpty) Text('＋ 버튼으로 목표를 추가하세요', style: TextStyle(color: Theme.of(context).hintColor)),
      ]),
    );

    final weekFixed = Section(
      title: '주간 고정할 일',
      color: Colors.blueGrey,
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => edit((x) {
          _FixedRow.justAdded.add('${x.start}-${x.fixed.length}');
          x.fixed.add('');
        }),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (w.fixed.isNotEmpty)
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            proxyDecorator: (child, _, _) => Material(elevation: 4, borderRadius: BorderRadius.circular(8), child: child),
            onReorderItem: (from, to) => edit((x) {
              final t = x.fixed.removeAt(from);
              x.fixed.insert(to, t);
            }),
            children: [
              for (var i = 0; i < w.fixed.length; i++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey('wfr-${w.start}-$i'),
                  index: i,
                  child: _FixedRow(
                    text: w.fixed[i],
                    startEditing: _FixedRow.justAdded.remove('${w.start}-$i'),
                    onChanged: (v) => edit((x) => x.fixed[i] = v),
                    onDelete: () => edit((x) => x.fixed.removeAt(i)),
                  ),
                ),
            ],
          ),
        Text(w.fixed.isEmpty ? '여기 적은 일은 이번 주 매일 오늘 화면에 보여요' : '꾹 눌러 순서를 바꿀 수 있어요 · 오늘 화면에도 보여요',
            style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
      ]),
    );

    final summary = _WeekSummary(store: store, monday: monday, week: w);

    final days = Section(
      title: '요일별 계획',
      child: Column(children: [
        for (var i = 0; i < 7; i++) _dayTile(context, monday.add(Duration(days: i)), i),
      ]),
    );

    final habits = Section(
      title: '습관 체크',
      trailing: IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => edit((x) => x.habits.add(Habit()))),
      child: Column(children: [
        Row(children: [
          const Expanded(child: SizedBox()),
          for (final d in _days) SizedBox(width: 34, child: Center(child: Text(d, style: const TextStyle(fontSize: 12)))),
          const SizedBox(width: 36),
        ]),
        for (var hi = 0; hi < w.habits.length; hi++)
          Row(children: [
            Expanded(child: SaveField(key: ValueKey('h-${w.habits[hi].id}'), value: w.habits[hi].name, dense: true, hint: '습관 이름', onChanged: (v) => edit((x) => x.habits[hi].name = v))),
            for (var d = 0; d < 7; d++)
              SizedBox(
                width: 34,
                child: Checkbox(
                  visualDensity: VisualDensity.compact,
                  value: w.habits[hi].checks[d],
                  onChanged: (v) => edit((x) => x.habits[hi].checks[d] = v ?? false),
                ),
              ),
            SizedBox(width: 36, child: IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: () => edit((x) => x.habits.removeAt(hi)))),
          ]),
        if (w.habits.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text('예: 운동, 독서, 물 2L', style: TextStyle(color: Theme.of(context).hintColor))),
      ]),
    );

    final review = Section(
      title: '주간 회고',
      child: Column(children: [
        SaveField(key: ValueKey('g-${w.start}'), value: w.good, label: '잘한 점', maxLines: null, onChanged: (v) => edit((x) => x.good = v)),
        const SizedBox(height: 10),
        SaveField(key: ValueKey('b-${w.start}'), value: w.bad, label: '아쉬운 점', maxLines: null, onChanged: (v) => edit((x) => x.bad = v)),
        const SizedBox(height: 10),
        SaveField(key: ValueKey('n-${w.start}'), value: w.next, label: '다음 주 다짐', maxLines: null, onChanged: (v) => edit((x) => x.next = v)),
      ]),
    );

    if (wide) {
      return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: Column(children: [
          header,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: [summary, affirmation, goals, weekFixed, habits])),
            Expanded(child: Column(children: [days, review])),
          ]),
        ]))),
      ]);
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [header, summary, affirmation, goals, weekFixed, days, habits, review]);
  }

  Widget _dayTile(BuildContext context, DateTime d, int i) {
    final has = store.hasDay(d);
    final p = has ? store.day(d) : null;
    final ys = p?.tasksOf('Y').where((t) => t.title.trim().isNotEmpty).toList() ?? [];
    final rate = p?.yDoneRate;
    final isToday = dateKey(d) == dateKey(DateTime.now());
    final past = d.isBefore(dateOnly(DateTime.now()));
    final missed = ys.where((t) => !t.done).toList();
    final w = store.week(monday);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            width: 52,
            child: Text('${_days[i]} ${d.day}',
                style: TextStyle(fontWeight: FontWeight.w700, color: isToday ? Theme.of(context).colorScheme.primary : (i >= 5 ? Colors.red.shade300 : null))),
          ),
        ),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SaveField(
              key: ValueKey('wd-${w.start}-$i'),
              value: w.days[i],
              dense: true,
              maxLines: null,
              hint: '${_days[i]}요일 계획 적기',
              onChanged: (v) => edit((x) => x.days[i] = v),
            ),
            if (ys.isNotEmpty && past) ...[
              if (missed.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('✓ 반드시 할 일을 다 끝냈어요', style: TextStyle(fontSize: 12, color: Color(0xFF30A46C))),
                )
              else
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: yColor.withValues(alpha: .08), borderRadius: BorderRadius.circular(6)),
                  child: Text('못한 일: ${missed.map((t) => t.title).join(', ')}', style: const TextStyle(fontSize: 12, color: yColor)),
                ),
            ] else if (ys.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Wrap(spacing: 8, children: [
                  for (final t in ys.take(4))
                    Text('${t.done ? '✓' : '·'} ${t.title}',
                        style: TextStyle(fontSize: 12, decoration: t.done ? TextDecoration.lineThrough : null, color: t.done ? Colors.grey : Theme.of(context).hintColor)),
                  if (ys.length > 4) Text('외 ${ys.length - 4}개', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                ]),
              ),
          ]),
        ),
        if (rate != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: 40,
              child: Column(children: [
                Text('${(rate * 100).round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: yColor.withValues(alpha: .4 + .6 * rate))),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: rate, color: yColor, backgroundColor: yColor.withValues(alpha: .12)),
              ]),
            ),
          ),
        IconButton(
          tooltip: '그날 오늘 화면으로',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.chevron_right),
          onPressed: () => widget.openDay(d),
        ),
      ]),
    );
  }
}

/// 이번 주 한눈에: 요일별 완료율 막대 + 주간 완료율 + 습관 달성률
class _WeekSummary extends StatelessWidget {
  const _WeekSummary({required this.store, required this.monday, required this.week});
  final Store store;
  final DateTime monday;
  final WeekPlan week;

  @override
  Widget build(BuildContext context) {
    final rates = <double?>[];
    var done = 0, all = 0, minutes = 0;
    for (var i = 0; i < 7; i++) {
      final d = monday.add(Duration(days: i));
      if (!store.hasDay(d)) {
        rates.add(null);
        continue;
      }
      final p = store.day(d);
      final ys = p.tasksOf('Y').where((t) => t.title.trim().isNotEmpty).toList();
      all += ys.length;
      done += ys.where((t) => t.done).length;
      minutes += p.tasks.where((t) => t.done).fold(0, (a, t) => a + t.minutes);
      rates.add(ys.isEmpty ? null : ys.where((t) => t.done).length / ys.length);
    }
    final todayIdx = DateTime.now().difference(monday).inDays;
    final habits = week.habits.where((h) => h.name.trim().isNotEmpty).toList();
    return Section(
      title: '이번 주 한눈에',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Ring(value: all == 0 ? 0 : done / all, color: yColor, size: 96, label: 'Y $done/$all'),
          const SizedBox(width: 12),
          Expanded(child: MiniBars(values: rates, labels: _days, color: yColor, height: 70, highlight: todayIdx >= 0 && todayIdx < 7 ? todayIdx : null)),
        ]),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          StatTile(value: fmtMinutes(minutes), label: '끝낸 일 시간', color: bColor),
          StatTile(value: '${store.memos().where((m) {
                final d = DateTime.parse(m.date).difference(monday).inDays;
                return d >= 0 && d < 7;
              }).length}', label: '메모'),
        ]),
        if (habits.isNotEmpty) ...[
          const Divider(height: 24),
          for (final h in habits)
            ProgressRow(label: h.name, value: h.checks.where((c) => c).length / 7, color: const Color(0xFF30A46C), trailing: '${h.checks.where((c) => c).length}/7'),
        ],
      ]),
    );
  }
}

class _FixedRow extends StatefulWidget {
  const _FixedRow({required this.text, required this.startEditing, required this.onChanged, required this.onDelete});
  final String text;
  final bool startEditing;
  final ValueChanged<String> onChanged;
  final VoidCallback onDelete;

  static final Set<String> justAdded = {};

  @override
  State<_FixedRow> createState() => _FixedRowState();
}

class _FixedRowState extends State<_FixedRow> {
  late bool _editing = widget.startEditing;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: Row(children: [
        const Icon(Icons.push_pin, size: 16, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: _editing
              ? SaveField(
                  value: widget.text,
                  dense: true,
                  autofocus: true,
                  hint: '매일 볼 고정할 일',
                  onChanged: widget.onChanged,
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
                    child: Text(widget.text.isEmpty ? '매일 볼 고정할 일' : widget.text,
                        style: TextStyle(color: widget.text.isEmpty ? Theme.of(context).hintColor : null)),
                  ),
                ),
        ),
        IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: widget.onDelete),
      ]),
    );
  }
}
