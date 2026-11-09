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
  final r = await showTimePicker(context: context, initialTime: init);
  if (r == null) return current;
  return '${r.hour.toString().padLeft(2, '0')}:${r.minute.toString().padLeft(2, '0')}';
}

/// 바깥을 누르면 키보드를 닫는 함수 (다른 입력창에서 씀)
void unfocusOutside(PointerDownEvent _) => FocusManager.instance.primaryFocus?.unfocus();
