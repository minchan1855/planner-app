import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();
String newId() => _uuid.v4();

String dateKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime mondayOf(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));

/// 그 주가 몇 주차인지: 주의 목요일이 속한 달을 기준으로 셉니다.
({DateTime month, int week}) weekOfMonth(DateTime monday) {
  final thu = monday.add(const Duration(days: 3));
  final firstMonday = mondayOf(DateTime(thu.year, thu.month, 1));
  final firstThu = firstMonday.add(const Duration(days: 3));
  final base = firstThu.month == thu.month ? firstMonday : firstMonday.add(const Duration(days: 7));
  return (month: DateTime(thu.year, thu.month), week: monday.difference(base).inDays ~/ 7 + 1);
}

/// "HH:mm" → 분
int? parseHm(String? s) {
  if (s == null || !RegExp(r'^\d{1,2}:\d{2}$').hasMatch(s)) return null;
  final p = s.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

String fmtMinutes(int m) {
  final sign = m < 0 ? '-' : '';
  m = m.abs();
  final h = m ~/ 60, r = m % 60;
  if (h == 0) return '$sign$r분';
  return r == 0 ? '$sign$h시간' : '$sign$h시간 $r분';
}

List<String> _strList(dynamic v) => (v as List?)?.map((e) => e.toString()).toList() ?? [];

// ───────────────── 일일 계획 ─────────────────

class PlanTask {
  String id;
  String type; // 'Y' 반드시 해야 할 일, 'B' 여유있게 할 일
  int priority;
  String title;
  int minutes;
  bool done;
  String? alarm; // "HH:mm"

  PlanTask({String? id, required this.type, this.priority = 1, this.title = '', this.minutes = 30, this.done = false, this.alarm})
      : id = id ?? newId();

  factory PlanTask.fromJson(Map<String, dynamic> j) => PlanTask(
        id: j['id'],
        type: j['type'] ?? 'Y',
        priority: j['priority'] ?? 1,
        title: j['title'] ?? '',
        minutes: j['minutes'] ?? 30,
        done: j['done'] ?? false,
        alarm: j['alarm'],
      );
  Map<String, dynamic> toJson() =>
      {'id': id, 'type': type, 'priority': priority, 'title': title, 'minutes': minutes, 'done': done, 'alarm': alarm};
}

class HourSlot {
  int hour;
  String plan;
  String actual;
  String rating; // '', 'O', '△', 'X'
  String review;
  bool alarm;

  HourSlot({required this.hour, this.plan = '', this.actual = '', this.rating = '', this.review = '', this.alarm = false});

  factory HourSlot.fromJson(Map<String, dynamic> j) => HourSlot(
        hour: j['hour'],
        plan: j['plan'] ?? '',
        actual: j['actual'] ?? '',
        rating: j['rating'] ?? '',
        review: j['review'] ?? '',
        alarm: j['alarm'] ?? false,
      );
  Map<String, dynamic> toJson() =>
      {'hour': hour, 'plan': plan, 'actual': actual, 'rating': rating, 'review': review, 'alarm': alarm};
}

class DayPlan {
  final String date; // yyyy-MM-dd
  String affirmation;
  String wake;
  String sleep;
  List<PlanTask> tasks;
  List<HourSlot> slots;

  DayPlan({required this.date, this.affirmation = '', this.wake = '06:00', this.sleep = '23:00', List<PlanTask>? tasks, List<HourSlot>? slots})
      : tasks = tasks ?? [],
        slots = slots ?? [];

  static String keyFor(DateTime d) => 'day:${dateKey(d)}';
  String get key => 'day:$date';
  DateTime get day => DateTime.parse(date);

  factory DayPlan.empty(DateTime d, {int startHour = 5, int endHour = 24}) => DayPlan(
        date: dateKey(d),
        slots: [for (var h = startHour; h < endHour; h++) HourSlot(hour: h)],
      );

  factory DayPlan.fromJson(Map<String, dynamic> j) => DayPlan(
        date: j['date'],
        affirmation: j['affirmation'] ?? '',
        wake: j['wake'] ?? '06:00',
        sleep: j['sleep'] ?? '23:00',
        tasks: ((j['tasks'] as List?) ?? []).map((e) => PlanTask.fromJson(Map<String, dynamic>.from(e))).toList(),
        slots: ((j['slots'] as List?) ?? []).map((e) => HourSlot.fromJson(Map<String, dynamic>.from(e))).toList(),
      );
  Map<String, dynamic> toJson() => {
        'date': date,
        'affirmation': affirmation,
        'wake': wake,
        'sleep': sleep,
        'tasks': tasks.map((t) => t.toJson()).toList(),
        'slots': slots.map((s) => s.toJson()).toList(),
      };

  List<PlanTask> tasksOf(String type) => tasks.where((t) => t.type == type).toList()..sort((a, b) => a.priority.compareTo(b.priority));

  int get activeMinutes {
    final w = parseHm(wake), s = parseHm(sleep);
    if (w == null || s == null) return 0;
    var d = s - w;
    if (d < 0) d += 24 * 60;
    return d;
  }

  int minutesOf(String type) => tasks.where((t) => t.type == type).fold(0, (a, t) => a + t.minutes);

  /// Y-time 완료율 (0~1). 할 일이 없으면 null.
  double? get yDoneRate {
    final ys = tasksOf('Y');
    if (ys.isEmpty) return null;
    return ys.where((t) => t.done).length / ys.length;
  }
}

// ───────────────── 주간 계획 ─────────────────

class Habit {
  String id;
  String name;
  List<bool> checks; // 월~일 7칸
  Habit({String? id, this.name = '', List<bool>? checks})
      : id = id ?? newId(),
        checks = checks ?? List.filled(7, false);
  factory Habit.fromJson(Map<String, dynamic> j) => Habit(
        id: j['id'],
        name: j['name'] ?? '',
        checks: ((j['checks'] as List?) ?? List.filled(7, false)).map((e) => e == true).toList(),
      );
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'checks': checks};
}

