import 'package:flutter/material.dart';

import 'services/settings_store.dart';
import 'services/tunnel_engine.dart';

enum AppSection { connect, whiteIp, settings, log, help, about }

class AppState extends ChangeNotifier {
  AppState({required this.settings, required this.tunnel}) {
    settings.addListener(notifyListeners);
    tunnel.addListener(notifyListeners);
  }

  final SettingsStore settings;
  final TunnelEngine tunnel;

  AppSection section = AppSection.connect;

  Locale get locale => Locale(settings.language == 'fa' ? 'fa' : 'en');

  void go(AppSection s) {
    section = s;
    notifyListeners();
  }

  void toggleLanguage() {
    settings.language = settings.language == 'fa' ? 'en' : 'fa';
  }
}
