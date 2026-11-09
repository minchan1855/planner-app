import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import 'fields.dart';

const ratingColors = {'O': Color(0xFF30A46C), '△': Color(0xFFF5A623), 'X': Color(0xFFE5484D)};
const ratingWords = {'O': '잘했어요', '△': '조금 했어요', 'X': '못 했어요'};

/// 시간표 블록 색 (이름마다 정해진 색)
const _palette = [
  Color(0xFFF2C46D), // 노랑
  Color(0xFF7FA8E8), // 파랑
  Color(0xFFF0877A), // 빨강
  Color(0xFFA6C96A), // 연두
  Color(0xFFA48BE0), // 보라
  Color(0xFFF7A35C), // 주황
  Color(0xFF6CCFC0), // 민트
  Color(0xFFE88BB8), // 분홍
];
Color blockColor(String key) => _palette[key.codeUnits.fold(0, (a, c) => (a * 31 + c) & 0x7fffffff) % _palette.length];

class _Block {
  _Block({required this.start, required this.end, required this.title, required this.color, this.task, this.slotHours = const [], this.rating = '', this.sub});
  final int start; // 분
  final int end;
  final String title;
  final Color color;
  final PlanTask? task;
  final List<int> slotHours; // 할 일이 아닌 칸 글이면 그 시간들
  final String rating;
  final String? sub;
  int lane = 0;
  int lanes = 1;
}

/// 하루 시간표: 할 일(시간 범위)과 시간 칸에 적은 글을 블록으로 보여줘요.
class DayTimetable extends StatelessWidget {
  const DayTimetable({super.key, required this.plan, required this.edit, this.hourHeight = 54});
  final DayPlan plan;
  final void Function(void Function(DayPlan)) edit;
  final double hourHeight;

  int get firstHour => plan.slots.isEmpty ? 5 : plan.slots.first.hour;
  int get lastHour => plan.slots.isEmpty ? 24 : plan.slots.last.hour + 1;

