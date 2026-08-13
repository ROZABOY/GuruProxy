import 'dart:convert';

/// Builds FrontedMeekDialOverrides.
/// Prefer order for this ISP: Cloudflare → Google → Akamai (fallback).
class FrontingDialBuilder {
  static const maxCustomIps = 32;

  static const cloudflareEdgeIps = <(String, String)>[
    ('cf-seed-1', '104.16.132.229'),
    ('cf-seed-2', '104.17.96.13'),
    ('cf-seed-3', '104.18.26.90'),
    ('cf-seed-4', '172.67.74.144'),
  ];

  static const googleEdgeIps = <(String, String)>[
    ('google-seed-1', '142.250.185.110'),
    ('google-seed-2', '142.250.203.142'),
    ('google-seed-3', '172.217.16.142'),
    ('google-seed-4', '216.58.212.142'),
  ];

  static const akamaiEdgeIps = <(String, String)>[
    ('akamai-a-1', '23.215.0.206'),
    ('akamai-a-2', '23.215.0.203'),
    ('akamai-b-1', '23.212.250.91'),
    ('akamai-b-2', '23.212.250.78'),
    ('akamai-c-1', '23.12.147.13'),
    ('akamai-c-2', '23.12.147.29'),
    ('akamai-d-1', '23.73.207.8'),
    ('akamai-d-2', '23.73.207.15'),
    ('akamai-original', '92.123.102.43'),
  ];

  static const akamaiVerify = [
    'a248.e.akamai.net',
    'a.akamaized.net',
    'a.akamaihd.net',
    'www.akamai.com',
  ];
  static const cloudflareVerify = [
    'www.cloudflare.com',
    'cloudflare.com',
    'cdnjs.cloudflare.com',
    'workers.dev',
  ];
  static const googleVerify = [
    'www.gstatic.com',
    'fonts.googleapis.com',
    'ajax.googleapis.com',
    'accounts.google.com',
  ];
  static const fastlyVerify = [
    'www.python.org',
    'pypi.org',
    'fastly.com',
    'github.com',
  ];

  /// Preferred CDN try-order for dial overrides / UI.
  static const providerPriority = ['cloudflare', 'google', 'akamai', 'fastly'];

  static String normalizeProvider(String? id) {
    switch ((id ?? '').trim().toLowerCase()) {
      case 'cloudflare':
      case 'cf':
        return 'cloudflare';
      case 'google':
      case 'gcdn':
      case 'gcp':
        return 'google';
      case 'fastly':
        return 'fastly';
      case 'akamai':
        return 'akamai';
      default:
        // Default preference: Cloudflare first for this product.
        return 'cloudflare';
    }
  }

  static List<String> parseIps(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    final seen = <String>{};
    final out = <String>[];
    for (final part in raw.split(RegExp(r'[\s,;]+'))) {
      final ip = part.trim();
      if (!_isIpv4(ip) || !seen.add(ip)) continue;
      out.add(ip);
      if (out.length >= maxCustomIps) break;
    }
    return out;
  }

  static List<String> parseSnis(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    final seen = <String>{};
    final out = <String>[];
    for (final part in raw.split(RegExp(r'[\s,;]+'))) {
      final host = part.trim();
      if (host.isEmpty || _isIpv4(host) || !seen.add(host.toLowerCase())) continue;
      out.add(host);
    }
    return out;
  }

