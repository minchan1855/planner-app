import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../widgets/fields.dart';
import 'today.dart' show yColor;

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
        if (w.goals.isEmpty && fromMonth.isEmpty) Text('＋ 버튼으로 목표를 추가하세요', style: TextStyle(color: Theme.of(context).hintColor)),
      ]),
    );

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
            Expanded(child: Column(children: [affirmation, goals, habits])),
            Expanded(child: Column(children: [days, review])),
          ]),
        ]))),
      ]);
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [header, affirmation, goals, days, habits, review]);
  }

  Widget _dayTile(BuildContext context, DateTime d, int i) {
    final has = store.hasDay(d);
    final p = has ? store.day(d) : null;
    final ys = p?.tasksOf('Y').where((t) => t.title.trim().isNotEmpty).toList() ?? [];
    final rate = p?.yDoneRate;
    final isToday = dateKey(d) == dateKey(DateTime.now());
    return InkWell(
      onTap: () => widget.openDay(d),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Theme.of(context).dividerColor))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 56,
            child: Text('${_days[i]} ${d.day}',
                style: TextStyle(fontWeight: FontWeight.w700, color: isToday ? Theme.of(context).colorScheme.primary : (i >= 5 ? Colors.red.shade300 : null))),
          ),
          Expanded(
            child: ys.isEmpty
                ? Text('계획 없음', style: TextStyle(color: Theme.of(context).hintColor))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    for (final t in ys.take(4))
                      Text('${t.done ? '✓' : '·'} ${t.title}', style: TextStyle(decoration: t.done ? TextDecoration.lineThrough : null, color: t.done ? Colors.grey : null)),
                    if (ys.length > 4) Text('외 ${ys.length - 4}개', style: TextStyle(color: Theme.of(context).hintColor, fontSize: 12)),
                  ]),
          ),
          if (rate != null)
            SizedBox(
              width: 44,
              child: Column(children: [
                Text('${(rate * 100).round()}%', style: TextStyle(fontWeight: FontWeight.w700, color: yColor.withValues(alpha: .4 + .6 * rate))),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: rate, color: yColor, backgroundColor: yColor.withValues(alpha: .12)),
              ]),
            ),
          const Icon(Icons.chevron_right, size: 18),
        ]),
      ),
    );
  }
}
