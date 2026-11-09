
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../models.dart';
import '../store.dart';
import 'fields.dart';

const photoColor = Color(0xFF12A594);
const voiceColor = Color(0xFF8E4EC6);
const textColor = Color(0xFFE5A000);

Color memoColor(String kind) => switch (kind) { 'photo' => photoColor, 'voice' => voiceColor, _ => textColor };
IconData memoIcon(String kind) => switch (kind) { 'photo' => Icons.photo_camera, 'voice' => Icons.mic, _ => Icons.edit_note };

/// 사진·음성·글 메모를 추가하는 버튼 줄
class MemoButtons extends StatelessWidget {
  const MemoButtons({super.key, required this.store, required this.date});
  final Store store;
  final DateTime date;

  void _err(BuildContext context, Object e) {
    final msg = e is StateError ? e.message : '$e';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _photo(BuildContext context, ImageSource src) async {
    if (store.user == null) {
      return _err(context, StateError('사진 메모는 설정 탭에서 로그인한 뒤에 쓸 수 있어요.'));
    }
    final x = await ImagePicker().pickImage(source: src, maxWidth: 1600, maxHeight: 1600, imageQuality: 80);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final m = Memo(date: dateKey(date), kind: 'photo');
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(const SnackBar(content: Text('사진 올리는 중…'), duration: Duration(seconds: 30)));
    try {
      final ext = x.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
      m.photo = await store.uploadPhoto(m.id, bytes, ext);
      store.saveMemo(m);
      messenger.hideCurrentSnackBar();
    } catch (e) {
      messenger.hideCurrentSnackBar();
      if (context.mounted) _err(context, e);
    }
  }

  Future<void> _voice(BuildContext context) async {
    final text = await showDialog<String>(context: context, builder: (_) => const VoiceDialog());
    if (text == null || text.trim().isEmpty) return;
    store.saveMemo(Memo(date: dateKey(date), kind: 'voice', text: text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final camera = !kIsWeb;
    Widget btn(IconData icon, String label, Color c, VoidCallback onTap) => Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                side: BorderSide(color: c.withValues(alpha: .5)),
                foregroundColor: c,
              ),
              onPressed: onTap,
              child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon), const SizedBox(height: 4), Text(label, style: const TextStyle(fontSize: 12))]),
            ),
          ),
        );
    return Row(children: [
      if (camera) btn(Icons.photo_camera, '사진 찍기', photoColor, () => _photo(context, ImageSource.camera)),
      btn(Icons.photo_library, camera ? '앨범' : '사진 올리기', photoColor, () => _photo(context, ImageSource.gallery)),
      btn(Icons.mic, '말로 메모', voiceColor, () => _voice(context)),
      btn(Icons.edit_note, '글 메모', textColor, () => store.saveMemo(Memo(date: dateKey(date), kind: 'text'))),
    ]);
  }
}

/// 말하면 글자로 바꿔주는 창
class VoiceDialog extends StatefulWidget {
  const VoiceDialog({super.key});
  @override
  State<VoiceDialog> createState() => _VoiceDialogState();
}

class _VoiceDialogState extends State<VoiceDialog> {
  static final _stt = SpeechToText();
  String _done = ''; // 앞에서 확정된 문장들
  String _now = ''; // 지금 듣고 있는 문장
  String? _error;
  bool _listening = false;
  double _level = 0;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final ok = await _stt.initialize(
        onError: (e) => setState(() {
          if (e.errorMsg != 'error_no_match' && e.errorMsg != 'error_speech_timeout') _error = '음성 인식 오류: ${e.errorMsg}';
          _listening = false;
        }),
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') setState(() => _listening = false);
        },
      );
      if (!ok) {
        setState(() => _error = '마이크를 쓸 수 없어요. 마이크 권한을 허용했는지 확인해 주세요.');
        return;
      }
      if (_now.isNotEmpty) {
        _done = '$_done $_now'.trim();
        _now = '';
      }
      setState(() {
        _listening = true;
        _error = null;
      });
      await _stt.listen(
        onResult: (r) => setState(() => _now = r.recognizedWords),
        onSoundLevelChange: (l) => setState(() => _level = l),
        listenOptions: SpeechListenOptions(
          localeId: 'ko_KR',
          partialResults: true,
          listenMode: ListenMode.dictation,
          pauseFor: const Duration(seconds: 5),
          listenFor: const Duration(minutes: 5),
          autoPunctuation: true,
        ),
      );
    } catch (e) {
      setState(() => _error = '음성 인식을 시작하지 못했어요: $e');
    }
  }

  String get _text => '$_done $_now'.trim();

  @override
  void dispose() {
    _stt.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(children: [
        Icon(Icons.mic, color: _listening ? voiceColor : Colors.grey),
        const SizedBox(width: 8),
        Text(_listening ? '듣고 있어요…' : '말로 메모'),
      ]),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (_listening)
            LinearProgressIndicator(value: ((_level + 2) / 12).clamp(0.05, 1.0), color: voiceColor, backgroundColor: voiceColor.withValues(alpha: .12)),
          const SizedBox(height: 12),
          Container(
            constraints: const BoxConstraints(minHeight: 100),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: voiceColor.withValues(alpha: .06), borderRadius: BorderRadius.circular(12)),
            child: Text(_text.isEmpty ? '말씀하시면 여기에 글자로 나타나요' : _text,
                style: TextStyle(fontSize: 16, color: _text.isEmpty ? Theme.of(context).hintColor : null)),
          ),
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.red))),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        if (!_listening) TextButton(onPressed: _start, child: const Text('이어서 말하기')),
        if (_listening) TextButton(onPressed: () => _stt.stop(), child: const Text('멈추기')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: voiceColor),
          onPressed: _text.isEmpty
              ? null
              : () async {
                  await _stt.stop();
                  if (context.mounted) Navigator.pop(context, _text);
                },
          child: const Text('저장'),
        ),
      ],
    );
  }
}

