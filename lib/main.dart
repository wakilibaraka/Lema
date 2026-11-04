import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/app_provider.dart';
import 'core/providers/auth_provider.dart';
import 'core/providers/media_provider.dart';
import 'core/providers/posts_provider.dart';
import 'core/providers/profile_provider.dart';
import 'core/services/demo_mode_service.dart';
import 'core/services/storage_service.dart';
import 'core/shell.dart';
import 'core/theme.dart';

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
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PostsProvider()),
        ChangeNotifierProvider(create: (_) => MediaProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, app, child) => MaterialApp(
          title: 'Lema',
          debugShowCheckedModeBanner: false,
          themeMode: app.themeMode,
          theme: LemaTheme.light,
          darkTheme: LemaTheme.dark,
          home: const MainLayoutScreen(),
        ),
      ),
    );
  }
}

/// Loads the state that lives behind services rather than providers, then
/// shows the shell.
class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  Timer? _daemonSync;

  @override
  void dispose() {
    _daemonSync?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _hydratePersistedState();
  }

  // Demo mode and platform tokens are saved by services, so without this
  // every launch would boot as if neither had ever been set.
  Future<void> _hydratePersistedState() async {
    await DemoModeService.load();
    if (!mounted) return;
    // After demo mode is known, so a demo session never reaches the daemon.
    final posts = context.read<PostsProvider>()..syncWithBackend();
    // Picks up what the daemon published while the app sits open.
    final auth = context.read<AuthProvider>();
    _daemonSync = Timer.periodic(const Duration(seconds: 30), (_) {
      posts.syncWithBackend();
      auth.loadTokens();
    });
    await auth.loadTokens();
  }

  @override
  Widget build(BuildContext context) => const LemaShell();
}
