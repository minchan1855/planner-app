import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models.dart';
import '../store.dart';
import '../widgets/memo.dart';

/// 모든 메모를 날짜별로 모아 보는 화면
class MemosScreen extends StatefulWidget {
  const MemosScreen({super.key, required this.store, required this.openDay});
  final Store store;
  final void Function(DateTime d) openDay;

  @override
  State<MemosScreen> createState() => _MemosScreenState();
}

class _MemosScreenState extends State<MemosScreen> {
  String _kind = 'all';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(listenable: widget.store, builder: (context, _) => _build(context));
  }

  Widget _build(BuildContext context) {
    final store = widget.store;
    final all = store.memos();
    final list = all.where((m) => (_kind == 'all' || m.kind == _kind) && (_query.isEmpty || m.text.contains(_query))).toList();
    final byDate = <String, List<Memo>>{};
    for (final m in list) {
      byDate.putIfAbsent(m.date, () => []).add(m);
    }
    final count = {for (final k in ['photo', 'voice', 'text']) k: all.where((m) => m.kind == k).length};
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final hint = Theme.of(context).hintColor;

    Widget chip(String k, String label, IconData? icon, Color? c) => Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            avatar: icon == null ? null : Icon(icon, size: 16, color: c),
            label: Text(label),
            selected: _kind == k,
            onSelected: (_) => setState(() => _kind = k),
          ),
        );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: CustomScrollView(slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('메모 모아보기', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                // 종류별 개수 막대
                if (all.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: SizedBox(
                      height: 12,
                      child: Row(children: [
                        for (final k in ['photo', 'voice', 'text'])
                          if (count[k]! > 0) Expanded(flex: count[k]!, child: Container(color: memoColor(k))),
                      ]),
                    ),
                  ),
                const SizedBox(height: 10),
                TextField(
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  onChanged: (v) => setState(() => _query = v.trim()),
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: '메모 검색', border: OutlineInputBorder(), isDense: true),
                ),
                const SizedBox(height: 10),
                Wrap(runSpacing: 6, children: [
                    chip('all', '전체 ${all.length}', null, null),
                    chip('photo', '사진 ${count['photo']}', Icons.photo_camera, photoColor),
                    chip('voice', '음성 ${count['voice']}', Icons.mic, voiceColor),
                    chip('text', '글 ${count['text']}', Icons.edit_note, textColor),
                ]),
              ]),
            ),
          ),
          if (list.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text(all.isEmpty ? '아직 메모가 없어요.\n오늘 화면 맨 아래에서 사진이나 음성으로 남겨보세요.' : '조건에 맞는 메모가 없어요.',
                    textAlign: TextAlign.center, style: TextStyle(color: hint)),
              ),
            ),
          for (final e in byDate.entries) ...[
            SliverToBoxAdapter(
              child: InkWell(
                onTap: () => widget.openDay(DateTime.parse(e.key)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Row(children: [
                    Text(DateFormat('M월 d일 (E)', 'ko').format(DateTime.parse(e.key)), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(width: 8),
                    Text('${e.value.length}개', style: TextStyle(color: hint)),
                    const Spacer(),
                    Text('그날 계획표', style: TextStyle(color: hint, fontSize: 12)),
                    Icon(Icons.chevron_right, size: 18, color: hint),
                  ]),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              sliver: wide
                  ? SliverGrid(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 380, mainAxisExtent: 330, crossAxisSpacing: 10),
                      delegate: SliverChildListDelegate([
                        for (final m in e.value)
                          SingleChildScrollView(
                            physics: const NeverScrollableScrollPhysics(),
                            child: MemoCard(key: ValueKey(m.id), store: store, memo: m, showDate: true, onOpenDay: () => widget.openDay(DateTime.parse(m.date))),
                          ),
                      ]),
                    )
                  : SliverList(
                      delegate: SliverChildListDelegate([
                        for (final m in e.value)
                          MemoCard(key: ValueKey(m.id), store: store, memo: m, showDate: true, onOpenDay: () => widget.openDay(DateTime.parse(m.date))),
                      ]),
                    ),
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ]),
      ),
    );
  }
}
