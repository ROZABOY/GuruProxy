import 'dart:io';

/// Psiphon LimitTunnelProtocols — must match SupportedTunnelProtocols.
/// Invalid names (e.g. UNFRONTED-MEEK-HTTPS without -OSSH) abort Start().
class ProtocolOption {
  const ProtocolOption({
    required this.id,
    required this.label,
    required this.hint,
    this.mobilePreferred = false,
    this.desktopCdnDefault = false,
    this.androidSupported = true,
  });

  final String id;
  final String label;
  final String hint;
  final bool mobilePreferred;
  final bool desktopCdnDefault;
  final bool androidSupported;
}

class ProtocolCatalog {
  ProtocolCatalog._();

  /// Absolute allow-list for Android Psiphon library (v2.0.x).
  static const androidAllowList = <String>{
    'SSH',
    'OSSH',
    'TLS-OSSH',
    'QUIC-OSSH',
    'FRONTED-MEEK-OSSH',
    'FRONTED-MEEK-HTTP-OSSH',
    'FRONTED-MEEK-QUIC-OSSH',
    'UNFRONTED-MEEK-OSSH',
    'UNFRONTED-MEEK-HTTPS-OSSH',
    'UNFRONTED-MEEK-SESSION-TICKET-OSSH',
    'SHADOWSOCKS-OSSH',
    'CONJURE-OSSH',
  };

  static const aliases = <String, String>{
    'UNFRONTED-MEEK-HTTPS': 'UNFRONTED-MEEK-HTTPS-OSSH',
    'UNFRONTED-MEEK-SESSION-TICKET': 'UNFRONTED-MEEK-SESSION-TICKET-OSSH',
    'UNFRONTED-MEEK': 'UNFRONTED-MEEK-OSSH',
    'FRONTED-MEEK-CDN-OSSH': 'FRONTED-MEEK-OSSH', // CDN-OSSH not in Android library
  };

  static const options = <ProtocolOption>[
    ProtocolOption(
      id: 'FRONTED-MEEK-OSSH',
      label: 'Fronted Meek + OSSH',
      hint: 'Classic CDN-fronted Meek',
      mobilePreferred: true,
      desktopCdnDefault: true,
    ),
    ProtocolOption(
      id: 'FRONTED-MEEK-HTTP-OSSH',
      label: 'Fronted Meek HTTP + OSSH',
      hint: 'HTTP-path Meek fronting',
      mobilePreferred: true,
      desktopCdnDefault: true,
    ),
    ProtocolOption(
      id: 'FRONTED-MEEK-QUIC-OSSH',
      label: 'Fronted Meek QUIC + OSSH',
      hint: 'Often stronger on mobile/cellular',
      mobilePreferred: true,
      desktopCdnDefault: true,
    ),
    ProtocolOption(
      id: 'UNFRONTED-MEEK-HTTPS-OSSH',
      label: 'Unfronted Meek HTTPS + OSSH',
      hint: 'Direct Meek HTTPS (Android/iOS)',
      mobilePreferred: true,
    ),
    ProtocolOption(
      id: 'UNFRONTED-MEEK-SESSION-TICKET-OSSH',
      label: 'Unfronted Meek session ticket + OSSH',
      hint: 'TLS session-ticket Meek',
      mobilePreferred: true,
    ),
    ProtocolOption(
      id: 'UNFRONTED-MEEK-OSSH',
      label: 'Unfronted Meek + OSSH',
      hint: 'Plain unfronted Meek',
      mobilePreferred: true,
    ),
    ProtocolOption(
      id: 'QUIC-OSSH',
      label: 'QUIC + OSSH',
      hint: 'UDP QUIC tunnel',
      mobilePreferred: true,
    ),
    ProtocolOption(
      id: 'OSSH',
      label: 'OSSH',
      hint: 'Obfuscated SSH',
      mobilePreferred: true,
    ),
    ProtocolOption(
      id: 'SSH',
      label: 'SSH',
      hint: 'Plain SSH',
    ),
    ProtocolOption(
      id: 'TLS-OSSH',
      label: 'TLS + OSSH',
      hint: 'TLS-wrapped OSSH',
    ),
  ];

  static const order = <String>[
    'FRONTED-MEEK-QUIC-OSSH',
    'FRONTED-MEEK-HTTP-OSSH',
    'FRONTED-MEEK-OSSH',
    'UNFRONTED-MEEK-HTTPS-OSSH',
    'UNFRONTED-MEEK-SESSION-TICKET-OSSH',
    'UNFRONTED-MEEK-OSSH',
    'QUIC-OSSH',
    'OSSH',
    'TLS-OSSH',
    'SSH',
  ];

  static String canonicalize(String id) => aliases[id.trim()] ?? id.trim();

  /// Never returns a protocol that will fail Validate() on Android.
  static List<String> sanitizeForStart(List<String> raw, {required bool android}) {
    final out = <String>[];
    final seen = <String>{};
    for (final id in raw) {
      final c = canonicalize(id);
      if (c.isEmpty || !seen.add(c)) continue;
      if (android && !androidAllowList.contains(c)) continue;
      out.add(c);
    }
    if (out.isEmpty) {
      return android ? List<String>.from(mobileAutoDefaults()) : desktopCdnDefaults();
    }
    return _sorted(out);
  }

  static List<String> desktopCdnDefaults() =>
      options.where((o) => o.desktopCdnDefault).map((o) => o.id).toList();

  static List<String> mobileAutoDefaults() => _sorted(const [
        'FRONTED-MEEK-QUIC-OSSH',
        'FRONTED-MEEK-HTTP-OSSH',
        'FRONTED-MEEK-OSSH',
        'UNFRONTED-MEEK-HTTPS-OSSH',
        'UNFRONTED-MEEK-SESSION-TICKET-OSSH',
        'UNFRONTED-MEEK-OSSH',
        'QUIC-OSSH',
        'OSSH',
      ]);

  static List<String> directDefaults() => sanitizeForStart(const [
        'QUIC-OSSH',
        'OSSH',
        'TLS-OSSH',
        'SSH',
        'FRONTED-MEEK-QUIC-OSSH',
        'FRONTED-MEEK-OSSH',
        'UNFRONTED-MEEK-HTTPS-OSSH',
      ], android: Platform.isAndroid || Platform.isIOS);

  static List<String> resolve({
    required bool autoProtocol,
    required List<String> enabled,
    required String protocolMode,
  }) {
    final android = Platform.isAndroid || Platform.isIOS;
    List<String> raw;
    if (autoProtocol) {
      if (android) {
        raw = mobileAutoDefaults();
      } else if (protocolMode == 'cdn_fronting') {
        raw = desktopCdnDefaults();
      } else if (protocolMode == 'direct') {
        raw = directDefaults();
      } else {
        raw = [...desktopCdnDefaults(), ...directDefaults()];
      }
    } else {
      raw = enabled.map(canonicalize).where((id) => options.any((o) => o.id == id)).toList();
      if (raw.isEmpty) {
        return resolve(autoProtocol: true, enabled: const [], protocolMode: protocolMode);
      }
    }
    return sanitizeForStart(raw, android: android);
  }

  static List<String> _sorted(List<String> ids) {
    final set = ids.map(canonicalize).toSet();
    final out = <String>[];
    for (final id in order) {
      if (set.remove(id)) out.add(id);
    }
    out.addAll(set);
    return out;
  }
}
