import 'dart:async';
import 'dart:io';

/// Probe whether an edge behaves like a usable Meek front (not merely open TCP).
class MeekHealthResult {
  MeekHealthResult({
    required this.ip,
    required this.sni,
    required this.ok,
    required this.detail,
    this.latencyMs = 0,
  });

  final String ip;
  final String sni;
  final bool ok;
  final String detail;
  final int latencyMs;
}

class MeekHealthCheck {
  MeekHealthCheck._();

  /// TCP+TLS with real SNI, then HTTP GET Host=SNI.
  /// HTTP 403/404 after TLS = classic "TLS-ok but not a Psiphon front".
  static Future<MeekHealthResult> probe({
    required String ip,
    required String sni,
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final sw = Stopwatch()..start();
    SecureSocket? secure;
    try {
      final raw = await Socket.connect(ip, 443, timeout: timeout);
      secure = await SecureSocket.secure(
        raw,
        host: sni,
        onBadCertificate: (_) => true,
      ).timeout(timeout);

      final req =
          'GET / HTTP/1.1\r\nHost: $sni\r\nConnection: close\r\nUser-Agent: GuruProxyHealth/2.6\r\n\r\n';
      secure.add(req.codeUnits);
      await secure.flush();

      final buf = StringBuffer();
      await for (final chunk in secure.timeout(timeout)) {
        buf.write(String.fromCharCodes(chunk));
        if (buf.length > 512 || buf.toString().contains('\r\n\r\n')) break;
      }
      sw.stop();
      final head = buf.toString();
      final m = RegExp(r'HTTP/\d\.\d\s+(\d{3})').firstMatch(head);
      final code = int.tryParse(m?.group(1) ?? '') ?? 0;
      if (code == 403 || code == 404) {
        return MeekHealthResult(
          ip: ip,
          sni: sni,
          ok: false,
          detail: 'HTTP $code (TLS ok, weak/unlikely Meek front)',
          latencyMs: sw.elapsedMilliseconds,
        );
      }
      if (code >= 200 && code < 500) {
        return MeekHealthResult(
          ip: ip,
          sni: sni,
          ok: true,
          detail: 'HTTP $code',
          latencyMs: sw.elapsedMilliseconds,
        );
      }
      // TLS worked but odd response — keep as soft-ok for dialing.
      return MeekHealthResult(
        ip: ip,
        sni: sni,
        ok: true,
        detail: code == 0 ? 'TLS ok (no HTTP status)' : 'HTTP $code',
        latencyMs: sw.elapsedMilliseconds,
      );
    } catch (e) {
      sw.stop();
      return MeekHealthResult(
        ip: ip,
        sni: sni,
        ok: false,
        detail: e.toString(),
        latencyMs: sw.elapsedMilliseconds,
      );
    } finally {
      try {
        await secure?.close();
      } catch (_) {}
    }
  }

  static Future<List<MeekHealthResult>> probeMany({
    required List<String> ips,
    required String sni,
    int concurrency = 4,
  }) async {
    final out = <MeekHealthResult>[];
    var i = 0;
    while (i < ips.length) {
      final chunk = ips.skip(i).take(concurrency).toList();
      final part = await Future.wait(chunk.map((ip) => probe(ip: ip, sni: sni)));
      out.addAll(part);
      i += concurrency;
    }
    return out;
  }
}
