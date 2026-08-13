import '../lib/services/fronting_dial.dart';

void main() {
  final o = FrontingDialBuilder.buildDialOverrides(
    customIpList: '104.16.7.36\n162.159.82.102',
    customSni: 'www.cloudflare.com',
    includeBuiltInDefaults: true,
    providerId: 'cloudflare',
  );
  print('count=${o.length}');
  print('order=${o.map((e) => e['OverrideID']).take(8).join(' → ')}');
  print('first=${o.first['OverrideID']} dial=${o.first['DialAddresses']}');
  final ids = o.map((e) => e['OverrideID']?.toString() ?? '').toList();
  final cfIdx = ids.indexWhere((id) => id.startsWith('cf-'));
  final akamaiIdx = ids.indexWhere((id) => id.contains('akamai'));
  print('firstCF=$cfIdx firstAkamai=$akamaiIdx');
  if (cfIdx != 0) {
    throw StateError('Cloudflare must be first');
  }
  if (akamaiIdx >= 0 && akamaiIdx < cfIdx) {
    throw StateError('Akamai must not precede Cloudflare');
  }
  print('OK');
}
