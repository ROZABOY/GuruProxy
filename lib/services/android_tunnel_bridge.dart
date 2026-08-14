import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Bridges Flutter ↔ Psiphon Android library (ca.psiphon).
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

  /// [serverEntriesPath] is read on the Kotlin side (file can exceed Binder size limits).
  Future<void> start(String configJson, {String? serverEntriesPath}) async {
    await ensureListening();
    await _methods.invokeMethod<void>('start', {
      'config': configJson,
      if (serverEntriesPath != null && serverEntriesPath.isNotEmpty)
        'serverEntriesPath': serverEntriesPath,
    });
  }

  Future<void> stop() async {
    if (!isSupported) return;
    await _methods.invokeMethod<void>('stop');
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
