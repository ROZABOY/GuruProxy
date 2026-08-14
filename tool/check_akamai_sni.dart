import '../lib/services/fronting_dial.dart';

void main() {
  final o = FrontingDialBuilder.buildDialOverrides(
    customIpList: '104.16.7.36\n162.159.82.102\n162.159.82.90',
    customSni: 'www.cloudflare.com\nak.net.akamaized.net\ncloudflare.com',
    includeBuiltInDefaults: true,
    providerId: 'cloudflare',
  );
  print('count=${o.length}');
  print('first3=${o.take(5).map((e) => '${e['OverrideID']}:${e['SNIServerName']}:${e['MatchDialAddressRegexes']}').join(' | ')}');
  final custom = o.firstWhere((e) => e['OverrideID'] == 'edge-custom-1');
  final akamai = o.firstWhere((e) => e['OverrideID'] == 'edge-a-1');
  if (custom['MatchDialAddressRegexes']?.first != '.*') {
    throw StateError('custom must be catch-all .*');
  }
  if (akamai['SNIServerName'] != 'www.cloudflare.com') {
    throw StateError('akamai must use primary SNI like Se7en, got ${akamai['SNIServerName']}');
  }
  print('OK Se7en-identical');
}
