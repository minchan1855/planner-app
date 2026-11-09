import 'package:flutter/material.dart';
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
    final body = SafeArea(child: IndexedStack(index: tab, children: pages));
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            labelType: NavigationRailLabelType.all,
            destinations: [for (final d in _dest) NavigationRailDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3))],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
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
