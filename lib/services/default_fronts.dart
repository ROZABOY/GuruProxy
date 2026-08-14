/// Built-in CDN front candidates so Connect is never empty of dial IPs/SNIs.
class DefaultFront {
  const DefaultFront({required this.ip, required this.sni, required this.provider});
  final String ip;
  final String sni;
  final String provider;
}

class DefaultFronts {
  DefaultFronts._();

  /// Seed list: Cloudflare + Google + Akamai + Fastly (+ a few extras).
  static const all = <DefaultFront>[
    // Cloudflare
    DefaultFront(ip: '104.16.7.36', sni: 'www.cloudflare.com', provider: 'cloudflare'),
    DefaultFront(ip: '104.16.8.36', sni: 'www.cloudflare.com', provider: 'cloudflare'),
    DefaultFront(ip: '162.159.82.90', sni: 'cdnjs.cloudflare.com', provider: 'cloudflare'),
    DefaultFront(ip: '172.67.159.60', sni: 'www.cloudflare.com', provider: 'cloudflare'),
    DefaultFront(ip: '104.24.181.142', sni: 'cloudflare.com', provider: 'cloudflare'),
    // Google
    DefaultFront(ip: '216.239.38.120', sni: 'www.google.com', provider: 'google'),
    DefaultFront(ip: '216.239.32.117', sni: 'www.gstatic.com', provider: 'google'),
    DefaultFront(ip: '142.250.185.110', sni: 'fonts.googleapis.com', provider: 'google'),
    DefaultFront(ip: '142.250.203.174', sni: 'www.google.com', provider: 'google'),
    // Akamai (Se7en catch-alls)
    DefaultFront(ip: '23.215.0.206', sni: 'a248.e.akamai.net', provider: 'akamai'),
    DefaultFront(ip: '23.215.0.203', sni: 'a.akamaized.net', provider: 'akamai'),
    DefaultFront(ip: '23.212.250.91', sni: 'a.akamaihd.net', provider: 'akamai'),
    DefaultFront(ip: '23.73.207.8', sni: 'www.akamai.com', provider: 'akamai'),
    DefaultFront(ip: '92.123.102.43', sni: 'a248.e.akamai.net', provider: 'akamai'),
    // Fastly
    DefaultFront(ip: '151.101.1.69', sni: 'www.python.org', provider: 'fastly'),
    DefaultFront(ip: '151.101.65.69', sni: 'pypi.org', provider: 'fastly'),
    DefaultFront(ip: '151.101.129.69', sni: 'github.com', provider: 'fastly'),
    DefaultFront(ip: '199.232.69.194', sni: 'github.githubassets.com', provider: 'fastly'),
    // Extras often usable as SNI fronts
    DefaultFront(ip: '13.32.88.10', sni: 'aws.amazon.com', provider: 'amazon'),
    DefaultFront(ip: '13.107.21.200', sni: 'www.microsoft.com', provider: 'azure'),
  ];

  static String ipsText({int max = 24}) =>
      all.take(max).map((e) => e.ip).toList().toSet().join('\n');

  static String snisText() => all.map((e) => e.sni).toSet().join('\n');

  static List<({String ip, String sni, int latencyMs})> asEntries({int max = 24}) => [
        for (var i = 0; i < all.length && i < max; i++)
          (ip: all[i].ip, sni: all[i].sni, latencyMs: 20 + i),
      ];
}
