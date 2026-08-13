import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ScanMethod { ping, tcp443, tlsSni }

class ScanHit {
  ScanHit({required this.ip, required this.latencyMs, required this.message, this.sni = ''});
  final String ip;
  final int latencyMs;
  final String message;
  final String sni;
}

class EdgeScanner extends ChangeNotifier {
  bool running = false;
  bool paused = false;
  String status = 'Idle';
  int checked = 0;
  int failed = 0;
  int total = 0;
  final List<ScanHit> healthy = [];
  final List<String> candidates = [];

  Completer<void>? _pauseGate;

  Future<void> scan({
    required String provider,
    required List<String> snis,
    required ScanMethod method,
    List<String> manualIps = const [],
    int maxCandidates = 200,
    int concurrency = 16,
    int perCidr = 6,
    int timeoutMs = 4000,
    bool clearPrevious = true,
  }) async {
    if (running) return;
    running = true;
    paused = false;
    checked = 0;
    failed = 0;
    total = 0;
    if (clearPrevious) healthy.clear();
    candidates.clear();
    status = 'Building candidate list…';
    notifyListeners();

    try {
      final fromManual = _parseIps(manualIps.join('\n'));
      candidates.addAll(fromManual);

      if (candidates.length < maxCandidates) {
        final asset = switch (provider) {
          'cloudflare' => 'assets/ranges/cloudflare_ip_ranges.txt',
          'fastly' => 'assets/ranges/fastly_ip_ranges.txt',
          'google' => 'assets/ranges/cloudflare_ip_ranges.txt', // no google CIDR pack yet; scan CF-like until added
          _ => 'assets/ranges/akamai_ip_ranges.txt',
        };
        final text = await rootBundle.loadString(asset);
        final cidrs = text
            .split(RegExp(r'\r?\n'))
            .map((l) => l.trim())
            .where((l) => l.contains('/') && !l.startsWith('#'))
            .take(120)
            .toList();

        final rnd = Random();
        final seen = candidates.toSet();
        for (final cidr in cidrs) {
          for (final ip in _sampleFromCidr(cidr, perRange: perCidr, rnd: rnd)) {
            if (seen.add(ip)) candidates.add(ip);
            if (candidates.length >= maxCandidates) break;
          }
          if (candidates.length >= maxCandidates) break;
        }
      }

      if (candidates.isEmpty) {
        candidates.addAll(const [
          '23.215.0.206',
          '23.215.0.203',
          '23.212.250.91',
          '23.73.207.8',
          '92.123.102.43',
        ]);
      }

      total = candidates.length;
      final sniList = snis.where((s) => s.trim().isNotEmpty).toList();
      if (sniList.isEmpty) sniList.add(_defaultSni(provider));

      status = 'Scanning $total IPs (${method.name}, ${sniList.length} SNI)…';
      notifyListeners();

      var index = 0;
      Future<void> worker() async {
        while (running) {
          await _waitIfPaused();
          if (!running) return;
          final i = index++;
          if (i >= candidates.length) return;
          final ip = candidates[i];
          final sni = sniList[i % sniList.length];
          final hit = await _check(ip, sni, method, timeoutMs);
          checked++;
          if (hit != null) {
            healthy.add(hit);
            healthy.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
          } else {
            failed++;
          }
          if (checked % 2 == 0 || hit != null) {
            status =
                'Checked $checked/$total — healthy ${healthy.length}, failed $failed'
                '${paused ? ' (paused)' : ''}';
            notifyListeners();
          }
        }
      }

      final workers = concurrency.clamp(1, 64);
      await Future.wait(List.generate(workers, (_) => worker()));
      status = running
          ? 'Done. ${healthy.length} healthy / $failed failed of $total'
          : 'Stopped. ${healthy.length} healthy / $failed failed';
    } catch (e) {
      status = 'Scanner error: $e';
    } finally {
      running = false;
      paused = false;
      notifyListeners();
    }
  }

  Future<void> scanManualOnly({
    required List<String> ips,
    required List<String> snis,
    required ScanMethod method,
    int concurrency = 16,
    int timeoutMs = 4000,
  }) async {
    await scan(
      provider: 'akamai',
      snis: snis,
      method: method,
      manualIps: ips,
      maxCandidates: ips.length,
      concurrency: concurrency,
      timeoutMs: timeoutMs,
      clearPrevious: true,
    );
  }

  void pause() {
    if (!running || paused) return;
    paused = true;
    _pauseGate = Completer<void>();
    status = 'Paused at $checked/$total — healthy ${healthy.length}';
    notifyListeners();
  }

