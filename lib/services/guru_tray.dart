import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'tunnel_engine.dart';

/// Windows tray using the user's brand .ico files.
class GuruTray with TrayListener, WindowListener {
  GuruTray(this.tunnel);

  final TunnelEngine tunnel;
  bool _ready = false;
  String _iconDir = '';

  Future<void> init() async {
    if (kIsWeb || !Platform.isWindows) return;
    try {
      final support = await getApplicationSupportDirectory();
      _iconDir = '${support.path}${Platform.pathSeparator}GuruProxy${Platform.pathSeparator}tray';
      await Directory(_iconDir).create(recursive: true);
      for (final name in [
        'tray-disconnected.ico',
        'tray-connecting.ico',
        'tray-connected.ico',
        'app-icon.ico',
      ]) {
        await _extract('assets/brand/$name', '$_iconDir${Platform.pathSeparator}$name');
      }

      trayManager.addListener(this);
      windowManager.addListener(this);
      await trayManager.setIcon(_iconPath(TunnelState.disconnected));
      await trayManager.setToolTip('GuruProxy');
      await trayManager.setContextMenu(Menu(items: [
        MenuItem(key: 'show', label: 'Show GuruProxy'),
        MenuItem.separator(),
        MenuItem(key: 'connect', label: 'Connect'),
        MenuItem(key: 'disconnect', label: 'Disconnect'),
        MenuItem.separator(),
        MenuItem(key: 'exit', label: 'Exit'),
      ]));
      _ready = true;
      tunnel.addListener(_onTunnel);
      await sync();
    } catch (e) {
      debugPrint('Tray init failed: $e');
    }
  }

  Future<void> _extract(String asset, String dest) async {
    final data = await rootBundle.load(asset);
    final file = File(dest);
    final bytes = data.buffer.asUint8List();
    if (await file.exists() && await file.length() == bytes.length) return;
    await file.writeAsBytes(bytes, flush: true);
  }

  String _iconPath(TunnelState s) {
    final name = switch (s) {
      TunnelState.connected => 'tray-connected.ico',
      TunnelState.connecting || TunnelState.disconnecting => 'tray-connecting.ico',
      _ => 'tray-disconnected.ico',
    };
    return '$_iconDir${Platform.pathSeparator}$name';
  }

  void _onTunnel() => sync();

  Future<void> sync() async {
    if (!_ready) return;
    try {
      await trayManager.setIcon(_iconPath(tunnel.state));
      final tip = switch (tunnel.state) {
        TunnelState.connected =>
          'GuruProxy · Connected${tunnel.connectedRegion.isNotEmpty ? " · ${tunnel.connectedRegion}" : ""}',
        TunnelState.connecting => 'GuruProxy · Connecting…',
        TunnelState.disconnecting => 'GuruProxy · Stopping…',
        _ => 'GuruProxy · Disconnected',
      };
      await trayManager.setToolTip(tip);
    } catch (_) {}
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        windowManager.show();
        windowManager.focus();
      case 'connect':
        if (!tunnel.isActive) tunnel.start();
      case 'disconnect':
        if (tunnel.isActive) tunnel.stop();
      case 'exit':
        tunnel.stop();
        trayManager.destroy();
        windowManager.destroy();
    }
  }

  @override
  void onWindowClose() async {
    // Keep running in tray.
    await windowManager.hide();
  }

  Future<void> dispose() async {
    if (!_ready) return;
    tunnel.removeListener(_onTunnel);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
  }
}