  static List<Map<String, dynamic>> buildDialOverrides({
    String? customIpList,
    String? customSni,
    bool includeBuiltInDefaults = true,
    String? providerId,
  }) {
    final preferred = normalizeProvider(providerId);
    final overrides = <Map<String, dynamic>>[];
    final edgeDialAddresses = <String>{};
    final snis = parseSnis(customSni);
    final primarySni = snis.isNotEmpty ? snis.first : '';

    // 0) Steal native Akamai/Google dials from server entries → preferred CDN.
    // MatchFrontingProviderIDRegexes cannot match opaque hex IDs like BACEC04E…
    // so we match dial hostnames and rewrite them.
    if (includeBuiltInDefaults) {
      if (preferred == 'cloudflare' || preferred == 'google') {
        final stealTo = preferred == 'google' ? 'www.gstatic.com' : 'cdnjs.cloudflare.com';
        final stealSni = preferred == 'google' ? 'www.gstatic.com' : 'cdnjs.cloudflare.com';
        final stealVerify = preferred == 'google' ? googleVerify : cloudflareVerify;
        overrides.add(_makeOverride(
          overrideId: 'rewrite-akamai-to-$preferred',
          matchDialAddressRegexes: [r'(?i)(akamai|akamaized|akamaitechnologies|edgekey|edgesuite)'],
          dialAddress: stealTo,
          sniServerName: stealSni,
          verifyServerNames: stealVerify,
          alpn: const ['h2', 'http/1.1'],
        ));
      }
      if (preferred == 'cloudflare') {
        overrides.add(_makeOverride(
          overrideId: 'rewrite-google-to-cloudflare',
          matchDialAddressRegexes: [r'(?i)(gstatic|googleapis|google\.com)'],
          dialAddress: 'cdnjs.cloudflare.com',
          sniServerName: 'cdnjs.cloudflare.com',
          verifyServerNames: cloudflareVerify,
          alpn: const ['h2', 'http/1.1'],
        ));
      }
    }

    // 1) Provider/hostname fronts — Cloudflare first, then Google, then others.
    if (includeBuiltInDefaults) {
      _addProviderFronts(overrides, preferredFirst: preferred);
    }

    // 2) User custom IPs first among .* catch-alls (highest priority force dials).
    final customIps = parseIps(customIpList);
    for (var i = 0; i < customIps.length; i++) {
      final sniForIp = snis.isNotEmpty ? snis[i % snis.length] : _defaultSni(preferred);
      _putEdge(
        overrides,
        edgeDialAddresses,
        'edge-custom-${i + 1}',
        customIps[i],
        sniForIp,
        preferred,
      );
    }

    // 3) Built-in IP seeds: preferred family first (CF → Google → Akamai).
    if (includeBuiltInDefaults) {
      final orderedSeeds = <(String, String, String)>[
        for (final e in cloudflareEdgeIps) (e.$1, e.$2, 'cloudflare'),
        for (final e in googleEdgeIps) (e.$1, e.$2, 'google'),
        for (final e in akamaiEdgeIps) (e.$1, e.$2, 'akamai'),
      ];
      orderedSeeds.sort((a, b) {
        int rank(String p) {
          if (p == preferred) return 0;
          final i = providerPriority.indexOf(p);
          return i < 0 ? 99 : i + 1;
        }

        return rank(a.$3).compareTo(rank(b.$3));
      });
      for (final e in orderedSeeds) {
        final sni = primarySni.isNotEmpty ? primarySni : _defaultSni(e.$3);
        _putEdge(overrides, edgeDialAddresses, e.$1, e.$2, sni, e.$3);
      }
    }

    return overrides;
  }

  static void _addProviderFronts(
    List<Map<String, dynamic>> overrides, {
    required String preferredFirst,
  }) {
    void cf() {
      overrides.add(_makeOverride(
        overrideId: 'cloudflare-provider',
        matchFrontingProviderIdRegexes: ['(?i)cloudflare'],
        dialAddress: 'cdnjs.cloudflare.com',
        sniServerName: 'cdnjs.cloudflare.com',
        verifyServerNames: cloudflareVerify,
        alpn: const ['h2', 'http/1.1'],
      ));
      overrides.add(_makeOverride(
        overrideId: 'cloudflare-address',
        matchDialAddressRegexes: ['(?i)(cloudflare|cdnjs|workers\\.dev)'],
        dialAddress: 'www.cloudflare.com',
        sniServerName: 'www.cloudflare.com',
        verifyServerNames: cloudflareVerify,
        alpn: const ['h2', 'http/1.1'],
      ));
    }

    void google() {
      overrides.add(_makeOverride(
        overrideId: 'google-provider',
        matchFrontingProviderIdRegexes: ['(?i)(google|gcdn|gcp)'],
        dialAddress: 'www.gstatic.com',
        sniServerName: 'www.gstatic.com',
        verifyServerNames: googleVerify,
        alpn: const ['h2', 'http/1.1'],
      ));
      overrides.add(_makeOverride(
        overrideId: 'google-address',
        matchDialAddressRegexes: ['(?i)(gstatic|googleapis|google\\.com)'],
        dialAddress: 'fonts.googleapis.com',
        sniServerName: 'fonts.googleapis.com',
        verifyServerNames: googleVerify,
        alpn: const ['h2', 'http/1.1'],
      ));
    }

    void fastly() {
      overrides.add(_makeOverride(
        overrideId: 'fastly-provider',
        matchFrontingProviderIdRegexes: ['(?i)fastly'],
        dialAddress: 'pypi.org',
        sniServerName: 'pypi.org',
        verifyServerNames: fastlyVerify,
        alpn: const ['h2', 'http/1.1'],
      ));
      overrides.add(_makeOverride(
        overrideId: 'fastly-address',
        matchDialAddressRegexes: ['(?i)(fastly|pypi|python|github)'],
        dialAddress: 'pypi.org',
        sniServerName: 'pypi.org',
        verifyServerNames: fastlyVerify,
        alpn: const ['h2', 'http/1.1'],
      ));
    }

    void akamai() {
      overrides.add(_makeOverride(
        overrideId: 'akamai-provider',
        matchFrontingProviderIdRegexes: ['(?i)akamai'],
        dialAddress: 'a248.e.akamai.net',
        sniServerName: 'a248.e.akamai.net',
        verifyServerNames: akamaiVerify,
        alpn: const ['http/1.1'],
      ));
    }

    // Preferred family first, then the fixed product order.
    final steps = <String, void Function()>{
      'cloudflare': cf,
      'google': google,
      'akamai': akamai,
      'fastly': fastly,
    };
    final order = <String>[
      preferredFirst,
      ...providerPriority.where((p) => p != preferredFirst),
    ];
    for (final p in order) {
      steps[p]?.call();
    }
  }