  void resume() {
    if (!running || !paused) return;
    paused = false;
    _pauseGate?.complete();
    _pauseGate = null;
    status = 'Resumed… $checked/$total';
    notifyListeners();
  }

  void stop() {
    running = false;
    paused = false;
    _pauseGate?.complete();
    _pauseGate = null;
    status = 'Stopping…';
    notifyListeners();
  }

  Future<void> _waitIfPaused() async {
    while (paused && running) {
      final gate = _pauseGate;
      if (gate == null) break;
      await gate.future;
    }
  }

  Future<ScanHit?> _check(String ip, String sni, ScanMethod method, int timeoutMs) {
    switch (method) {
      case ScanMethod.ping:
        return _ping(ip, timeoutMs);
      case ScanMethod.tcp443:
        return _tcp443(ip, timeoutMs);
      case ScanMethod.tlsSni:
        return _tlsSni(ip, sni, timeoutMs);
    }
  }

  Future<ScanHit?> _ping(String ip, int timeoutMs) async {
    final sw = Stopwatch()..start();
    try {
      // Windows: ping -n 1 -w timeoutMs
      final result = await Process.run(
        'ping',
        ['-n', '1', '-w', '$timeoutMs', ip],
        runInShell: false,
      );
      sw.stop();
      if (result.exitCode == 0) {
        return ScanHit(ip: ip, latencyMs: sw.elapsedMilliseconds, message: 'ping ok');
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ScanHit?> _tcp443(String ip, int timeoutMs) async {
    final sw = Stopwatch()..start();
    try {
      final sock = await Socket.connect(ip, 443, timeout: Duration(milliseconds: timeoutMs));
      await sock.close();
      sw.stop();
      return ScanHit(ip: ip, latencyMs: sw.elapsedMilliseconds, message: 'tcp/443 ok');
    } catch (_) {
      return null;
    }
  }

  Future<ScanHit?> _tlsSni(String ip, String sni, int timeoutMs) async {
    final sw = Stopwatch()..start();
    try {
      final raw = await Socket.connect(ip, 443, timeout: Duration(milliseconds: timeoutMs));
      try {
        final secure = await SecureSocket.secure(
          raw,
          host: sni,
          onBadCertificate: (_) => true,
        );
        await secure.close();
        sw.stop();
        return ScanHit(
          ip: ip,
          latencyMs: sw.elapsedMilliseconds,
          message: 'TLS+SNI ok',
          sni: sni,
        );
      } catch (_) {
        try {
          await raw.close();
        } catch (_) {}
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  static String _defaultSni(String provider) => switch (provider) {
        'cloudflare' => 'www.cloudflare.com',
        'google' => 'www.gstatic.com',
        'fastly' => 'pypi.org',
        _ => 'a248.e.akamai.net',
      };

  static List<String> _parseIps(String raw) {
    final out = <String>[];
    final seen = <String>{};
    for (final part in raw.split(RegExp(r'[\s,;]+'))) {
      final ip = part.trim();
      if (!_isIpv4(ip) || !seen.add(ip)) continue;
      out.add(ip);
    }
    return out;
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

  List<String> _sampleFromCidr(String cidr, {required int perRange, required Random rnd}) {
    final parts = cidr.split('/');
    if (parts.length != 2) return [];
    final base = parts[0].split('.').map(int.tryParse).toList();
    final prefix = int.tryParse(parts[1]);
    if (base.length != 4 || base.any((e) => e == null) || prefix == null) return [];
    if (prefix < 16 || prefix > 32) return [];

    final hostBits = 32 - prefix;
    final span = hostBits >= 16 ? 1 << 16 : (1 << hostBits);
    final baseInt = (base[0]! << 24) | (base[1]! << 16) | (base[2]! << 8) | base[3]!;
    final mask = hostBits == 0 ? 0xFFFFFFFF : (0xFFFFFFFF << hostBits) & 0xFFFFFFFF;
    final network = baseInt & mask;

    final out = <String>[];
    final take = min(perRange, max(1, span - 2));
    for (var i = 0; i < take; i++) {
      final offset = span <= 2 ? 0 : 1 + rnd.nextInt(span - 2);
      final ipInt = network + offset;
      out.add(
        '${(ipInt >> 24) & 0xFF}.${(ipInt >> 16) & 0xFF}.${(ipInt >> 8) & 0xFF}.${ipInt & 0xFF}',
      );
    }
    return out;
  }
}
