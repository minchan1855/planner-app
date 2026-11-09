import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../widgets/fields.dart';
import '../widgets/memo.dart';

/// 메모를 달력으로 보고, 날짜를 누르면 그날 메모를 보여주는 화면
class MemosScreen extends StatefulWidget {
  const MemosScreen({super.key, required this.store, required this.openDay});
  final Store store;
  final void Function(DateTime d) openDay;

  @override
  State<MemosScreen> createState() => _MemosScreenState();
}

class _MemosScreenState extends State<MemosScreen> {
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selected = dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) => ListenableBuilder(listenable: widget.store, builder: (context, _) => _build(context));

  Widget _build(BuildContext context) {
    final store = widget.store;
    final all = store.memos();
    final byDate = <String, List<Memo>>{};
    for (final m in all) {
      byDate.putIfAbsent(m.date, () => []).add(m);
    }
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final hint = Theme.of(context).hintColor;
    final monthCount = all.where((m) => m.date.startsWith(monthKey(month))).length;

    final calendar = Section(
      title: '${month.year}년 ${month.month}월 메모',
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)), icon: const Icon(Icons.chevron_left)),
        IconButton(visualDensity: VisualDensity.compact, onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)), icon: const Icon(Icons.chevron_right)),
      ]),
      child: Column(children: [
        _MemoCalendar(month: month, selected: selected, byDate: byDate, onTap: (d) => setState(() => selected = d)),
        const SizedBox(height: 8),
        Row(children: [
          for (final k in ['photo', 'voice', 'text']) ...[
            Container(width: 8, height: 8, decoration: BoxDecoration(color: memoColor(k), shape: BoxShape.circle)),
            Text(' ${switch (k) { 'photo' => '사진', 'voice' => '음성', _ => '글' }}   ', style: TextStyle(fontSize: 12, color: hint)),
          ],
          const Spacer(),
          Text('이번 달 $monthCount개', style: TextStyle(fontSize: 12, color: hint)),
        ]),
      ]),
    );

    final dayMemos = (byDate[dateKey(selected)] ?? []).reversed.toList();
    final dayList = Section(
      title: DateFormat('M월 d일 (E)', 'ko').format(selected),
      color: voiceColor,
      trailing: TextButton.icon(
        onPressed: () => widget.openDay(selected),
        icon: const Icon(Icons.chevron_right, size: 18),
        label: const Text('그날 계획표'),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        MemoButtons(store: store, date: selected),
        const SizedBox(height: 8),
        if (dayMemos.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: Center(child: Text('이 날은 메모가 없어요', style: TextStyle(color: hint)))),
        for (final m in dayMemos) MemoCard(key: ValueKey(m.id), store: store, memo: m),
      ]),
    );

    if (wide) {
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: calendar), Expanded(child: dayList)]),
          ),
        ),
      );
    }
    return ListView(padding: const EdgeInsets.symmetric(vertical: 8), children: [calendar, dayList]);
  }
}

class _MemoCalendar extends StatelessWidget {
  const _MemoCalendar({required this.month, required this.selected, required this.byDate, required this.onTap});
  final DateTime month;
  final DateTime selected;
  final Map<String, List<Memo>> byDate;
  final void Function(DateTime) onTap;

  @override
  Widget build(BuildContext context) {
    final start = mondayOf(DateTime(month.year, month.month, 1));
    final last = DateTime(month.year, month.month + 1, 0);
    final weeks = ((last.difference(start).inDays + 1) / 7).ceil();
    final today = dateKey(DateTime.now());
    final primary = Theme.of(context).colorScheme.primary;
    return Column(children: [
      Row(children: [for (final d in ['월', '화', '수', '목', '금', '토', '일']) Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 12))))]),
      const SizedBox(height: 4),
      for (var w = 0; w < weeks; w++)
        Row(children: [
          for (var i = 0; i < 7; i++)
            Builder(builder: (context) {
              final d = start.add(Duration(days: w * 7 + i));
              final k = dateKey(d);
              final memos = byDate[k] ?? const <Memo>[];
              final inMonth = d.month == month.month;
              final isSel = k == dateKey(selected);
              final kinds = {for (final m in memos) m.kind}.toList();
              return Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => onTap(d),
                  child: Container(
                    height: 52,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: isSel ? primary.withValues(alpha: .15) : (memos.isNotEmpty ? voiceColor.withValues(alpha: .05) : null),
                      border: k == today ? Border.all(color: primary, width: 1.5) : null,
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${d.day}',
                          style: TextStyle(
                            fontWeight: isSel ? FontWeight.w800 : null,
                            color: inMonth ? (i >= 5 ? Colors.red.shade300 : null) : Colors.grey.shade400,
                          )),
                      const SizedBox(height: 4),
                      SizedBox(
                        height: 8,
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          for (final kd in kinds)
                            Container(width: 6, height: 6, margin: const EdgeInsets.symmetric(horizontal: 1), decoration: BoxDecoration(color: memoColor(kd), shape: BoxShape.circle)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            }),
        ]),
    ]);
  }
}
