import '../lib/services/fronting_dial.dart';

void main() {
  final o = FrontingDialBuilder.buildDialOverrides(
    customIpList: '104.16.7.36\n162.159.82.102',
    customSni: 'www.cloudflare.com\ncdnjs.cloudflare.com',
    includeBuiltInDefaults: true,
    providerId: 'cloudflare',
  );
  final akamai = o.where((e) => (e['OverrideID'] as String).startsWith('edge-'));
  for (final e in akamai) {
    final sni = e['SNIServerName'];
    print('${e['OverrideID']} SNI=$sni dial=${e['DialAddresses']}');
    if (sni != 'a248.e.akamai.net') {
      throw StateError('Akamai edge poisoned with SNI=$sni');
    }
  }
  print('OK overrides=${o.length} first=${o.first['OverrideID']}');
}
