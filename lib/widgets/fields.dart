import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// 입력하면 바로 저장되는 글 칸.
/// 다른 기기에서 바뀐 내용은 이 칸을 쓰고 있지 않을 때만 반영합니다.
class SaveField extends StatefulWidget {
  const SaveField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.label,
    this.maxLines = 1,
    this.style,
    this.dense = false,
    this.keyboardType,
    this.autofocus = false,
    this.onSubmitted,
    this.onFocusLost,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final String? hint;
  final String? label;
  final int? maxLines;
  final TextStyle? style;
  final bool dense;
  final TextInputType? keyboardType;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFocusLost;

  @override
  State<SaveField> createState() => _SaveFieldState();
}

class _SaveFieldState extends State<SaveField> {
  late final TextEditingController _c = TextEditingController(text: widget.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus) widget.onFocusLost?.call();
    });
  }

  @override
  void didUpdateWidget(SaveField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus && widget.value != _c.text) _c.text = widget.value;
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      focusNode: _focus,
      onChanged: widget.onChanged,
      onTapOutside: (_) => _focus.unfocus(),
      autofocus: widget.autofocus,
      onSubmitted: widget.onSubmitted,
      maxLines: widget.maxLines,
      minLines: 1,
      style: widget.style,
      keyboardType: widget.keyboardType ?? (widget.maxLines == 1 ? TextInputType.text : TextInputType.multiline),
      decoration: InputDecoration(
        hintText: widget.hint,
        labelText: widget.label,
        isDense: widget.dense,
        border: widget.dense ? InputBorder.none : const OutlineInputBorder(),
        contentPadding: widget.dense ? const EdgeInsets.symmetric(vertical: 8) : null,
      ),
    );
  }
}

/// 제목이 있는 카드 묶음
class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child, this.trailing, this.color});
  final String title;
  final Widget child;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (color != null) ...[
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// "HH:mm" 시간 고르기. 비어 있으면 null.
Future<String?> pickTime(BuildContext context, String? current, {bool allowClear = false}) async {
  final m = current == null ? null : RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(current);
  final init = m == null ? TimeOfDay.now() : TimeOfDay(hour: int.parse(m[1]!), minute: int.parse(m[2]!));
  final r = await showTimePicker(
    context: context,
    initialTime: init,
    initialEntryMode: TimePickerEntryMode.inputOnly,
    builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true), child: child!),
  );
  if (r == null) return current;
  return '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
}

/// 바깥을 누르면 키보드를 닫는 함수 (다른 입력창에서 씀)
void unfocusOutside(PointerDownEvent _) => FocusManager.instance.primaryFocus?.unfocus();

/// "언제 할까요?": 시작 시간과 걸리는 시간을 시/분 휠로 골라요. 지우기를 누르면 ('', '')를 돌려줘요.
Future<(String, String)?> pickRange(BuildContext context, {String? start, String? end, bool clearable = true}) {
  return showDialog<(String, String)>(
    context: context,
    builder: (_) => _RangeDialog(start: start, end: end, clearable: clearable),
  );
}

String hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

/// 처음 열 때 시작 시간: 다음 정각
int defaultStart() {
  final n = DateTime.now();
  return ((n.hour + 1) % 24) * 60;
}

/// 시작 시간(시·분)과 걸리는 시간(시간·분) 버튼 4개. 누르면 휠이 떠요.
class TimeSpanPicker extends StatelessWidget {
  const TimeSpanPicker({super.key, required this.start, required this.length, required this.onChanged});
  final int start; // 분 (0~1439)
  final int length; // 분
  final void Function(int start, int length) onChanged;

  static final _mins = [for (var m = 0; m < 60; m += 5) m];

  @override
  Widget build(BuildContext context) {
    final sh = start ~/ 60, sm = start % 60, lh = length ~/ 60, lm = length % 60;
    final end = start + length;
    final t = Theme.of(context);
    Widget btn(String label, String value, Future<void> Function() onTap) => Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: t.hintColor)),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('시작 시간', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            btn('시', '$sh시', () async {
              final v = await wheelPick(context, '시작 시', [for (var h = 0; h < 24; h++) h], sh, (h) => '$h시');
              if (v != null) onChanged(v * 60 + sm, length);
            }),
            const SizedBox(width: 8),
            btn('분', '$sm분', () async {
              final v = await wheelPick(context, '시작 분', {..._mins, sm}.toList()..sort(), sm, (m) => '$m분');
              if (v != null) onChanged(sh * 60 + v, length);
            }),
          ],
        ),
        const SizedBox(height: 14),
        const Text('걸리는 시간', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Row(
          children: [
            btn('시간', '$lh시간', () async {
              final v = await wheelPick(context, '걸리는 시간', [for (var h = 0; h <= 12; h++) h], lh, (h) => '$h시간');
              if (v != null) onChanged(start, v * 60 + lm);
            }),
            const SizedBox(width: 8),
            btn('분', '$lm분', () async {
              final v = await wheelPick(context, '걸리는 분', {..._mins, lm}.toList()..sort(), lm, (m) => '$m분');
              if (v != null) onChanged(start, lh * 60 + v);
            }),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          length <= 0
              ? '걸리는 시간을 골라주세요'
              : end > 24 * 60
              ? '자정을 넘길 수 없어요'
              : '${hm(start)} ~ ${hm(end)}',
          style: TextStyle(fontWeight: FontWeight.w700, color: length <= 0 || end > 24 * 60 ? Colors.red : t.colorScheme.primary),
        ),
      ],
    );
  }
}

/// 위아래로 굴려서 고르는 휠 (마우스로 끌거나 휠을 굴려도 돼요)
Future<int?> wheelPick(BuildContext context, String title, List<int> values, int current, String Function(int) label) {
  var idx = values.indexOf(current);
  if (idx < 0) idx = 0;
  final c = FixedExtentScrollController(initialItem: idx);
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            SizedBox(
              height: 200,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(ctx).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
                child: CupertinoPicker(
                  scrollController: c,
                  itemExtent: 40,
                  useMagnifier: true,
                  magnification: 1.15,
                  onSelectedItemChanged: (i) => idx = i,
                  children: [for (final v in values) Center(child: Text(label(v), style: const TextStyle(fontSize: 20)))],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(ctx, values[idx]), child: const Text('확인')),
            ),
          ],
        ),
      ),
    ),
  );
}

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({this.start, this.end, this.clearable = true});
  final bool clearable;
  final String? start;
  final String? end;
  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late int _start = parseHmLocal(widget.start) ?? defaultStart();
  late int _len = () {
    final a = parseHmLocal(widget.start), b = parseHmLocal(widget.end);
    return a == null || b == null || b <= a ? 60 : b - a;
  }();

  bool get _ok => _len > 0 && _start + _len <= 24 * 60;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('언제 할까요?'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TimeSpanPicker(
              start: _start,
              length: _len,
              onChanged: (s, l) => setState(() {
                _start = s;
                _len = l;
              }),
            ),
            const SizedBox(height: 4),
            Text('오늘 계획표에도 같이 표시돼요', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
          ],
        ),
      ),
      actions: [
        if (widget.start != null && widget.clearable) TextButton(onPressed: () => Navigator.pop(context, ('', '')), child: const Text('시간 지우기')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _ok ? () => Navigator.pop(context, (hm(_start), hm(_start + _len))) : null, child: const Text('확인')),
      ],
    );
  }
}

int? parseHmLocal(String? s) {
  final m = s == null ? null : RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(s);
  return m == null ? null : int.parse(m[1]!) * 60 + int.parse(m[2]!);
}
