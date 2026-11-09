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
            Row(children: [
              if (color != null) ...[
                Container(width: 4, height: 18, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 8),
              ],
              Expanded(child: Text(title, style: t.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
              ?trailing,
            ]),
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

/// "몇 시부터 몇 시까지" 숫자로 적어서 고르기. 지우기를 누르면 ('', '')를 돌려줘요.
Future<(String, String)?> pickRange(BuildContext context, {String? start, String? end}) {
  return showDialog<(String, String)>(context: context, builder: (_) => _RangeDialog(start: start, end: end));
}

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({this.start, this.end});
  final String? start;
  final String? end;
  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  late final _a = TextEditingController(text: widget.start ?? '');
  late int _len = () {
    final a = widget.start, b = widget.end;
    if (a == null || b == null) return 60;
    return _mins(b) - _mins(a);
  }();
  String? _err;

  static const _lens = [15, 30, 45, 60, 90, 120, 150, 180, 240, 300];

  static int _mins(String s) => int.parse(s.substring(0, 2)) * 60 + int.parse(s.substring(3));

  /// "9", "930", "9:30", "0930" → "09:30"
  static String? norm(String s) {
    s = s.trim().replaceAll(RegExp(r'[^0-9:]'), '');
    if (s.isEmpty) return null;
    int h, m;
    if (s.contains(':')) {
      final p = s.split(':');
      h = int.tryParse(p[0]) ?? -1;
      m = int.tryParse(p.length > 1 && p[1].isNotEmpty ? p[1] : '0') ?? -1;
    } else if (s.length <= 2) {
      h = int.parse(s);
      m = 0;
    } else {
      h = int.parse(s.substring(0, s.length - 2));
      m = int.parse(s.substring(s.length - 2));
    }
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  static String _fmt(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  static String _lenText(int m) => m < 60 ? '$m분' : (m % 60 == 0 ? '${m ~/ 60}시간' : '${m ~/ 60}시간 ${m % 60}분');

  void _ok() {
    final a = norm(_a.text);
    if (a == null) return setState(() => _err = '시작 시간을 9:00 이나 0930 처럼 적어주세요');
    final end = _mins(a) + _len;
    if (end > 24 * 60) return setState(() => _err = '자정을 넘길 수 없어요');
    Navigator.pop(context, (a, _fmt(end)));
  }

  @override
  Widget build(BuildContext context) {
    final a = norm(_a.text);
    return AlertDialog(
      title: const Text('언제 할까요?'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: _a,
            autofocus: widget.start == null,
            keyboardType: TextInputType.datetime,
            onTapOutside: unfocusOutside,
            onChanged: (_) => setState(() => _err = null),
            decoration: const InputDecoration(labelText: '시작 시간', hintText: '예: 9:00 또는 0930', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          const Text('걸리는 시간'),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 6, children: [
            for (final l in {..._lens, _len}.toList()..sort())
              ChoiceChip(label: Text(_lenText(l)), selected: _len == l, onSelected: (_) => setState(() => _len = l)),
          ]),
          const SizedBox(height: 10),
          if (a != null) Text('$a ~ ${_fmt((_mins(a) + _len).clamp(0, 24 * 60))}', style: const TextStyle(fontWeight: FontWeight.w700)),
          if (_err != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_err!, style: const TextStyle(color: Colors.red))),
          const SizedBox(height: 4),
          Text('오늘 계획표에도 같이 표시돼요', style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
        ]),
      ),
      actions: [
        if (widget.start != null) TextButton(onPressed: () => Navigator.pop(context, ('', '')), child: const Text('시간 지우기')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        FilledButton(onPressed: _ok, child: const Text('확인')),
      ],
    );
  }
}
