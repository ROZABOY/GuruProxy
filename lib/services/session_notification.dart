import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'tunnel_engine.dart';

typedef StopTunnelCallback = Future<void> Function();

/// VPN-style ongoing notification with speeds + Stop (native Android channel).
class SessionNotification {
  SessionNotification._();
  static final SessionNotification instance = SessionNotification._();

  static const _channel = MethodChannel('guruproxy/session_notification');
  static const stopActionId = 'guruproxy_stop';

  StopTunnelCallback? onStop;
  bool _ready = false;
  bool _visible = false;

  Future<void> init({required StopTunnelCallback onStop}) async {
    this.onStop = onStop;
    if (kIsWeb || !Platform.isAndroid) {
      _ready = true;
      return;
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stop') {
        await this.onStop?.call();
      }
    });

    try {
      await _channel.invokeMethod<void>('init');
    } catch (_) {}
    _ready = true;
  }

  Future<void> sync(TunnelEngine tunnel) async {
    if (!_ready || kIsWeb || !Platform.isAndroid) return;

    final active = tunnel.state == TunnelState.connected ||
        tunnel.state == TunnelState.connecting ||
        tunnel.state == TunnelState.disconnecting;

    if (!active) {
      if (_visible) {
        try {
          await _channel.invokeMethod<void>('clear');
        } catch (_) {}
        _visible = false;
      }
      return;
    }

    final title = switch (tunnel.state) {
      TunnelState.connected => 'GuruProxy · Connected',
      TunnelState.connecting => 'GuruProxy · Connecting…',
      TunnelState.disconnecting => 'GuruProxy · Stopping…',
      _ => 'GuruProxy',
    };

    final region = tunnel.connectedRegion.isNotEmpty ? tunnel.connectedRegion : '…';
    final body = '↑ ${tunnel.uploadLabel}  ↓ ${tunnel.downloadLabel}  ·  $region';

    try {
      await _channel.invokeMethod<void>('show', <String, dynamic>{
        'title': title,
        'body': body,
      });
      _visible = true;
    } catch (_) {}
  }

  Future<void> clear() async {
    if (!_ready || !Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('clear');
    } catch (_) {}
    _visible = false;
  }
}
