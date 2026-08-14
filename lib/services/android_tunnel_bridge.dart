import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges Flutter ↔ Psiphon Android library (ca.psiphon) + VpnService.
class AndroidTunnelBridge {
  AndroidTunnelBridge._();
  static final AndroidTunnelBridge instance = AndroidTunnelBridge._();

  static const _methods = MethodChannel('guruproxy/android_tunnel');
  static const _events = EventChannel('guruproxy/android_tunnel_events');

  StreamSubscription? _sub;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get events => _controller.stream;

  bool get isSupported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> ensureListening() async {
    if (!isSupported || _sub != null) return;
    _sub = _events.receiveBroadcastStream().listen((raw) {
      if (raw is Map) {
        _controller.add(Map<String, dynamic>.from(raw));
      }
    });
  }

  Future<void> start(
    String configJson, {
    String? serverEntriesPath,
    bool vpnMode = false,
  }) async {
    await ensureListening();
    await _methods.invokeMethod<void>('start', {
      'config': configJson,
      'vpnMode': vpnMode,
      if (serverEntriesPath != null && serverEntriesPath.isNotEmpty)
        'serverEntriesPath': serverEntriesPath,
    });
  }

  Future<void> stop() async {
    if (!isSupported) return;
    await _methods.invokeMethod<void>('stop');
  }

  Future<bool> prepareVpn() async {
    if (!isSupported) return false;
    final ok = await _methods.invokeMethod<bool>('prepareVpn');
    return ok == true;
  }

  Future<void> startVpnRouting({
    required int socks,
    required String mode,
    required List<String> apps,
  }) async {
    if (!isSupported) return;
    await _methods.invokeMethod<void>('startVpnRouting', {
      'socks': socks,
      'mode': mode,
      'apps': apps.join(','),
    });
  }

  Future<void> stopVpnRouting() async {
    if (!isSupported) return;
    await _methods.invokeMethod<void>('stopVpnRouting');
  }

  Future<bool> vpnRunning() async {
    if (!isSupported) return false;
    return await _methods.invokeMethod<bool>('vpnRunning') == true;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
