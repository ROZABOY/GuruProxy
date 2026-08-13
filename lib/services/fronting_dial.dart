import 'dart:convert';

/// Exact Se7en/GuruProxy_v1 dial-override strategy + Cloudflare scoped extras.
///
/// Working Se7en connect uses Akamai catch-all edges with Akamai SNI
/// (`a248.e.akamai.net`) and FRONTED-MEEK-OSSH. Applying Cloudflare SNI to
/// those Akamai IPs causes Meek 400/404 — that was the GuruProxy bug.
class FrontingDialBuilder {
  static const maxCustomIps = 16;

  static const akamaiEdgeIps = <(String, String)>[
    ('edge-a-1', '23.215.0.206'),
    ('edge-a-2', '23.215.0.203'),
    ('edge-b-1', '23.212.250.91'),
    ('edge-b-2', '23.212.250.78'),
    ('edge-c-1', '23.12.147.13'),
    ('edge-c-2', '23.12.147.29'),
    ('edge-d-1', '23.73.207.8'),
    ('edge-d-2', '23.73.207.15'),
    ('edge-original', '92.123.102.43'),
  ];

  static const akamaiVerify = [
    'a248.e.akamai.net',
    'a.akamaized.net',
    'a.akamaized-staging.net',
    'a.akamaihd.net',
    'a.akamaihd-staging.net',
    'www.akamai.com',
  ];
  static const cloudflareVerify = [
    'www.cloudflare.com',
    'cloudflare.com',
    'cdnjs.cloudflare.com',
    'discord.com',
    'www.shopify.com',
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
    'www.fastly.com',
    'github.com',
  ];

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
    final customIps = parseIps(customIpList);

    // --- Se7en order: Fastly scoped ---
    if (includeBuiltInDefaults) {
      overrides.add(_makeOverride(
        overrideId: 'fastly-provider',
        matchFrontingProviderIdRegexes: [r'(?i)fastly'],
        dialAddress: 'pypi.org',
        sniServerName: 'pypi.org',
        verifyServerNames: fastlyVerify,
        alpn: const ['h2', 'http/1.1'],
      ));
      overrides.add(_makeOverride(
        overrideId: 'fastly-address',
        matchDialAddressRegexes: [r'(?i)(fastly|pypi|python|github)'],
        dialAddress: 'pypi.org',
        sniServerName: 'pypi.org',
        verifyServerNames: fastlyVerify,
        alpn: const ['h2', 'http/1.1'],
      ));
    }

    // --- Cloudflare custom IPs: SCOPED only (never `.*`, never on Akamai SNI) ---
    if (preferred == 'cloudflare' || preferred == 'google' || preferred == 'fastly') {
      for (var i = 0; i < customIps.length; i++) {
        final ip = customIps[i];
        if (!edgeDialAddresses.add(ip)) continue;
        final sni = snis.isNotEmpty ? snis[i % snis.length] : _defaultSni(preferred);
        if (preferred == 'cloudflare') {
          overrides.add(_makeOverride(
            overrideId: 'cf-user-${i + 1}',
            matchFrontingProviderIdRegexes: [r'(?i)cloudflare'],
            matchDialAddressRegexes: [r'(?i)(cloudflare|cdnjs|workers\.dev)'],
            dialAddress: ip,
            sniServerName: sni,
            verifyServerNames: {sni, ip, ...cloudflareVerify}.toList(),
            alpn: const ['h2', 'http/1.1'],
          ));
        } else if (preferred == 'google') {
          overrides.add(_makeOverride(
            overrideId: 'google-user-${i + 1}',
            matchFrontingProviderIdRegexes: [r'(?i)(google|gcdn|gcp)'],
            matchDialAddressRegexes: [r'(?i)(gstatic|googleapis|google\.com)'],
            dialAddress: ip,
            sniServerName: sni,
            verifyServerNames: {sni, ip, ...googleVerify}.toList(),
            alpn: const ['h2', 'http/1.1'],
          ));
        } else {
          overrides.add(_makeOverride(
            overrideId: 'fastly-user-${i + 1}',
            matchFrontingProviderIdRegexes: [r'(?i)fastly'],
            matchDialAddressRegexes: [r'(?i)(fastly|pypi|python|github)'],
            dialAddress: ip,
            sniServerName: sni,
            verifyServerNames: {sni, ip, ...fastlyVerify}.toList(),
            alpn: const ['h2', 'http/1.1'],
          ));
        }
      }
    } else {
      // Akamai/custom provider: Se7en-style catch-all custom edges with Akamai SNI.
      for (var i = 0; i < customIps.length; i++) {
        final ip = customIps[i];
        _putCatchAllEdge(
          overrides,
          edgeDialAddresses,
          'edge-custom-${i + 1}',
          ip,
          'a248.e.akamai.net',
          'akamai',
        );
      }
    }

    if (includeBuiltInDefaults) {
      // Se7en Akamai catch-alls — ALWAYS Akamai SNI (this is what connects).
      for (final e in akamaiEdgeIps) {
        _putCatchAllEdge(
          overrides,
          edgeDialAddresses,
          e.$1,
          e.$2,
          'a248.e.akamai.net',
          'akamai',
        );
      }
    } else if (customIps.isNotEmpty && preferred == 'cloudflare') {
      // Explicit CF-only mode (risky).
      for (var i = 0; i < customIps.length; i++) {
        _putCatchAllEdge(
          overrides,
          edgeDialAddresses,
          'cf-only-${i + 1}',
          customIps[i],
          snis.isNotEmpty ? snis[i % snis.length] : _defaultSni('cloudflare'),
          'cloudflare',
        );
      }
    }

    return overrides;
  }

  static String _defaultSni(String provider) => switch (provider) {
        'cloudflare' => 'www.cloudflare.com',
        'google' => 'www.gstatic.com',
        'fastly' => 'pypi.org',
        _ => 'a248.e.akamai.net',
      };

  static void _putCatchAllEdge(
    List<Map<String, dynamic>> overrides,
    Set<String> dialAddresses,
    String id,
    String ip,
    String sni,
    String provider,
  ) {
    if (!dialAddresses.add(ip)) return;
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
}
