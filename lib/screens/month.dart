import 'package:flutter/material.dart';

import '../models.dart';
import '../store.dart';
import '../widgets/charts.dart';
import '../widgets/fields.dart';
import 'today.dart' show yColor;

class MonthScreen extends StatefulWidget {
  const MonthScreen({super.key, required this.store, required this.openDay});
  final Store store;
  final void Function(DateTime d) openDay;

  @override
  State<MonthScreen> createState() => _MonthScreenState();
}

class _MonthScreenState extends State<MonthScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  Store get store => widget.store;

  void edit(void Function(MonthPlan m) f) {
    final m = store.month(month);
    f(m);
    store.saveMonth(m);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: store, builder: (context, _) => _build(context));

  Widget _list(String id, List<String> items, String hint, void Function(void Function(List<String>)) change) {
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        Row(children: [
          const Text('•  '),
          Expanded(child: SaveField(key: ValueKey('$id-${month.month}-$i-${items.length}'), value: items[i], dense: true, hint: hint, onChanged: (v) => change((l) => l[i] = v))),
          IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.close, size: 18), onPressed: () => change((l) => l.removeAt(i))),
        ]),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(onPressed: () => change((l) => l.add('')), icon: const Icon(Icons.add, size: 18), label: const Text('추가')),
      ),
    ]);
  }

  Widget _build(BuildContext context) {
    final m = store.month(month);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final mk = monthKey(month);

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
      child: Row(children: [
        IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
        Expanded(child: Center(child: Text('${month.year}년 ${month.month}월', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)))),
        IconButton(onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
      ]),
    );

    final affirmation = Section(
      title: '월 확언',
      child: SaveField(key: ValueKey('ma-$mk'), value: m.affirmation, hint: '이번 달 나에게 하는 말', maxLines: null, onChanged: (v) => edit((x) => x.affirmation = v)),
    );

    final goals = Section(
      title: '월 목표',
      child: Column(children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text('${i + 1}  ', style: const TextStyle(fontWeight: FontWeight.w700)),
              Expanded(flex: 3, child: SaveField(key: ValueKey('mg-$mk-$i'), value: m.goals[i].text, dense: true, hint: '목표', onChanged: (v) => edit((x) => x.goals[i].text = v))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: SaveField(key: ValueKey('mr-$mk-$i'), value: m.goals[i].reward, dense: true, hint: '보상수치', onChanged: (v) => edit((x) => x.goals[i].reward = v))),
            ]),
          ),
      ]),
    );

    final todos = Section(
      title: '월 할 일',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('고정된 일', style: TextStyle(fontWeight: FontWeight.w700)),
        _list('fx', m.fixed, '매주/매달 반복되는 일', (f) => edit((x) => f(x.fixed))),
        for (var w = 0; w < 5; w++) ...[
          const Divider(),
          Text('${w + 1}주차', style: const TextStyle(fontWeight: FontWeight.w700)),
          _list('w$w', m.weeks[w], '${w + 1}주차 할 일', (f) => edit((x) => f(x.weeks[w]))),
        ],
      ]),
    );

    final summary = _MonthSummary(store: store, month: month);

    final cal = Section(title: '달력', child: _Calendar(store: store, month: month, openDay: widget.openDay));

    if (wide) {
      return ListView(padding: const EdgeInsets.only(bottom: 24), children: [
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 1200), child: Column(children: [
          header,
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(children: [summary, affirmation, goals, cal])),
            Expanded(child: todos),
          ]),
        ]))),
      ]);
    }
    return ListView(padding: const EdgeInsets.only(bottom: 24), children: [header, summary, affirmation, goals, cal, todos]);
  }
}

class _Calendar extends StatelessWidget {
  const _Calendar({required this.store, required this.month, required this.openDay});
  final Store store;
  final DateTime month;
  final void Function(DateTime) openDay;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final start = mondayOf(first);
    final last = DateTime(month.year, month.month + 1, 0);
    final weeks = ((last.difference(start).inDays + 1) / 7).ceil();
    final today = dateKey(DateTime.now());
    return Column(children: [
      Row(children: [for (final d in ['월', '화', '수', '목', '금', '토', '일']) Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 12))))]),
      for (var w = 0; w < weeks; w++)
        Row(children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (context) {
              final d = start.add(Duration(days: w * 7 + i));
              final inMonth = d.month == month.month;
              final rate = store.hasDay(d) ? store.day(d).yDoneRate : null;
              return Expanded(
                child: InkWell(
                  onTap: () => openDay(d),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    height: 44,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: rate == null ? null : yColor.withValues(alpha: .08 + .32 * rate),
                      border: dateKey(d) == today ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
                    ),
                    child: Center(
                      child: Text('${d.day}', style: TextStyle(color: inMonth ? (i >= 5 ? Colors.red.shade300 : null) : Colors.grey.shade400)),
                    ),
                  ),
                ),
              );
            }),
        ]),
      const SizedBox(height: 6),
      Text('색이 진할수록 그날 Y-time을 많이 끝낸 날이에요', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
    ]);
  }
}

class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.store, required this.month});
  final Store store;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final last = DateTime(month.year, month.month + 1, 0).day;
    final weekRates = List<List<double>>.generate(6, (_) => []);
    final start = mondayOf(DateTime(month.year, month.month, 1));
    var planned = 0, perfect = 0, streak = 0, best = 0;
    final rates = <double>[];
    for (var d = 1; d <= last; d++) {
      final day = DateTime(month.year, month.month, d);
      final r = store.hasDay(day) ? store.day(day).yDoneRate : null;
      if (r != null) {
        planned++;
        rates.add(r);
        weekRates[day.difference(start).inDays ~/ 7].add(r);
        if (r >= 1) perfect++;
      }
      streak = (r != null && r >= 1) ? streak + 1 : 0;
      if (streak > best) best = streak;
    }
    final avg = rates.isEmpty ? 0.0 : rates.reduce((a, b) => a + b) / rates.length;
    final memoCount = store.memos().where((m) => m.date.startsWith(monthKey(month))).length;
    final weeks = weekRates;
    final nWeeks = ((DateTime(month.year, month.month, last).difference(start).inDays) ~/ 7) + 1;
    return Section(
      title: '이번 달 한눈에',
      child: Column(children: [
        Row(children: [
          Ring(value: avg, color: yColor, size: 96, label: '평균 완료율'),
          const SizedBox(width: 12),
          Expanded(
            child: MiniBars(
              values: [for (var i = 0; i < nWeeks; i++) weeks[i].isEmpty ? null : weeks[i].reduce((a, b) => a + b) / weeks[i].length],
              labels: [for (var i = 0; i < nWeeks; i++) '${i + 1}주'],
              color: yColor,
              height: 70,
            ),
          ),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          StatTile(value: '$planned일', label: '계획한 날'),
          StatTile(value: '$perfect일', label: 'Y-time 완벽', color: yColor),
          StatTile(value: '$best일', label: '최장 연속'),
          StatTile(value: '$memoCount', label: '메모'),
        ]),
      ]),
    );
  }
}
