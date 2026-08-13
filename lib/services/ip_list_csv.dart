/// CSV helpers for White IP lists.
/// Format:
/// ip,latency_ms,ttl,message
/// 104.16.7.36,22,50,ping ok
class IpListCsv {
  static const header = 'ip,latency_ms,ttl,message';

  static List<ParsedIpRow> parse(String raw) {
    final rows = <ParsedIpRow>[];
    final seen = <String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (t.toLowerCase().startsWith('ip,')) continue;
      final parts = _splitCsv(t);
      if (parts.isEmpty) continue;
      final ip = parts[0].trim();
      if (!_isIpv4(ip) || !seen.add(ip)) continue;
      final latency = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
      final ttl = parts.length > 2 ? int.tryParse(parts[2].trim()) : null;
      final message = parts.length > 3 ? parts.sublist(3).join(',').trim() : 'imported';
      rows.add(ParsedIpRow(ip: ip, latencyMs: latency, ttl: ttl, message: message));
    }
    rows.sort((a, b) {
      final la = a.latencyMs <= 0 ? 1 << 30 : a.latencyMs;
      final lb = b.latencyMs <= 0 ? 1 << 30 : b.latencyMs;
      return la.compareTo(lb);
    });
    return rows;
  }

  static String export({
    required Iterable<ParsedIpRow> rows,
  }) {
    final buf = StringBuffer('$header\n');
    for (final r in rows) {
      buf.writeln('${r.ip},${r.latencyMs},${r.ttl ?? ''},${_esc(r.message)}');
    }
    return buf.toString();
  }

  static String exportFromEntries({
    required Iterable<({String ip, int latencyMs, String message})> entries,
  }) {
    return export(
      rows: entries.map(
        (e) => ParsedIpRow(ip: e.ip, latencyMs: e.latencyMs, message: e.message),
      ),
    );
  }

  static List<String> _splitCsv(String line) {
    // Simple CSV: no quoted commas in our format; keep robust enough.
    return line.split(',');
  }

  static String _esc(String s) => s.replaceAll(',', ';');

  static bool _isIpv4(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final v = int.tryParse(p);
      if (v == null || v < 0 || v > 255) return false;
    }
    return true;
  }
}

class ParsedIpRow {
  ParsedIpRow({
    required this.ip,
    this.latencyMs = 0,
    this.ttl,
    this.message = '',
  });

  final String ip;
  final int latencyMs;
  final int? ttl;
  final String message;
}
