import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class InstalledAppInfo {
  InstalledAppInfo({
    required this.packageName,
    required this.label,
    this.system = false,
  });

  final String packageName;
  final String label;
  final bool system;
}

class InstalledAppsBridge {
  InstalledAppsBridge._();
  static final InstalledAppsBridge instance = InstalledAppsBridge._();
  static const _ch = MethodChannel('guruproxy/installed_apps');

  bool get isSupported => !kIsWeb && Platform.isAndroid;

  Future<List<InstalledAppInfo>> listLaunchable() async {
    if (!isSupported) return const [];
    final raw = await _ch.invokeMethod<List<dynamic>>('listLaunchable');
    return (raw ?? const [])
        .whereType<Map>()
        .map(
          (m) => InstalledAppInfo(
            packageName: m['package']?.toString() ?? '',
            label: m['label']?.toString() ?? '',
            system: m['system'] == true,
          ),
        )
        .where((a) => a.packageName.isNotEmpty)
        .toList();
  }
}
