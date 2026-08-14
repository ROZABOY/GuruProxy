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
  /// False for protocols only the Windows Se7en binary accepts (e.g. CDN-OSSH).
  final bool androidSupported;
}

class ProtocolCatalog {
  ProtocolCatalog._();

  /// Rename legacy checkbox IDs that crash Android library validation.
  static const aliases = <String, String>{
    'UNFRONTED-MEEK-HTTPS': 'UNFRONTED-MEEK-HTTPS-OSSH',
    'UNFRONTED-MEEK-SESSION-TICKET': 'UNFRONTED-MEEK-SESSION-TICKET-OSSH',
    'UNFRONTED-MEEK': 'UNFRONTED-MEEK-OSSH',
  };

  static const options = <ProtocolOption>[
    ProtocolOption(
      id: 'FRONTED-MEEK-CDN-OSSH',
      label: 'Fronted Meek CDN + OSSH',
      hint: 'Se7en Windows staple — not in Android library',
      desktopCdnDefault: true,
      androidSupported: false,
    ),
    ProtocolOption(
      id: 'FRONTED-MEEK-OSSH',
      label: 'Fronted Meek + OSSH',
      hint: 'Classic fronted Meek',
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
    'FRONTED-MEEK-CDN-OSSH',
    'UNFRONTED-MEEK-HTTPS-OSSH',
    'UNFRONTED-MEEK-SESSION-TICKET-OSSH',
    'UNFRONTED-MEEK-OSSH',
    'QUIC-OSSH',
    'OSSH',
    'TLS-OSSH',
    'SSH',
  ];

  static String canonicalize(String id) => aliases[id] ?? id;

  static List<String> desktopCdnDefaults() =>
      options.where((o) => o.desktopCdnDefault).map((o) => o.id).toList();

  static List<String> mobileAutoDefaults() {
    // Prefer fronted Meek first (matches Se7en CDN path), then unfronted + QUIC.
    return _forPlatform(_sorted([
      'FRONTED-MEEK-QUIC-OSSH',
      'FRONTED-MEEK-HTTP-OSSH',
      'FRONTED-MEEK-OSSH',
      'UNFRONTED-MEEK-HTTPS-OSSH',
      'UNFRONTED-MEEK-SESSION-TICKET-OSSH',
      'UNFRONTED-MEEK-OSSH',
      'QUIC-OSSH',
      'OSSH',
    ]));
  }

  static List<String> directDefaults() => _forPlatform(const [
        'QUIC-OSSH',
        'OSSH',
        'TLS-OSSH',
        'SSH',
        'FRONTED-MEEK-QUIC-OSSH',
        'FRONTED-MEEK-OSSH',
        'UNFRONTED-MEEK-HTTPS-OSSH',
      ]);

  static List<String> resolve({
    required bool autoProtocol,
    required List<String> enabled,
    required String protocolMode,
  }) {
    if (autoProtocol) {
      final mobile = Platform.isAndroid || Platform.isIOS;
      if (mobile) return mobileAutoDefaults();
      if (protocolMode == 'cdn_fronting') return desktopCdnDefaults();
      if (protocolMode == 'direct') return directDefaults();
      return _forPlatform(_sorted({...desktopCdnDefaults(), ...directDefaults()}.toList()));
    }

    final picked = enabled.map(canonicalize).where((id) => options.any((o) => o.id == id)).toList();
    if (picked.isEmpty) {
      return resolve(autoProtocol: true, enabled: const [], protocolMode: protocolMode);
    }
    return _forPlatform(_sorted(picked));
  }

  static List<String> _forPlatform(List<String> ids) {
    if (!(Platform.isAndroid || Platform.isIOS)) return ids;
    final allowed = options.where((o) => o.androidSupported).map((o) => o.id).toSet();
    final out = ids.where(allowed.contains).toList();
    if (out.isEmpty) return mobileAutoDefaults();
    return out;
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
