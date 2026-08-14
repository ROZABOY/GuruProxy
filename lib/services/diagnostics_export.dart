import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'tunnel_engine.dart';

class DiagnosticsExport {
  DiagnosticsExport._();

  static final _secretish = RegExp(
    r'(PropagationChannelId|SponsorId|PublicKey|private|password|token|secret)[\"\s:=]+[^\s,\"\}]+',
    caseSensitive: false,
  );

  static String sanitize(String raw) {
    var s = raw;
    s = s.replaceAllMapped(_secretish, (m) => '${m.group(1)}=***');
    s = s.replaceAll(RegExp(r'\b\d{1,3}(?:\.\d{1,3}){3}:\d+\b'), '*.*.*.*:*');
    return s;
  }

  /// Copies sanitized diagnostics to clipboard and writes a temp file.
  static Future<String> shareSession(TunnelEngine tunnel, {int lastN = 120}) async {
    final lines = tunnel.recentLog;
    final slice = lines.length <= lastN ? lines : lines.sublist(lines.length - lastN);
    final body = sanitize(slice.join('\n'));
    final header = [
      'GuruProxy diagnostics',
      'state=${tunnel.state}',
      'socks=${tunnel.socksPort} http=${tunnel.httpPort}',
      'region=${tunnel.connectedRegion}',
      'protocol=${tunnel.routeProtocol}',
      'platform=${Platform.operatingSystem}',
      '---',
    ].join('\n');
    final text = '$header\n$body';
    await Clipboard.setData(ClipboardData(text: text));
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}${Platform.pathSeparator}guruproxy-diagnostics.txt');
      await f.writeAsString(text);
      return f.path;
    } catch (_) {
      return 'clipboard';
    }
  }
}
