/// Iran ISP Meek-front presets (starting points — verify with health-check).
class IranIspPreset {
  const IranIspPreset({
    required this.id,
    required this.label,
    required this.hint,
    required this.ips,
    required this.snis,
    this.provider = 'cloudflare',
  });

  final String id;
  final String label;
  final String hint;
  final List<String> ips;
  final List<String> snis;
  final String provider;
}

class IranIspPresets {
  IranIspPresets._();

  static const all = <IranIspPreset>[
    IranIspPreset(
      id: 'mci',
      label: 'MCI (Hamrah Aval)',
      hint: 'CDN fronts that often work on MCI',
      ips: [
        '104.16.7.36',
        '104.16.8.36',
        '162.159.82.102',
        '23.215.0.206',
        '23.215.0.203',
      ],
      snis: ['www.cloudflare.com', 'cdnjs.cloudflare.com', 'a248.e.akamai.net'],
    ),
    IranIspPreset(
      id: 'irancell',
      label: 'Irancell',
      hint: 'CDN fronts that often work on Irancell',
      ips: [
        '104.16.9.36',
        '162.159.136.98',
        '23.212.250.91',
        '23.212.250.78',
        '216.239.38.120',
      ],
      snis: ['www.cloudflare.com', 'www.google.com', 'a248.e.akamai.net'],
      provider: 'cloudflare',
    ),
    IranIspPreset(
      id: 'rightel',
      label: 'Rightel',
      hint: 'Mixed CF + Akamai edges',
      ips: [
        '104.17.1.36',
        '23.12.147.13',
        '23.73.207.8',
        '92.123.102.43',
      ],
      snis: ['www.cloudflare.com', 'a248.e.akamai.net'],
    ),
    IranIspPreset(
      id: 'mixed',
      label: 'Iran mixed (safe start)',
      hint: 'Broader multi-CDN set for unknown ISP',
      ips: [
        '104.16.7.36',
        '162.159.82.102',
        '23.215.0.206',
        '23.212.250.91',
        '216.239.38.120',
        '151.101.1.69',
      ],
      snis: [
        'www.cloudflare.com',
        'cdnjs.cloudflare.com',
        'www.google.com',
        'a248.e.akamai.net',
      ],
    ),
  ];

  static IranIspPreset? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
