import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'store.dart';

/// 휴대폰(안드로이드) 알람. 웹(컴퓨터)에서는 아무것도 하지 않습니다.
class Alarms {
  Alarms(this.store);
  final Store store;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static const _channel = AndroidNotificationDetails(
    'plan_alarm',
    '계획 알람',
    channelDescription: '계획한 시간에 울리는 알람',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    fullScreenIntent: true,
    playSound: true,
    enableVibration: true,
  );

  Future<void> init() async {
    if (!supported) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    }
    await _plugin.initialize(settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
    _ready = true;
    store.onDocChanged((key) {
      if (key.startsWith('day:') || key == AppSettings.key) rescheduleAll();
    });
    await rescheduleAll();
  }

  /// 오늘부터 14일 동안의 알람을 모두 다시 맞춥니다.
  Future<void> rescheduleAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
    final s = store.settings;
    final now = tz.TZDateTime.now(tz.local);
    final today = dateOnly(DateTime.now());
    var id = 1;
    Future<void> add(DateTime when, String title, String body) async {
      final t = tz.TZDateTime.from(when, tz.local);
      if (t.isBefore(now)) return;
      await _plugin.zonedSchedule(
        id: id++,
        title: title,
        body: body,
        scheduledDate: t,
        notificationDetails: const NotificationDetails(android: _channel),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }

    final lead = Duration(minutes: s.leadMinutes);
    final leadText = s.leadMinutes == 0 ? '지금' : '${s.leadMinutes}분 뒤';
    for (var i = 0; i < 14; i++) {
      final d = today.add(Duration(days: i));
      if (!store.hasDay(d)) continue;
      final p = store.day(d);
      for (final t in p.tasks) {
        final m = parseHm(t.alarm);
        if (m == null || t.done || t.title.trim().isEmpty) continue;
        final at = d.add(Duration(minutes: m));
        await add(at.subtract(lead), t.type == 'Y' ? '꼭 할 일 · $leadText' : '여유 있게 할 일 · $leadText', t.title);
      }
    }
    if (s.weeklyReviewAlarm) {
      final sunday = mondayOf(today).add(const Duration(days: 6, hours: 21));
      await add(sunday, '주간 회고 쓸 시간이에요', '이번 주 잘한 점, 아쉬운 점, 다음 주 다짐을 적어보세요');
      await add(sunday.add(const Duration(days: 7)), '주간 회고 쓸 시간이에요', '이번 주 잘한 점, 아쉬운 점, 다음 주 다짐을 적어보세요');
    }
  }
}
