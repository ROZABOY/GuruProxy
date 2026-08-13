import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n/strings.dart';
import '../theme/guru_theme.dart';
import 'pages/about_page.dart';
import 'pages/connect_page.dart';
import 'pages/help_page.dart';
import 'pages/log_page.dart';
import 'pages/settings_page.dart';
import 'pages/white_ip_page.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.locale.languageCode == 'fa');

    return Scaffold(
      body: Column(
        children: [
          _TopBar(s: s, state: state),
          Expanded(
            child: ColoredBox(
              color: GuruTheme.ink,
              child: switch (state.section) {
                AppSection.connect => const ConnectPage(),
                AppSection.whiteIp => const WhiteIpPage(),
                AppSection.settings => const SettingsPage(),
                AppSection.log => const LogPage(),
                AppSection.help => const HelpPage(),
                AppSection.about => const AboutPage(),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.s, required this.state});
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
            height: 36,
            child: Row(
              children: [
                const SizedBox(width: 8),
                Image.asset(
                  'assets/brand/app-icon.png',
                  width: 20,
                  height: 20,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.shield_outlined, size: 18, color: GuruTheme.sand);
                  },
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
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: state.toggleLanguage,
                  child: Text(
                    s.langToggle,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
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
