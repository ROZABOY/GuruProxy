import 'dart:convert';

/// CDN fronting dial overrides for Psiphon FrontedMeekDialOverrides.
///
/// Working pattern:
/// - custom IPs as catch-all `MatchDialAddressRegexes: [".*"]` (`edge-custom-N`)
/// - built-in Akamai edges also `.*`, with SNI = first custom SNI when set
///   (often `www.cloudflare.com`), NOT forced `a248.e.akamai.net`
class FrontingDialBuilder {
  static const maxCustomIps = 32;

  static const defaultEdgeIps = <(String, String)>[
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
    'developer.fastly.com',
    'githubassets.com',
    'github.com',
    'github.io',
    'githubusercontent.com',
  ];
  static const amazonVerify = [
    'd1.cloudfront.net',
    'cloudfront.net',
    's3.amazonaws.com',
    'aws.amazon.com',
  ];
  static const azureVerify = [
    'ajax.aspnetcdn.com',
    'cdn.office.net',
    'static.azureedge.net',
    'az.msecnd.net',
  ];

  static String normalizeProvider(String? id) {
    switch ((id ?? '').trim().toLowerCase()) {
      case 'cloudflare':
      case 'cf':
        return 'cloudflare';
      case 'fastly':
        return 'fastly';
      case 'google':
      case 'gcdn':
      case 'gcp':
        return 'google';
      case 'amazon':
        return 'amazon';
      case 'azure':
        return 'azure';
      case 'iran-isp':
        return 'akamai';
      case 'akamai':
        return 'akamai';
      default:
        // CDN default when unset is akamai; GuruProxy UI prefers cloudflare
        // but either works with catch-all custom IPs.
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
      if (!_isHostname(host)) continue;
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
    final provider = normalizeProvider(providerId);
    final overrides = <Map<String, dynamic>>[];
    final edgeDialAddresses = <String>{};
    final snis = parseSnis(customSni);
    final primarySni = snis.isNotEmpty ? snis.first : '';

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

    // CDN: every custom IP is a catch-all `.*` edge override.
    final customIps = parseIps(customIpList);
    for (var i = 0; i < customIps.length; i++) {
      final sniForIp = snis.isNotEmpty ? snis[i % snis.length] : '';
      _putEdgeOverride(
        overrides,
        edgeDialAddresses,
        'edge-custom-${i + 1}',
        customIps[i],
        sniForIp,
        provider,
      );
    }

    if (includeBuiltInDefaults) {
      // CDN: Akamai built-ins use primarySni when set (often Cloudflare SNI).
      for (final e in defaultEdgeIps) {
        _putEdgeOverride(
          overrides,
          edgeDialAddresses,
          e.$1,
          e.$2,
          primarySni,
          'akamai',
        );
      }
    }

    return overrides;
  }

  static void _putEdgeOverride(
    List<Map<String, dynamic>> overrides,
    Set<String> dialAddresses,
    String overrideId,
    String ipAddress,
    String customSni,
    String providerId,
  ) {
    if (!dialAddresses.add(ipAddress)) return;
    // CDN: empty custom SNI â†’ use the IP itself as SNIServerName.
    final sniServerName = customSni.trim().isEmpty ? ipAddress : customSni.trim();
    final alpn = (providerId == 'cloudflare' || providerId == 'fastly' || providerId == 'google')
        ? const ['h2', 'http/1.1']
        : const ['http/1.1'];
    overrides.add(_makeOverride(
      overrideId: overrideId,
      matchDialAddressRegexes: ['.*'],
      dialAddress: ipAddress,
      sniServerName: sniServerName,
      verifyServerNames: _buildEdgeVerify(providerId, ipAddress, sniServerName),
      alpn: alpn,
    ));
  }

  static List<String> _buildEdgeVerify(String providerId, String ip, String sni) {
    final list = <String>[];
    final seen = <String>{};
    void add(String? v) {
      if (v == null || v.isEmpty) return;
      if (seen.add(v)) list.add(v);
    }

    add(sni);
    add(ip);
    for (final n in _providerVerify(providerId)) {
      add(n);
    }
    return list;
  }

  static List<String> _providerVerify(String providerId) {
    switch (providerId) {
      case 'cloudflare':
        return cloudflareVerify;
      case 'fastly':
        return fastlyVerify;
      case 'google':
        return googleVerify;
      case 'amazon':
        return amazonVerify;
      case 'azure':
        return azureVerify;
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

  static bool _isHostname(String hostname) {
    if (hostname.isEmpty || hostname.length > 253) return false;
    if (_isIpv4(hostname)) return false;
    var normalised = hostname;
    if (normalised.endsWith('.')) {
      normalised = normalised.substring(0, normalised.length - 1);
    }
    if (normalised.isEmpty) return false;
    for (final label in normalised.split('.')) {
      if (label.isEmpty || label.length > 63) return false;
      if (label.startsWith('-') || label.endsWith('-')) return false;
      for (final c in label.codeUnits) {
        final ok = (c >= 97 && c <= 122) ||
            (c >= 65 && c <= 90) ||
            (c >= 48 && c <= 57) ||
            c == 45;
        if (!ok) return false;
      }
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
