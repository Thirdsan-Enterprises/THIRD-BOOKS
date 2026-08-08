import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/services/theme_service.dart';
import 'core/services/server_sync_service.dart';
import 'core/services/data_service.dart' show databaseProvider;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Intercept the window close button so we can attempt one last backup
  // push before the app actually exits — otherwise a short session (open,
  // enter a few entries, close) can end before the login-time push or the
  // periodic timer ever gets a chance to run, and that session's data is
  // never backed up.
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);

  runApp(
    const ProviderScope(
      child: ThirdBooksApp(),
    ),
  );
}

class ThirdBooksApp extends ConsumerStatefulWidget {
  const ThirdBooksApp({super.key});

  @override
  ConsumerState<ThirdBooksApp> createState() => _ThirdBooksAppState();
}

class _ThirdBooksAppState extends ConsumerState<ThirdBooksApp> with WindowListener {
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    if (_closing) return;
    _closing = true;
    // Bounded attempt — never let a slow/unreachable server block the app
    // from closing. Worst case the user waits a few seconds longer.
    try {
      // Reuse the app's shared database connection rather than opening a
      // fresh, never-closed one — see sync_status_provider.dart for why.
      await ServerSyncService.pushBackup(ref.read(databaseProvider))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Ignored — the periodic/login pushes will catch it next time.
    } finally {
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'MagicBet Accounting',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
