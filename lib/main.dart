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
import 'views/katikati_grid_view.dart';
import 'views/queue_view.dart';
import 'views/settings_view.dart';
import 'views/simulator_view.dart';
import 'views/tasks_view.dart';
import 'widgets/dynamic_capsule.dart';
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
            title: 'Lema - Social Auto-Poster & AI Studio',
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _views = const [
    KatikatiGridView(),
    SimulatorView(),
    QueueView(),
    CalendarView(),
    AiStudioView(),
    HooksPipelineView(),
    TasksView(),
    SettingsView(),
  ];

  final List<String> _viewTitles = const [
    'Katikati Visual Grid',
    'Device Simulator',
    'Publishing Queue',
    'Content Calendar',
    'AI Studio & Planner',
    'Hooks & Scripts Pipeline',
    'Daily Operations Tick',
    'Daemon & Settings',
  ];

  // Short titles for the narrow mobile app bar (Slice 1: no truncation).
  final List<String> _viewShortTitles = const [
    'Katikati',
    'Simulator',
    'Queue',
    'Calendar',
    'AI Studio',
    'Hooks',
    'Daily Tick',
    'Settings',
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    final isMobile = screenWidth < 768;
    final isTablet = screenWidth >= 768 && screenWidth < 1100;

    // Desktop / Tablet Layout with Adaptive Sidebar
    if (!isMobile) {
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
                    isRail: isTablet,
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

    // Mobile Layout (< 768px) with Drawer & Top Capsule Bar
    return Scaffold(
      key: _scaffoldKey,
      drawer: Drawer(
        child: SafeArea(
          child: SidebarNavigation(
            selectedIndex: app.selectedNavIndex,
            onDestinationSelected: (index) {
              app.setNavIndex(index);
              Navigator.of(context).pop();
            },
            isRail: false,
          ),
        ),
      ),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF131317) : Colors.white,
            border: Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.black12)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(CupertinoIcons.bars, size: 22),
                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _viewShortTitles[app.selectedNavIndex],
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Compact capsule: dot + handle only, capped width so the
                  // title never truncates at 402pt (Slice 1).
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: const DynamicCapsule(compact: true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: _views[app.selectedNavIndex],
      bottomNavigationBar: CupertinoTabBar(
        currentIndex: app.selectedNavIndex < 5 ? app.selectedNavIndex : 0,
        activeColor: AppleTheme.systemBlue,
        onTap: (index) => app.setNavIndex(index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.square_grid_2x2_fill),
            label: 'Katikati',
          ),
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
        ],
      ),
    );
  }
}
