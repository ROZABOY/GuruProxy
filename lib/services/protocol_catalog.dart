import 'dart:io';

/// Known Psiphon tunnel protocols exposed as Settings checkboxes.
class ProtocolOption {
  const ProtocolOption({
    required this.id,
    required this.label,
    required this.hint,
    this.mobilePreferred = false,
    this.desktopCdnDefault = false,
  });

  final String id;
  final String label;
  final String hint;
  final bool mobilePreferred;
  final bool desktopCdnDefault;
}

class ProtocolCatalog {
  ProtocolCatalog._();

  static const options = <ProtocolOption>[
    ProtocolOption(
      id: 'FRONTED-MEEK-CDN-OSSH',
      label: 'Fronted Meek CDN + OSSH',
      hint: 'CDN-fronted OSSH (Se7en Windows staple)',
      desktopCdnDefault: true,
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
      id: 'UNFRONTED-MEEK-HTTPS',
      label: 'Unfronted Meek HTTPS',
      hint: 'Direct Meek — common on Android/iOS',
      mobilePreferred: true,
    ),
    ProtocolOption(
      id: 'UNFRONTED-MEEK-SESSION-TICKET',
      label: 'Unfronted Meek session ticket',
      hint: 'TLS session-ticket Meek variant',
      mobilePreferred: true,
    ),
    ProtocolOption(
      id: 'QUIC-OSSH',
      label: 'QUIC + OSSH',
      hint: 'UDP QUIC tunnel (mobile-friendly)',
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
    'UNFRONTED-MEEK-HTTPS',
    'UNFRONTED-MEEK-SESSION-TICKET',
    'QUIC-OSSH',
    'OSSH',
    'TLS-OSSH',
    'SSH',
  ];

  static List<String> desktopCdnDefaults() =>
      options.where((o) => o.desktopCdnDefault).map((o) => o.id).toList();

  static List<String> mobileAutoDefaults() {
    final preferred = options.where((o) => o.mobilePreferred).map((o) => o.id).toList();
    return _sorted(preferred);
  }

  static List<String> directDefaults() => const [
        'QUIC-OSSH',
        'OSSH',
        'TLS-OSSH',
        'SSH',
        'FRONTED-MEEK-QUIC-OSSH',
        'FRONTED-MEEK-OSSH',
        'FRONTED-MEEK-CDN-OSSH',
        'UNFRONTED-MEEK-HTTPS',
      ];

  /// Resolve LimitTunnelProtocols from settings flags.
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
      // Auto mode on desktop: mix CDN + direct-friendly.
      return _sorted({...desktopCdnDefaults(), ...directDefaults()}.toList());
    }

    final picked = enabled.where((id) => options.any((o) => o.id == id)).toList();
    if (picked.isEmpty) {
      return resolve(autoProtocol: true, enabled: const [], protocolMode: protocolMode);
    }
    return _sorted(picked);
  }

  static List<String> _sorted(List<String> ids) {
    final set = ids.toSet();
    final out = <String>[];
    for (final id in order) {
      if (set.remove(id)) out.add(id);
    }
    out.addAll(set);
    return out;
  }
}
