import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/posts_provider.dart';
import 'providers/profile_provider.dart';
import 'services/storage_service.dart';
import 'theme/apple_theme.dart';
import 'views/ai_studio_view.dart';
import 'views/calendar_view.dart';
import 'views/hooks_pipeline_view.dart';
import 'views/queue_view.dart';
import 'views/settings_view.dart';
import 'views/simulator_view.dart';
import 'views/tasks_view.dart';
import 'widgets/sidebar_navigation.dart';
import 'widgets/window_title_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  runApp(const LemaApp());
}

class LemaApp extends StatelessWidget {
  const LemaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, app, child) {
          return MaterialApp(
            title: 'Lema - Social Auto-Poster',
            debugShowCheckedModeBanner: false,
            themeMode: app.themeMode,
            theme: AppleTheme.lightTheme,
            darkTheme: AppleTheme.darkTheme,
            home: const MainLayoutScreen(),
          );
        },
      ),
    );
  }
}

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  final List<Widget> _views = const [
    SimulatorView(),
    QueueView(),
    CalendarView(),
    AiStudioView(),
    HooksPipelineView(),
    TasksView(),
    SettingsView(),
  ];

  final List<String> _viewTitles = const [
    'Device Simulator',
    'Publishing Queue',
    'Content Calendar',
    'AI Studio & Planner',
    'Hooks & Scripts Pipeline',
    'Daily Operations Tick',
    'Daemon & Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      return Scaffold(
        body: Column(
          children: [
            WindowTitleBar(
              title: _viewTitles[app.selectedNavIndex],
            ),
            Expanded(
              child: Row(
                children: [
                  SidebarNavigation(
                    selectedIndex: app.selectedNavIndex,
                    onDestinationSelected: (index) => app.setNavIndex(index),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _views[app.selectedNavIndex],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Mobile / Compact Layout
    return Scaffold(
      body: SafeArea(
        child: _views[app.selectedNavIndex],
      ),
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: app.selectedNavIndex < 5 ? app.selectedNavIndex : 0,
        activeColor: AppleTheme.systemBlue,
        onTap: (index) => app.setNavIndex(index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.device_phone_portrait),
            label: 'Simulator',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.layers_alt),
            label: 'Queue',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.calendar),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.sparkles),
            label: 'AI Studio',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.film),
            label: 'Hooks',
          ),
        ],
      ),
    );
  }
}