  List<_Block> _blocks() {
    final out = <_Block>[];
    for (final t in plan.tasks) {
      final a = parseHm(t.start), b = parseHm(t.end);
      if (t.title.trim().isEmpty || a == null || b == null || b <= a) continue;
      out.add(
        _Block(
          start: math.max(a, firstHour * 60),
          end: math.min(b, lastHour * 60),
          title: t.title,
          color: blockColor(t.title),
          task: t,
          rating: t.rating,
          sub: t.rangeText,
        ),
      );
    }
    // 같은 글이 이어지는 시간 칸은 한 블록으로 합쳐요.
    final slots = plan.slots;
    for (var i = 0; i < slots.length; i++) {
      final text = slots[i].plan.trim();
      if (text.isEmpty) continue;
      var j = i;
      while (j + 1 < slots.length && slots[j + 1].plan.trim() == text && slots[j + 1].hour == slots[j].hour + 1) {
        j++;
      }
      out.add(
        _Block(
          start: slots[i].hour * 60,
          end: (slots[j].hour + 1) * 60,
          title: text,
          color: blockColor(text),
          slotHours: [for (var k = i; k <= j; k++) slots[k].hour],
          rating: slots[i].rating,
          sub: slots[i].actual.isEmpty ? null : '실제: ${slots[i].actual}',
        ),
      );
      i = j;
    }
    // 겹치는 블록은 옆으로 나란히 놓아요.
    out.sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.end.compareTo(a.end));
    final groups = <List<_Block>>[];
    var groupEnd = -1;
    for (final bl in out) {
      if (bl.start >= groupEnd) groups.add([]);
      groups.last.add(bl);
      groupEnd = math.max(groupEnd, bl.end);
    }
    for (final g in groups) {
      final laneEnds = <int>[];
      for (final bl in g) {
        var lane = laneEnds.indexWhere((e) => e <= bl.start);
        if (lane < 0) {
          lane = laneEnds.length;
          laneEnds.add(bl.end);
        } else {
          laneEnds[lane] = bl.end;
        }
        bl.lane = lane;
      }
      for (final bl in g) {
        bl.lanes = laneEnds.length;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = _blocks();
    final hours = lastHour - firstHour;
    final height = hours * hourHeight;
    final grid = Theme.of(context).dividerColor;
    final hint = Theme.of(context).hintColor;
    const axis = 26.0;
    final now = DateTime.now();
    final isToday = plan.date == dateKey(now);
    final nowMin = now.hour * 60 + now.minute;

    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth - axis;
        double y(int min) => (min - firstHour * 60) / 60 * hourHeight;
        return SizedBox(
          height: height + 8,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (var h = 0; h <= hours; h++) ...[
                Positioned(
                  left: axis,
                  right: 0,
                  top: h * hourHeight,
                  child: IgnorePointer(child: Container(height: 1, color: grid)),
                ),
                if (h < hours)
                  Positioned(
                    left: 0,
                    width: axis - 4,
                    top: h * hourHeight + 2,
                    child: Text(
                      '${firstHour + h}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: isToday && now.hour == firstHour + h ? Theme.of(context).colorScheme.primary : hint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
              for (final bl in blocks)
                Positioned(
                  left: axis + 2 + w * bl.lane / bl.lanes,
                  width: w / bl.lanes - 4,
                  top: y(bl.start) + 1,
                  height: math.max(20, y(bl.end) - y(bl.start) - 2),
                  child: _BlockView(
                    block: bl,
                    height: y(bl.end) - y(bl.start) - 2,
                    onTap: () => bl.task != null ? _openTask(context, bl.task!) : _openSlot(context, bl.slotHours),
                  ),
                ),
              if (isToday && nowMin >= firstHour * 60 && nowMin <= lastHour * 60)
                Positioned(
                  left: axis - 4,
                  right: 0,
                  top: y(nowMin) - 4,
                  child: IgnorePointer(
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        ),
                        Expanded(child: Container(height: 1.5, color: Colors.red)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openTask(BuildContext context, PlanTask t) async {
    await showDialog(
      context: context,
      builder: (_) => _TaskDialog(task: t, edit: edit),
    );
  }

  /// ＋ 버튼: 시작 시간과 걸리는 시간을 골라 계획표에 적어요.
  Future<void> openAdd(BuildContext context) async {
    final r = await showDialog<(String, int, int)>(
      context: context,
      builder: (_) => _AddDialog(first: firstHour, last: lastHour),
    );
    if (r == null) return;
    edit((p) {
      for (final s in p.slots) {
        if (s.hour >= r.$2 && s.hour < r.$2 + r.$3) s.plan = r.$1;
      }
    });
  }

  Future<void> _openSlot(BuildContext context, List<int> hours) async {
    final first = plan.slots.firstWhere((s) => s.hour == hours.first, orElse: () => HourSlot(hour: hours.first));
    final r = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => _SlotDialog(hours: hours, slot: first),
    );
    if (r == null) return;
    edit((p) {
      for (final s in p.slots) {
        if (hours.contains(s.hour)) {
          s.plan = r.$1;
          s.actual = r.$2;
          s.rating = r.$3;
        }
      }
    });
  }
}

class _BlockView extends StatelessWidget {
  const _BlockView({required this.block, required this.height, required this.onTap});
  final _Block block;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = block.task;
    final done = t?.done ?? false;
    final rc = ratingColors[block.rating];
    return Material(
      color: done ? Color.lerp(block.color, Colors.white, .45) : block.color,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(6, height < 40 ? 1 : 3, 4, height < 40 ? 1 : 3),
          child: Stack(
            children: [
              if (height < 40)
                // 짧은 블록(30분 등)은 한 줄로: 제목 + 시간
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 40),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: block.title,
                            style: TextStyle(fontWeight: FontWeight.w700, decoration: done ? TextDecoration.lineThrough : null, decorationColor: Colors.white),
                          ),
                          if (block.sub != null) TextSpan(text: '  ${block.sub}', style: const TextStyle(fontSize: 10.5)),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: height < 24 ? 11 : 12.5, height: 1.1),
                    ),
                  ),
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      block.title,
                      maxLines: math.max(1, ((height - (block.sub == null ? 6 : 20)) / 16).floor()),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        height: 1.2,
                        decoration: done ? TextDecoration.lineThrough : null,
                        decorationColor: Colors.white,
                      ),
                    ),
                    if (block.sub != null)
                      Text(
                        block.sub!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                  ],
                ),
              Positioned(
                right: 0,
                top: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (t?.alarm != null) const Icon(Icons.alarm_on, size: 14, color: Colors.white),
                    if (rc != null)
                      Container(
                        margin: const EdgeInsets.only(left: 2),
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: rc, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            block.rating,
                            style: TextStyle(color: rc, fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget ratingPicker(String value, ValueChanged<String> onPick) {
  return Wrap(
    spacing: 8,
    children: [
      for (final r in ['O', '△', 'X'])
        ChoiceChip(
          avatar: CircleAvatar(
            backgroundColor: ratingColors[r],
            child: Text(
              r,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
            ),
          ),
          label: Text(ratingWords[r]!),
          selected: value == r,
          onSelected: (on) => onPick(on ? r : ''),
        ),
    ],
  );
}

class _TaskDialog extends StatefulWidget {
  const _TaskDialog({required this.task, required this.edit});
  final PlanTask task;
  final void Function(void Function(DayPlan)) edit;
  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  late PlanTask t = widget.task;
  void _set(void Function(PlanTask t) f) {
    setState(() => f(t));
    widget.edit((p) => f(p.tasks.firstWhere((x) => x.id == t.id)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${t.type == 'Y' ? '반드시 해야 할 일' : '여유 있게 할 일'} · ${t.rangeText ?? ''}', style: TextStyle(color: Theme.of(context).hintColor)),
          const SizedBox(height: 12),
          CheckboxListTile(contentPadding: EdgeInsets.zero, value: t.done, title: const Text('끝냈어요'), onChanged: (v) => _set((x) => x.done = v ?? false)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: t.alarm != null,
            title: Text(t.alarm == null ? '알람' : '알람 ${t.alarm}'),
            onChanged: (on) => _set((x) => x.alarm = on ? x.start : null),
          ),
          const Text('평가'),
          const SizedBox(height: 6),
          ratingPicker(t.rating, (r) => _set((x) => x.rating = r)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final r = await pickRange(context, start: t.start, end: t.end);
            if (r == null) return;
            _set((x) {
              if (r.$1.isEmpty) {
                x.start = null;
                x.end = null;
              } else {
                if (x.alarm != null) x.alarm = r.$1;
                x.start = r.$1;
                x.end = r.$2;
                x.minutes = parseHm(r.$2)! - parseHm(r.$1)!;
              }
            });
            if (r.$1.isEmpty && context.mounted) Navigator.pop(context);
          },
          child: const Text('시간 바꾸기'),
        ),
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
      ],
    );
  }
}

class _SlotDialog extends StatefulWidget {
  const _SlotDialog({required this.hours, required this.slot});
  final List<int> hours;
  final HourSlot slot;
  @override
  State<_SlotDialog> createState() => _SlotDialogState();
}

class _SlotDialogState extends State<_SlotDialog> {
  late final _plan = TextEditingController(text: widget.slot.plan);
  late final _actual = TextEditingController(text: widget.slot.actual);
  late String _rating = widget.slot.rating;

  @override
  Widget build(BuildContext context) {
    final h = widget.hours;
    return AlertDialog(
      title: Text(h.length == 1 ? '${h.first}시~${h.first + 1}시' : '${h.first}시~${h.last + 1}시'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _plan,
              autofocus: widget.slot.plan.isEmpty,
              onTapOutside: unfocusOutside,
              decoration: const InputDecoration(labelText: '해야 할 일', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _actual,
              onTapOutside: unfocusOutside,
              decoration: const InputDecoration(labelText: '실제 한 일 (선택)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            const Text('평가'),
            const SizedBox(height: 6),
            ratingPicker(_rating, (r) => setState(() => _rating = r)),
          ],
        ),
      ),
      actions: [
        if (widget.slot.plan.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, ('', '', '')),
            child: const Text('지우기', style: TextStyle(color: Colors.red)),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(context, (_plan.text.trim(), _actual.text.trim(), _rating)), child: const Text('저장')),
      ],
    );
  }
}

class _AddDialog extends StatefulWidget {
  const _AddDialog({required this.first, required this.last});
  final int first;
  final int last;
  @override
  State<_AddDialog> createState() => _AddDialogState();
}

class _AddDialogState extends State<_AddDialog> {
  final _text = TextEditingController();
  late int _start = DateTime.now().hour.clamp(widget.first, widget.last - 1) + (DateTime.now().hour + 1 < widget.last ? 1 : 0);
  int _len = 1;

  @override
  Widget build(BuildContext context) {
    final maxLen = widget.last - _start;
    return AlertDialog(
      title: const Text('계획 추가'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _text,
              autofocus: true,
              onTapOutside: unfocusOutside,
              decoration: const InputDecoration(labelText: '해야 할 일', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Text('시작  '),
                DropdownButton<int>(
                  value: _start,
                  items: [for (var h = widget.first; h < widget.last; h++) DropdownMenuItem(value: h, child: Text('$h시'))],
                  onChanged: (v) => setState(() {
                    _start = v ?? _start;
                    if (_len > widget.last - _start) _len = widget.last - _start;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('걸리는 시간'),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final l in [1, 2, 3, 4, 5, 6])
                  if (l <= maxLen) ChoiceChip(label: Text('$l시간'), selected: _len == l, onSelected: (_) => setState(() => _len = l)),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(
          onPressed: () {
            if (_text.text.trim().isEmpty) return;
            Navigator.pop(context, (_text.text.trim(), _start, _len));
          },
          child: const Text('추가'),
        ),
      ],
    );
  }
}