/// 메모 하나를 보여주는 카드
class MemoCard extends StatelessWidget {
  const MemoCard({super.key, required this.store, required this.memo, this.showDate = false, this.onOpenDay});
  final Store store;
  final Memo memo;
  final bool showDate;
  final VoidCallback? onOpenDay;

  @override
  Widget build(BuildContext context) {
    final c = memoColor(memo.kind);
    final hint = Theme.of(context).hintColor;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: .35)),
        borderRadius: BorderRadius.circular(12),
        color: c.withValues(alpha: .04),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (memo.photo != null) MemoPhoto(store: store, path: memo.photo!),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(children: [
            Icon(memoIcon(memo.kind), size: 18, color: c),
            const SizedBox(width: 8),
            Expanded(
              child: SaveField(
                key: ValueKey('memo-${memo.id}'),
                value: memo.text,
                dense: true,
                maxLines: null,
                autofocus: memo.kind == 'text' && memo.text.isEmpty && DateTime.now().difference(memo.createdAt).inSeconds < 3,
                hint: memo.kind == 'photo' ? '사진 설명 (선택)' : '메모',
                onChanged: (v) {
                  memo.text = v;
                  store.saveMemo(memo);
                },
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 18, color: hint),
              onSelected: (v) async {
                if (v == 'day') onOpenDay?.call();
                if (v == 'del') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      title: const Text('이 메모를 지울까요?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                        TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('지우기', style: TextStyle(color: Colors.red))),
                      ],
                    ),
                  );
                  if (ok == true) store.deleteMemo(memo);
                }
              },
              itemBuilder: (_) => [
                if (onOpenDay != null) const PopupMenuItem(value: 'day', child: Text('그날 계획표 보기')),
                const PopupMenuItem(value: 'del', child: Text('지우기')),
              ],
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(38, 0, 12, 8),
          child: Text(
            showDate ? DateFormat('M월 d일 (E) HH:mm', 'ko').format(memo.createdAt) : DateFormat('HH:mm').format(memo.createdAt),
            style: TextStyle(fontSize: 11, color: hint),
          ),
        ),
      ]),
    );
  }
}

class MemoPhoto extends StatelessWidget {
  const MemoPhoto({super.key, required this.store, required this.path, this.height = 220, this.fit = BoxFit.cover});
  final Store store;
  final String path;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: store.photo(path),
      builder: (context, snap) {
        final b = snap.data;
        if (b == null) {
          return Container(
            height: height,
            color: photoColor.withValues(alpha: .08),
            child: Center(
              child: snap.connectionState == ConnectionState.done
                  ? const Text('사진을 불러오지 못했어요 (로그인 확인)')
                  : const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return GestureDetector(
          onTap: () => showDialog(
            context: context,
            builder: (c) => Dialog(
              insetPadding: const EdgeInsets.all(12),
              child: GestureDetector(onTap: () => Navigator.pop(c), child: InteractiveViewer(child: Image.memory(b))),
            ),
          ),
          child: SizedBox(height: height, child: Image.memory(b, fit: fit, gaplessPlayback: true)),
        );
      },
    );
  }
}
