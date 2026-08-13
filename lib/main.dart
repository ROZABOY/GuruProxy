import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app_state.dart';
import 'services/asset_bootstrap.dart';
import 'services/guru_tray.dart';
import 'services/settings_store.dart';
import 'services/tunnel_engine.dart';
import 'theme/guru_theme.dart';
import 'ui/shell.dart';

GuruTray? _tray;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final desktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  if (desktop) {
    await windowManager.ensureInitialized();
    const opts = WindowOptions(
      size: Size(900, 580),
      minimumSize: Size(720, 480),
      center: true,
      backgroundColor: Colors.transparent,
      title: 'GuruProxy v2.2',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.setPreventClose(true);
    await windowManager.waitUntilReadyToShow(opts, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  final settings = await SettingsStore.load();
  try {
    final csv = await rootBundle.loadString('assets/presets/known_working_cf.csv');
    await settings.ensureV22CloudflarePreset(csv);
  } catch (_) {}

  final bootstrap = AssetBootstrap();
  await bootstrap.ensureReady();
  final tunnel = TunnelEngine(settings: settings, bootstrap: bootstrap);

  if (desktop && defaultTargetPlatform == TargetPlatform.windows) {
    _tray = GuruTray(tunnel);
    await _tray!.init();
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState(settings: settings, tunnel: tunnel)),
      ],
      child: const GuruProxyApp(),
    ),
  );
}

class GuruProxyApp extends StatelessWidget {
  const GuruProxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isFa = state.locale.languageCode == 'fa';
    return MaterialApp(
      title: 'GuruProxy v2.2',
      debugShowCheckedModeBanner: false,
      locale: state.locale,
      theme: GuruTheme.light,
      darkTheme: GuruTheme.dark,
      themeMode: ThemeMode.dark,
      builder: (context, child) {
        return Directionality(
          textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const AppShell(),
    );
  }
}
