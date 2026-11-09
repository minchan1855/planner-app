import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../alarms.dart';
import '../store.dart';
import '../widgets/fields.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final s = store.settings;
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(
                  children: [
                    Card(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      child: ListTile(
                        leading: Icon(
                          store.user == null ? Icons.cloud_off : Icons.cloud_done,
                          color: store.user == null ? Colors.grey : Theme.of(context).colorScheme.primary,
                        ),
                        title: const Text('계정과 동기화', style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text(store.user == null ? '로그인하면 휴대폰과 컴퓨터 기록이 맞춰져요' : '${store.user!.email} 로 로그인됨'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('계정과 동기화')),
                              body: ListView(
                                children: [
                                  Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 640),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: ListenableBuilder(
                                          listenable: store,
                                          builder: (_, _) => _Account(store: store),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Section(
                      title: '알람',
                      child: Column(
                        children: [
                          if (!Alarms.supported) const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('알람은 휴대폰 앱에서 울려요. 여기서 맞춘 알람도 휴대폰에 그대로 반영돼요.')),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('알람 울리는 때'),
                            trailing: DropdownButton<int>(
                              value: s.leadMinutes,
                              items: [
                                for (final m in [0, 5, 10, 15, 30]) DropdownMenuItem(value: m, child: Text(m == 0 ? '정각' : '$m분 전')),
                              ],
                              onChanged: (v) => store.saveSettings(s..leadMinutes = v ?? 10),
                            ),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('일요일 밤 9시 주간 회고 알람'),
                            value: s.weeklyReviewAlarm,
                            onChanged: (v) => store.saveSettings(s..weeklyReviewAlarm = v),
                          ),
                        ],
                      ),
                    ),
                    Section(
                      title: '하루 계획표',
                      child: Column(
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('하루 시작 시간'),
                            subtitle: const Text('새로 만드는 날부터 적용돼요'),
                            trailing: DropdownButton<int>(
                              value: s.startHour,
                              items: [for (var h = 3; h <= 9; h++) DropdownMenuItem(value: h, child: Text('$h시'))],
                              onChanged: (v) => store.saveSettings(s..startHour = v ?? 5),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('하루 끝 시간'),
                            trailing: DropdownButton<int>(
                              value: s.endHour,
                              items: [
                                for (var h = 20; h <= 26; h++)
                                  DropdownMenuItem(
                                    value: h,
                                    child: Text(
                                      h == 24
                                          ? '자정'
                                          : h > 24
                                          ? '새벽 ${h - 24}시'
                                          : '$h시',
                                    ),
                                  ),
                              ],
                              onChanged: (v) => store.saveSettings(s..endHour = v ?? 24),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Section(
                      title: '카카오톡 알림',
                      child: _Kakao(store: store),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Account extends StatefulWidget {
  const _Account({required this.store});
  final Store store;
  @override
  State<_Account> createState() => _AccountState();
}

class _AccountState extends State<_Account> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  String? _msg;

  GoTrueClient get auth => Supabase.instance.client.auth;

  Future<void> _run(Future<void> Function() f) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      await f();
    } on AuthException catch (e) {
      _msg = _korean(e.message);
    } catch (e) {
      _msg = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  String _korean(String m) {
    if (m.contains('Invalid login')) return '이메일이나 비밀번호가 맞지 않아요.';
    if (m.contains('Email not confirmed')) return '이메일함에서 인증 메일의 링크를 먼저 눌러주세요.';
    if (m.contains('already registered')) return '이미 가입된 이메일이에요. 로그인을 눌러주세요.';
    if (m.contains('Password should be')) return '비밀번호는 6자 이상이어야 해요.';
    return m;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final user = store.user;
    if (user != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${user.email} 로 로그인됨'),
          const SizedBox(height: 4),
          Text(
            store.syncError ??
                (store.syncing
                    ? '맞추는 중…'
                    : store.lastSynced == null
                    ? '아직 동기화 전이에요'
                    : '마지막 동기화 ${DateFormat('HH:mm:ss').format(store.lastSynced!)}${store.pendingCount > 0 ? ' · 올릴 것 ${store.pendingCount}개' : ''}'),
            style: TextStyle(color: store.syncError != null ? Colors.red : Theme.of(context).hintColor, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilledButton.tonal(onPressed: store.syncing ? null : store.sync, child: const Text('지금 동기화')),
              TextButton(onPressed: () => auth.signOut(), child: const Text('로그아웃')),
            ],
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('휴대폰과 컴퓨터에서 같은 계정으로 로그인하면 기록이 똑같이 맞춰져요. 로그인 전 기록은 이 기기에만 있어요.'),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          onTapOutside: unfocusOutside,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: '이메일', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _pw,
          onTapOutside: unfocusOutside,
          obscureText: true,
          decoration: const InputDecoration(labelText: '비밀번호 (6자 이상)', border: OutlineInputBorder()),
        ),
        if (_msg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_msg!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: _busy ? null : () => _run(() => auth.signInWithPassword(email: _email.text.trim(), password: _pw.text)),
                child: const Text('로그인'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: _busy
                    ? null
                    : () => _run(() async {
                        final r = await auth.signUp(email: _email.text.trim(), password: _pw.text);
                        if (r.session == null) _msg = '가입 완료! 이메일함의 인증 링크를 누른 뒤 로그인해 주세요.';
                      }),
                child: const Text('처음이에요 (가입)'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// 카카오톡 "나에게 보내기" 연결
class _Kakao extends StatefulWidget {
  const _Kakao({required this.store});
  final Store store;
  @override
  State<_Kakao> createState() => _KakaoState();
}

class _KakaoState extends State<_Kakao> {
  bool? _ready;
  bool _connected = false;
  bool _busy = false;
  String? _msg;
  String? _userId;

  Future<Map<String, dynamic>> _call(String action) async {
    final r = await Supabase.instance.client.functions.invoke('kakao', body: {'action': action});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> _load() async {
    _userId = widget.store.user?.id;
    if (_userId == null) return;
    try {
      final r = await _call('status');
      if (!mounted) return;
      setState(() {
        _ready = r['ready'] == true;
        _connected = r['connected'] == true;
      });
    } catch (e) {
      if (mounted) setState(() => _msg = '카톡 연결 상태를 불러오지 못했어요');
    }
  }

  Future<void> _run(String action, {String? done}) async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    try {
      final r = await _call(action);
      if (action == 'start') {
        await launchUrl(Uri.parse(r['url']), mode: LaunchMode.externalApplication, webOnlyWindowName: '_self');
        if (!kIsWeb) _msg = '카카오 로그인을 마치고 앱으로 돌아와서 아래 "다시 확인"을 눌러주세요.';
      } else {
        _msg = done;
        if (action == 'disconnect') _connected = false;
      }
    } on FunctionException catch (e) {
      _msg = '실패했어요: ${e.details}';
    } catch (e) {
      _msg = '실패했어요: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final s = store.settings;
    if (store.user == null) return const Text('위의 "계정과 동기화"에서 먼저 로그인해 주세요.');
    if (store.user!.id != _userId) {
      _ready = null;
      _load();
    }
    final hint = Theme.of(context).hintColor;
    final children = <Widget>[];
    if (_ready == null && _msg == null) {
      children.add(const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator()));
    } else if (_ready == false) {
      children.add(const Text('카카오 개발자 앱 등록이 끝나면 여기서 연결할 수 있어요.'));
    } else if (_ready == true && !_connected) {
      children.addAll([
        const Text('카카오톡에 연결하면 알람 시간에 "나와의 채팅"으로 알려드려요. 앱이 꺼져 있어도, 컴퓨터에서 맞춘 알람도 와요.'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFFEE500), foregroundColor: Colors.black87),
              onPressed: _busy ? null : () => _run('start'),
              icon: const Icon(Icons.chat_bubble),
              label: const Text('카카오톡 연결하기'),
            ),
            if (!kIsWeb) TextButton(onPressed: _busy ? null : _load, child: const Text('다시 확인')),
          ],
        ),
      ]);
    } else if (_connected) {
      children.addAll([
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('카톡으로도 알림 받기'),
          subtitle: Text('할 일·계획의 알람과 주간 회고 알람을 카톡 나에게 보내기로 보내요', style: TextStyle(fontSize: 12, color: hint)),
          value: s.kakaoAlarm,
          onChanged: (v) => store.saveSettings(s..kakaoAlarm = v),
        ),
        Wrap(
          spacing: 8,
          children: [
            FilledButton.tonal(
              onPressed: _busy ? null : () => _run('test', done: '보냈어요. 카톡 "나와의 채팅"을 확인해 보세요.'),
              child: const Text('시험 메시지 보내기'),
            ),
            TextButton(
              onPressed: _busy ? null : () => _run('disconnect', done: '연결을 끊었어요.'),
              child: const Text('연결 끊기'),
            ),
          ],
        ),
      ]);
    }
    if (_msg != null)
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_msg!, style: TextStyle(fontSize: 13, color: hint)),
        ),
      );
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}