class WeekPlan {
  final String start; // 월요일 yyyy-MM-dd
  String affirmation;
  List<String> goals;
  List<String> fixed; // 주간 고정할 일 (오늘 화면에 보여요)
  List<Habit> habits;
  String good;
  String bad;
  String next;

  WeekPlan({required this.start, this.affirmation = '', List<String>? goals, List<String>? fixed, List<Habit>? habits, this.good = '', this.bad = '', this.next = ''})
      : goals = goals ?? [],
        fixed = fixed ?? [],
        habits = habits ?? [];

  static String keyFor(DateTime monday) => 'week:${dateKey(monday)}';
  String get key => 'week:$start';

  factory WeekPlan.fromJson(Map<String, dynamic> j) => WeekPlan(
        start: j['start'],
        affirmation: j['affirmation'] ?? '',
        goals: _strList(j['goals']),
        fixed: _strList(j['fixed']),
        habits: ((j['habits'] as List?) ?? []).map((e) => Habit.fromJson(Map<String, dynamic>.from(e))).toList(),
        good: j['good'] ?? '',
        bad: j['bad'] ?? '',
        next: j['next'] ?? '',
      );
  Map<String, dynamic> toJson() => {
        'start': start,
        'affirmation': affirmation,
        'goals': goals,
        'fixed': fixed,
        'habits': habits.map((h) => h.toJson()).toList(),
        'good': good,
        'bad': bad,
        'next': next,
      };
}

// ───────────────── 월간 계획 ─────────────────

class MonthGoal {
  String text;
  String reward;
  MonthGoal({this.text = '', this.reward = ''});
  factory MonthGoal.fromJson(Map<String, dynamic> j) => MonthGoal(text: j['text'] ?? '', reward: j['reward'] ?? '');
  Map<String, dynamic> toJson() => {'text': text, 'reward': reward};
}

class MonthPlan {
  final String month; // yyyy-MM
  String affirmation;
  List<MonthGoal> goals; // 3개
  List<String> fixed; // 고정된 일
  List<List<String>> weeks; // 1~5주차 할 일

  MonthPlan({required this.month, this.affirmation = '', List<MonthGoal>? goals, List<String>? fixed, List<List<String>>? weeks})
      : goals = goals ?? List.generate(3, (_) => MonthGoal()),
        fixed = fixed ?? [],
        weeks = weeks ?? List.generate(5, (_) => <String>[]);

  static String keyFor(DateTime d) => 'month:${monthKey(d)}';
  String get key => 'month:$month';

  factory MonthPlan.fromJson(Map<String, dynamic> j) {
    final weeks = ((j['weeks'] as List?) ?? []).map((w) => _strList(w)).toList();
    while (weeks.length < 5) {
      weeks.add([]);
    }
    final goals = ((j['goals'] as List?) ?? []).map((e) => MonthGoal.fromJson(Map<String, dynamic>.from(e))).toList();
    while (goals.length < 3) {
      goals.add(MonthGoal());
    }
    return MonthPlan(month: j['month'], affirmation: j['affirmation'] ?? '', goals: goals, fixed: _strList(j['fixed']), weeks: weeks);
  }
  Map<String, dynamic> toJson() => {
        'month': month,
        'affirmation': affirmation,
        'goals': goals.map((g) => g.toJson()).toList(),
        'fixed': fixed,
        'weeks': weeks,
      };
}

// ───────────────── 메모 ─────────────────

class Memo {
  final String id;
  final String date; // yyyy-MM-dd (어느 날의 메모인지)
  String kind; // 'photo' | 'voice' | 'text'
  String text;
  String? photo; // Supabase 저장소 경로
  final String created; // ISO 시각

  Memo({String? id, required this.date, required this.kind, this.text = '', this.photo, String? created})
      : id = id ?? newId(),
        created = created ?? DateTime.now().toIso8601String();

  String get key => 'memo:$id';
  DateTime get createdAt => DateTime.tryParse(created) ?? DateTime.parse(date);

  factory Memo.fromJson(Map<String, dynamic> j) =>
      Memo(id: j['id'], date: j['date'], kind: j['kind'] ?? 'text', text: j['text'] ?? '', photo: j['photo'], created: j['created']);
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'kind': kind, 'text': text, 'photo': photo, 'created': created};
}

// ───────────────── 설정 ─────────────────

class AppSettings {
  int startHour;
  int endHour;
  int leadMinutes; // 알람을 몇 분 전에 울릴지
  bool weeklyReviewAlarm; // 일요일 21시 주간 회고 알람

  AppSettings({this.startHour = 5, this.endHour = 24, this.leadMinutes = 10, this.weeklyReviewAlarm = true});
  static const key = 'settings';
  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        startHour: j['startHour'] ?? 5,
        endHour: j['endHour'] ?? 24,
        leadMinutes: j['leadMinutes'] ?? 10,
        weeklyReviewAlarm: j['weeklyReviewAlarm'] ?? true,
      );
  Map<String, dynamic> toJson() =>
      {'startHour': startHour, 'endHour': endHour, 'leadMinutes': leadMinutes, 'weeklyReviewAlarm': weeklyReviewAlarm};
}
