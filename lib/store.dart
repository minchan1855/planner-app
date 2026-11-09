import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

/// 모든 기록을 "문서(key → JSON)"로 저장합니다.
/// 휴대폰/브라우저에 먼저 저장하고, 로그인되어 있으면 Supabase와 맞춥니다.
/// 같은 문서를 두 곳에서 고치면 나중에 고친 쪽이 남습니다.
class Store extends ChangeNotifier with WidgetsBindingObserver {
  Store._(this._prefs);

  static const _docPrefix = 'doc:';
  static const _pendingKey = 'sync:pending';
  static const _lastPullKey = 'sync:lastPull';

  final SharedPreferences _prefs;
  final Map<String, Map<String, dynamic>> _docs = {};
  final Set<String> _pending = {};
  Timer? _pushTimer;
  Timer? _pollTimer;
  bool _syncing = false;
  String? syncError;
  DateTime? lastSynced;

  /// 문서가 바뀔 때마다(알람 다시 맞추기 등) 부르는 함수
  final List<void Function(String key)> _listeners = [];
  void onDocChanged(void Function(String key) f) => _listeners.add(f);

  static Future<Store> open() async {
    final prefs = await SharedPreferences.getInstance();
    final s = Store._(prefs);
    for (final k in prefs.getKeys()) {
      if (k.startsWith(_docPrefix)) {
        try {
          s._docs[k.substring(_docPrefix.length)] = Map<String, dynamic>.from(jsonDecode(prefs.getString(k)!));
        } catch (_) {}
      }
    }
    s._pending.addAll(prefs.getStringList(_pendingKey) ?? []);
    WidgetsBinding.instance.addObserver(s);
    s._auth.onAuthStateChange.listen((e) {
      if (e.event == AuthChangeEvent.signedIn) {
        // 처음 로그인하면 이 기기에 있던 기록도 서버에 올립니다.
        s._pending.addAll(s._docs.keys);
        s._savePending();
      }
      if (e.event == AuthChangeEvent.signedOut) {
        s._prefs.remove(_lastPullKey);
      }
      s.notifyListeners();
      s.sync();
    });
    s._pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => s.sync());
    unawaited(s.sync());
    return s;
  }

  GoTrueClient get _auth => Supabase.instance.client.auth;
  User? get user => _auth.currentUser;
  bool get syncing => _syncing;
  int get pendingCount => _pending.length;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync();
  }

  Map<String, dynamic>? raw(String key) => _docs[key];
  Iterable<String> keysWithPrefix(String prefix) => _docs.keys.where((k) => k.startsWith(prefix));

  void put(String key, Map<String, dynamic> data) {
    data['_updated'] = DateTime.now().toUtc().toIso8601String();
    _docs[key] = data;
    _prefs.setString('$_docPrefix$key', jsonEncode(data));
    _pending.add(key);
    _savePending();
    for (final f in _listeners) {
      f(key);
    }
    notifyListeners();
    _pushTimer?.cancel();
    _pushTimer = Timer(const Duration(seconds: 2), sync);
  }

  void _savePending() => _prefs.setStringList(_pendingKey, _pending.toList());

  // ── 편의 함수 ──
  AppSettings get settings => _docs[AppSettings.key] == null ? AppSettings() : AppSettings.fromJson(_docs[AppSettings.key]!);
  void saveSettings(AppSettings s) => put(AppSettings.key, s.toJson());

  DayPlan day(DateTime d) {
    final j = _docs[DayPlan.keyFor(d)];
    if (j != null) return DayPlan.fromJson(j);
    final s = settings;
    return DayPlan.empty(d, startHour: s.startHour, endHour: s.endHour);
  }

  bool hasDay(DateTime d) => _docs.containsKey(DayPlan.keyFor(d));
  void saveDay(DayPlan p) => put(p.key, p.toJson());

  WeekPlan week(DateTime monday) {
    final j = _docs[WeekPlan.keyFor(monday)];
    if (j != null) return WeekPlan.fromJson(j);
    // 지난주 습관과 주간 고정할 일을 이어받습니다.
    final prevJ = _docs[WeekPlan.keyFor(monday.subtract(const Duration(days: 7)))];
    final prev = prevJ == null ? null : WeekPlan.fromJson(prevJ);
    return WeekPlan(
      start: dateKey(monday),
      habits: prev?.habits.map((h) => Habit(name: h.name)).toList(),
      fixed: prev?.fixed.toList(),
    );
  }

  void saveWeek(WeekPlan p) => put(p.key, p.toJson());

  MonthPlan month(DateTime d) {
    final j = _docs[MonthPlan.keyFor(d)];
    return j != null ? MonthPlan.fromJson(j) : MonthPlan(month: monthKey(d));
  }

  void saveMonth(MonthPlan p) => put(p.key, p.toJson());

  // ── 메모 ──
  List<Memo> memos({String? date}) {
    final out = <Memo>[];
    for (final e in _docs.entries) {
      if (!e.key.startsWith('memo:') || e.value['_deleted'] == true) continue;
      final m = Memo.fromJson(e.value);
      if (date == null || m.date == date) out.add(m);
    }
    out.sort((a, b) => b.created.compareTo(a.created));
    return out;
  }

  void saveMemo(Memo m) => put(m.key, m.toJson());

  Future<void> deleteMemo(Memo m) async {
    put(m.key, {...m.toJson(), '_deleted': true});
    if (m.photo != null && user != null) {
      try {
        await Supabase.instance.client.storage.from('memos').remove([m.photo!]);
      } catch (_) {}
    }
  }

  /// 사진을 올리고 저장소 경로를 돌려줍니다. 로그인이 필요해요.
  Future<String> uploadPhoto(String memoId, Uint8List bytes, String ext) async {
    final u = user;
    if (u == null) throw StateError('사진 메모는 설정 탭에서 로그인한 뒤에 쓸 수 있어요.');
    final path = '${u.id}/$memoId.$ext';
    await Supabase.instance.client.storage.from('memos').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: ext == 'png' ? 'image/png' : 'image/jpeg', upsert: true),
        );
    _photoCache[path] = bytes;
    return path;
  }

  final Map<String, Uint8List> _photoCache = {};
  final Map<String, Future<Uint8List?>> _photoLoading = {};

  /// 저장된 사진을 불러옵니다(한 번 받은 사진은 기억해 둡니다).
  Future<Uint8List?> photo(String path) {
    final c = _photoCache[path];
    if (c != null) return Future.value(c);
    return _photoLoading[path] ??= () async {
      try {
        final b = await Supabase.instance.client.storage.from('memos').download(path);
        _photoCache[path] = b;
        return b;
      } catch (_) {
        _photoLoading.remove(path);
        return null;
      }
    }();
  }

  // ── 동기화 ──
  Future<void> sync() async {
    if (_syncing || user == null) return;
    _syncing = true;
    notifyListeners();
    final db = Supabase.instance.client.from('docs');
    try {
      // 1) 올리기
      final keys = _pending.toList();
      if (keys.isNotEmpty) {
        final rows = [
          for (final k in keys)
            if (_docs[k] != null) {'key': k, 'data': _docs[k]}
        ];
        if (rows.isNotEmpty) await db.upsert(rows, onConflict: 'user_id,key');
        _pending.removeAll(keys);
        _savePending();
      }
      // 2) 내려받기 (지난번 이후 바뀐 것만)
      final since = _prefs.getString(_lastPullKey) ?? '1970-01-01T00:00:00Z';
      final List rows = await db.select('key,data,updated_at').gt('updated_at', since).order('updated_at');
      var newest = since;
      final changed = <String>[];
      for (final r in rows) {
        final k = r['key'] as String;
        final remote = Map<String, dynamic>.from(r['data']);
        final remoteAt = r['updated_at'] as String;
        if (remoteAt.compareTo(newest) > 0) newest = remoteAt;
        final local = _docs[k];
        final localAt = local?['_updated'] as String?;
        final remoteStamp = (remote['_updated'] as String?) ?? remoteAt;
        if (local == null || localAt == null || DateTime.parse(remoteStamp).isAfter(DateTime.parse(localAt))) {
          if (_pending.contains(k)) continue; // 이 기기에서 방금 고친 내용이 우선
          _docs[k] = remote;
          _prefs.setString('$_docPrefix$k', jsonEncode(remote));
          changed.add(k);
        }
      }
      _prefs.setString(_lastPullKey, newest);
      for (final k in changed) {
        for (final f in _listeners) {
          f(k);
        }
      }
      syncError = null;
      lastSynced = DateTime.now();
    } catch (e) {
      syncError = '동기화 실패: $e';
      debugPrint(syncError);
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pushTimer?.cancel();
    _pollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
