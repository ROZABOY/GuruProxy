import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/strings.dart';
import '../theme/guru_theme.dart';
import 'pages/about_page.dart';
import 'pages/apps_page.dart';
import 'pages/connect_page.dart';
import 'pages/help_page.dart';
import 'pages/log_page.dart';
import 'pages/settings_page.dart';
import 'pages/white_ip_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  bool get _mobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.locale.languageCode == 'fa');
    final isFa = state.locale.languageCode == 'fa';

    if (_mobile) {
      return Scaffold(
        backgroundColor: GuruTheme.ink,
        appBar: AppBar(
          backgroundColor: GuruTheme.tealDeep,
          foregroundColor: const Color(0xFFF4F1EA),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 12,
          title: InkWell(
            onTap: () => state.go(AppSection.connect),
            child: Row(
              children: [
                Image.asset(
                  'assets/brand/app-icon.png',
                  width: 28,
                  height: 28,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.shield_outlined, size: 24, color: GuruTheme.sand),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    s.appName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 0.3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: state.toggleLanguage,
              child: Text(s.langToggle, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (v) {
                switch (v) {
                  case 'help':
                    state.go(AppSection.help);
                  case 'about':
                    state.go(AppSection.about);
                  case 'start':
                    state.go(AppSection.connect);
                    state.tunnel.start();
                  case 'stop':
                    state.tunnel.stop();
                  case 'iran':
                    state.settings.applyIranQuickConnect();
                    state.go(AppSection.connect);
                    state.tunnel.start();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'start', enabled: !state.tunnel.isActive, child: Text(s.startConn)),
                PopupMenuItem(value: 'stop', enabled: state.tunnel.isActive, child: Text(s.stopConn)),
                PopupMenuItem(value: 'iran', child: Text(s.iranQuick)),
                const PopupMenuDivider(),
                PopupMenuItem(value: 'help', child: Text(s.menuHelp)),
                PopupMenuItem(value: 'about', child: Text(s.menuAbout)),
              ],
            ),
          ],
        ),
        body: ColoredBox(
          color: GuruTheme.ink,
          child: _page(state),
        ),
        bottomNavigationBar: NavigationBar(
          height: 64,
          backgroundColor: GuruTheme.tealDeep,
          indicatorColor: GuruTheme.sand.withValues(alpha: 0.22),
          selectedIndex: _navIndex(state.section),
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            state.go(switch (i) {
              1 => AppSection.whiteIp,
              2 => AppSection.apps,
              3 => AppSection.settings,
              4 => AppSection.log,
              _ => AppSection.connect,
            });
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.shield_outlined),
              selectedIcon: const Icon(Icons.shield),
              label: isFa ? 'اتصال' : 'Connect',
            ),
            NavigationDestination(
              icon: const Icon(Icons.travel_explore_outlined),
              selectedIcon: const Icon(Icons.travel_explore),
              label: 'White IP',
            ),
            NavigationDestination(
              icon: const Icon(Icons.apps_outlined),
              selectedIcon: const Icon(Icons.apps),
              label: s.menuApps,
            ),
            NavigationDestination(
              icon: const Icon(Icons.tune_outlined),
              selectedIcon: const Icon(Icons.tune),
              label: isFa ? 'تنظیمات' : 'Settings',
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: isFa ? 'لاگ' : 'Log',
            ),
          ],
        ),
      );
    }

    // Desktop / wide: classic menu bar, still SafeArea for any inset displays.
    return Scaffold(
      backgroundColor: GuruTheme.ink,
      body: SafeArea(
        child: Column(
          children: [
            _DesktopTopBar(s: s, state: state),
            Expanded(
              child: ColoredBox(
                color: GuruTheme.ink,
                child: _page(state),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _navIndex(AppSection section) => switch (section) {
        AppSection.whiteIp => 1,
        AppSection.apps => 2,
        AppSection.settings => 3,
        AppSection.log => 4,
        AppSection.help || AppSection.about || AppSection.connect => 0,
      };

  Widget _page(AppState state) => switch (state.section) {
        AppSection.connect => const ConnectPage(),
        AppSection.whiteIp => const WhiteIpPage(),
        AppSection.apps => const AppsPage(),
        AppSection.settings => const SettingsPage(),
        AppSection.log => const LogPage(),
        AppSection.help => const HelpPage(),
        AppSection.about => const AboutPage(),
      };
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({required this.s, required this.state});
  final S s;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final active = state.tunnel.isActive;
    return Material(
      color: GuruTheme.tealDeep,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 40,
            child: Row(
              children: [
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => state.go(AppSection.connect),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/brand/app-icon.png',
                          width: 20,
                          height: 20,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.shield_outlined, size: 18, color: GuruTheme.sand),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s.appName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.6,
                            fontSize: 13,
                            color: Color(0xFFF4F1EA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MenuBar(
                    style: MenuStyle(
                      backgroundColor: WidgetStateProperty.all(GuruTheme.tealDeep),
                      elevation: WidgetStateProperty.all(0),
                      padding: WidgetStateProperty.all(EdgeInsets.zero),
                    ),
                    children: [
                      SubmenuButton(
                        menuChildren: [
                          MenuItemButton(
                            onPressed: active
                                ? null
                                : () {
                                    state.go(AppSection.connect);
                                    state.tunnel.start();
                                  },
                            child: Text(s.startConn),
                          ),
                          MenuItemButton(
                            onPressed: active ? () => state.tunnel.stop() : null,
                            child: Text(s.stopConn),
                          ),
                          const Divider(),
                          MenuItemButton(
                            onPressed: () {
                              state.settings.applyIranQuickConnect();
                              state.go(AppSection.connect);
                              state.tunnel.start();
                            },
                            child: Text(s.iranQuick),
                          ),
                        ],
                        child: Text(s.menuSession, style: _menuStyle),
                      ),
                      SubmenuButton(
                        menuChildren: [
                          MenuItemButton(
                            onPressed: () => state.go(AppSection.connect),
                            child: Text(s.openConnect),
                          ),
                          MenuItemButton(
                            onPressed: () => state.go(AppSection.whiteIp),
                            child: Text(s.menuWhiteIp),
                          ),
                          MenuItemButton(
                            onPressed: () => state.go(AppSection.apps),
                            child: Text(s.menuApps),
                          ),
                          MenuItemButton(
                            onPressed: () => state.go(AppSection.log),
                            child: Text(s.menuLog),
                          ),
                          MenuItemButton(
                            onPressed: () => state.go(AppSection.settings),
                            child: Text(s.menuSettings),
                          ),
                        ],
                        child: Text(s.menuTools, style: _menuStyle),
                      ),
                      SubmenuButton(
                        menuChildren: [
                          MenuItemButton(
                            onPressed: () => state.go(AppSection.help),
                            child: Text(s.menuHelp),
                          ),
                          MenuItemButton(
                            onPressed: () => state.go(AppSection.about),
                            child: Text(s.menuAbout),
                          ),
                        ],
                        child: Text(s.menuHelp, style: _menuStyle),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: GuruTheme.sand,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: const Size(44, 28),
                  ),
                  onPressed: state.toggleLanguage,
                  child: Text(s.langToggle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          Container(height: 1, color: GuruTheme.line),
        ],
      ),
    );
  }

  static const _menuStyle = TextStyle(fontSize: 12.5, color: Color(0xFFF4F1EA));
}
