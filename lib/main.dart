import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'alarms.dart';
import 'config.dart';
import 'models.dart';
import 'screens/memos.dart';
import 'screens/month.dart';
import 'screens/settings.dart';
import 'screens/today.dart';
import 'screens/week.dart';
import 'store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  await Supabase.initialize(url: supabaseUrl, publishableKey: supabaseAnonKey);
  final store = await Store.open();
  final alarms = Alarms(store);
  runApp(PlannerApp(store: store));
  await alarms.init();
}

class PlannerApp extends StatelessWidget {
  const PlannerApp({super.key, required this.store});
  final Store store;

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E63DD), brightness: b),
      useMaterial3: true,
      cardTheme: const CardThemeData(elevation: 0),
    );
    return MaterialApp(
      title: '계획표',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: HomeShell(store: store),
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final Store store;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int tab = 0;
  final selectedDay = ValueNotifier(dateOnly(DateTime.now()));

  @override
  void initState() {
    super.initState();
    // 카카오 연결을 마치고 웹으로 돌아왔을 때 (주소 끝 ?kakao=ok)
    final k = Uri.base.queryParameters['kakao'];
    if (k != null) {
      tab = 4;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        const words = {'ok': '카카오톡이 연결됐어요! 카톡 "나와의 채팅"에 확인 메시지를 보냈어요.', 'denied': '카카오톡 연결을 취소했어요.', 'expired': '연결 시간이 지났어요. 다시 눌러주세요.'};
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(words[k] ?? '카카오톡 연결에 실패했어요. 다시 시도해 주세요.'), duration: const Duration(seconds: 6)));
      });
    }
  }

  void openDay(DateTime d) {
    selectedDay.value = dateOnly(d);
    setState(() => tab = 0);
  }

  static const _dest = [
    (Icons.today_outlined, Icons.today, '오늘'),
    (Icons.view_week_outlined, Icons.view_week, '주간'),
    (Icons.calendar_month_outlined, Icons.calendar_month, '월간'),
    (Icons.photo_library_outlined, Icons.photo_library, '메모'),
    (Icons.settings_outlined, Icons.settings, '설정'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(store: widget.store, selected: selectedDay),
      WeekScreen(store: widget.store, openDay: openDay),
      MonthScreen(store: widget.store, openDay: openDay),
      MemosScreen(store: widget.store, openDay: openDay),
      SettingsScreen(store: widget.store),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 900;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        // 뒤로가기: 입력 중이면 입력창만 닫고, 다른 탭이면 오늘로, 오늘이면 앱을 닫아요.
        final focus = FocusManager.instance.primaryFocus;
        if (focus != null && focus.context?.findAncestorStateOfType<EditableTextState>() != null) {
          focus.unfocus();
        } else if (tab != 0) {
          setState(() => tab = 0);
        } else {
          SystemNavigator.pop();
        }
      },
      child: _scaffold(context, pages, wide),
    );
  }

  Widget _scaffold(BuildContext context, List<Widget> pages, bool wide) {
    final body = SafeArea(
      child: IndexedStack(index: tab, children: pages),
    );
    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: tab,
              onDestinationSelected: (i) => setState(() => tab = i),
              labelType: NavigationRailLabelType.all,
              destinations: [for (final d in _dest) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: [for (final d in _dest) NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3)],
      ),
    );
  }
}