  static String _defaultSni(String provider) => switch (provider) {
        'cloudflare' => 'www.cloudflare.com',
        'google' => 'www.gstatic.com',
        'fastly' => 'pypi.org',
        _ => 'a248.e.akamai.net',
      };

  static String encodeOverridesJson({
    String? customIpList,
    String? customSni,
    bool includeBuiltInDefaults = true,
    String? providerId,
  }) {
    return jsonEncode(buildDialOverrides(
      customIpList: customIpList,
      customSni: customSni,
      includeBuiltInDefaults: includeBuiltInDefaults,
      providerId: providerId,
    ));
  }

  static void _putEdge(
    List<Map<String, dynamic>> overrides,
    Set<String> dialAddresses,
    String id,
    String ip,
    String customSni,
    String provider,
  ) {
    if (!dialAddresses.add(ip)) return;
    final sni = customSni.isEmpty ? _defaultSni(provider) : customSni;
    final alpn = (provider == 'cloudflare' || provider == 'fastly' || provider == 'google')
        ? const ['h2', 'http/1.1']
        : const ['http/1.1'];
    final verify = <String>{sni, ip, ..._verifyNames(provider)}.toList();
    overrides.add(_makeOverride(
      overrideId: id,
      matchDialAddressRegexes: ['.*'],
      dialAddress: ip,
      sniServerName: sni,
      verifyServerNames: verify,
      alpn: alpn,
    ));
  }

  static List<String> _verifyNames(String provider) {
    switch (provider) {
      case 'cloudflare':
        return cloudflareVerify;
      case 'google':
        return googleVerify;
      case 'fastly':
        return fastlyVerify;
      default:
        return akamaiVerify;
    }
  }

  static Map<String, dynamic> _makeOverride({
    required String overrideId,
    List<String>? matchFrontingProviderIdRegexes,
    List<String>? matchDialAddressRegexes,
    required String dialAddress,
    required String sniServerName,
    required List<String> verifyServerNames,
    required List<String> alpn,
  }) {
    final obj = <String, dynamic>{
      'OverrideID': overrideId,
      'DialAddresses': [dialAddress],
      'SNIServerName': sniServerName,
      'VerifyServerNames': verifyServerNames,
      'ALPNProtocols': alpn,
      'TLSProfile': 'Chrome-83',
    };
    if (matchFrontingProviderIdRegexes != null) {
      obj['MatchFrontingProviderIDRegexes'] = matchFrontingProviderIdRegexes;
    }
    if (matchDialAddressRegexes != null) {
      obj['MatchDialAddressRegexes'] = matchDialAddressRegexes;
    }
    return obj;
  }

  static bool _isIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final v = int.tryParse(p);
      if (v == null || v < 0 || v > 255) return false;
    }
    return true;
  }
}
