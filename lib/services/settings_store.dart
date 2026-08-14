import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fronting_dial.dart';
import 'protocol_catalog.dart';

class SettingsStore extends ChangeNotifier {
  SettingsStore._(this._prefs);

  final SharedPreferences _prefs;

  static Future<SettingsStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    final store = SettingsStore._(prefs);
    final schema = prefs.getInt('settingsSchema') ?? 0;
    if (schema < 2) {
      final prev = prefs.getString('cdnProvider');
      if (prev == null || prev == 'akamai') {
        await prefs.setString('cdnProvider', 'cloudflare');
      }
      await prefs.setInt('settingsSchema', 2);
    }
    return store;
  }

  /// Apply v2.2 defaults: Cloudflare + known-working CF list (once).
  Future<void> ensureV22CloudflarePreset(String csvAssetText) async {
    final schema = _prefs.getInt('settingsSchema') ?? 0;
    // Schema 8 = ports 17888/17889 (leave 8088/8089 for Se7en Pro).
    if (schema >= 8 && customIps.trim().isNotEmpty && activeGroupName == 'known-working') {
      // Still migrate off Se7en ports if user somehow still has them.
      if (localSocksPort == 8088 || localHttpPort == 8089) {
        localSocksPort = 17888;
        localHttpPort = 17889;
      }
      return;
    }

    cdnProvider = 'cloudflare';
    sniOverrideEnabled = true;
    customSnis =
        'www.cloudflare.com\nak.net.akamaized.net\ncloudflare.com\nsnapp.ir\ndigikala.com\ngoogle.com';
    // Keep Se7en Akamai catch-alls so FRONTED-MEEK-OSSH can connect.
    autoFindIpAndSni = true;
    protocolMode = 'cdn_fronting';
    beastMode = true;
    localSocksPort = 17888;
    localHttpPort = 17889;
    establishTimeoutSec = 90;

    // Parse CSV without importing ip_list_csv cycle in setter path — inline.
    final ips = <String>[];
    final entries = <IpEntry>[];
    for (final line in csvAssetText.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty || t.toLowerCase().startsWith('ip,')) continue;
      final parts = t.split(',');
      if (parts.isEmpty) continue;
      final ip = parts[0].trim();
      if (ip.split('.').length != 4) continue;
      if (ips.contains(ip)) continue;
      final latency = parts.length > 1 ? int.tryParse(parts[1].trim()) ?? 0 : 0;
      ips.add(ip);
      entries.add(IpEntry(ip: ip, latencyMs: latency, sni: 'www.cloudflare.com'));
    }
    if (ips.isEmpty) return;

    customIps = ips.join('\n');
    activeGroupName = 'known-working';
    autoFindIpAndSni = true;
    localSocksPort = 17888;
    localHttpPort = 17889;
    establishTimeoutSec = 90;
    upsertIpGroup(IpGroup(
      name: 'known-working',
      ips: customIps,
      snis: customSnis,
      provider: 'cloudflare',
      keepDefaults: true,
      entries: entries,
    ));
    await _prefs.setInt('settingsSchema', 8);
  }

  String get activeGroupName => _prefs.getString('activeGroupName') ?? '';
  set activeGroupName(String v) {
    _prefs.setString('activeGroupName', v.trim());
    notifyListeners();
  }

  String get language => _prefs.getString('language') ?? 'en';
  set language(String v) {
    _prefs.setString('language', v);
    notifyListeners();
  }

  String get protocolMode => _prefs.getString('protocolMode') ?? 'cdn_fronting';
  set protocolMode(String v) {
    _prefs.setString('protocolMode', v);
    notifyListeners();
  }

  /// When true, platform picks protocols (mobile ≠ Windows CDN set).
  bool get autoProtocol {
    if (_prefs.containsKey('autoProtocol')) {
      return _prefs.getBool('autoProtocol') ?? true;
    }
    // Fresh installs: auto on phones, manual CDN set on desktop.
    return Platform.isAndroid || Platform.isIOS;
  }

  set autoProtocol(bool v) {
    _prefs.setBool('autoProtocol', v);
    notifyListeners();
  }

  List<String> get enabledProtocols {
    final raw = _prefs.getString('enabledProtocolsJson');
    if (raw == null || raw.isEmpty) {
      return ProtocolCatalog.desktopCdnDefaults();
    }
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).toList();
    } catch (_) {
      return ProtocolCatalog.desktopCdnDefaults();
    }
  }

  set enabledProtocols(List<String> ids) {
    final known = ProtocolCatalog.options.map((o) => o.id).toSet();
    final selected = ids.where(known.contains).toList();
    _prefs.setString('enabledProtocolsJson', jsonEncode(selected));
    notifyListeners();
  }

  void setProtocolEnabled(String id, bool on) {
    final set = enabledProtocols.toSet();
    if (on) {
      set.add(id);
    } else {
      set.remove(id);
    }
    enabledProtocols = set.toList();
  }

  List<String> resolveTunnelProtocols() => ProtocolCatalog.resolve(
        autoProtocol: autoProtocol,
        enabled: enabledProtocols,
        protocolMode: protocolMode,
      );

  String get egressRegion {
    final v = _prefs.getString('egressRegion');
    if (v == null) return 'auto'; // default Auto, not US
    return v.trim().isEmpty ? 'auto' : v;
  }
  set egressRegion(String v) {
    final n = v.trim().isEmpty ? 'auto' : v.trim();
    _prefs.setString('egressRegion', n);
    notifyListeners();
  }

  /// Auto-find IP + SNI: merge built-in CDN edge defaults with any custom list.
  bool get autoFindIpAndSni {
    if (_prefs.containsKey('autoFindIpAndSni')) {
      return _prefs.getBool('autoFindIpAndSni') ?? true;
    }
    return _prefs.getBool('autoFindEdges') ?? true;
  }
  set autoFindIpAndSni(bool v) {
    _prefs.setBool('autoFindIpAndSni', v);
    // keep legacy key in sync for older UI bits
    _prefs.setBool('autoFindEdges', v);
    notifyListeners();
  }

  @Deprecated('Use autoFindIpAndSni')
  bool get autoFindEdges => autoFindIpAndSni;
  @Deprecated('Use autoFindIpAndSni')
  set autoFindEdges(bool v) => autoFindIpAndSni = v;

  bool get sniOverrideEnabled => _prefs.getBool('sniOverrideEnabled') ?? true;
  set sniOverrideEnabled(bool v) {
    _prefs.setBool('sniOverrideEnabled', v);
    notifyListeners();
  }

  String get customIps => _prefs.getString('customIps') ?? '';
  set customIps(String v) {
    _prefs.setString('customIps', v);
    notifyListeners();
  }

  String get customSnis => _prefs.getString('customSnis') ?? '';
  set customSnis(String v) {
    _prefs.setString('customSnis', v);
    notifyListeners();
  }

  String get cdnProvider => _prefs.getString('cdnProvider') ?? 'cloudflare';
  set cdnProvider(String v) {
    _prefs.setString('cdnProvider', FrontingDialBuilder.normalizeProvider(v));
    notifyListeners();
  }

  bool get beastMode => _prefs.getBool('beastMode') ?? true;
  set beastMode(bool v) {
    _prefs.setBool('beastMode', v);
    notifyListeners();
  }

  String get upstreamProxyUrl => _prefs.getString('upstreamProxyUrl') ?? '';
  set upstreamProxyUrl(String v) {
    _prefs.setString('upstreamProxyUrl', v.trim());
    notifyListeners();
  }

  String get upstreamProxyUser => _prefs.getString('upstreamProxyUser') ?? '';
  set upstreamProxyUser(String v) {
    _prefs.setString('upstreamProxyUser', v);
    notifyListeners();
  }

  String get upstreamProxyPass => _prefs.getString('upstreamProxyPass') ?? '';
  set upstreamProxyPass(String v) {
    _prefs.setString('upstreamProxyPass', v);
    notifyListeners();
  }

  bool get verboseLogs => _prefs.getBool('verboseLogs') ?? true;
  set verboseLogs(bool v) {
    _prefs.setBool('verboseLogs', v);
    notifyListeners();
  }

  int get establishTimeoutSec => _prefs.getInt('establishTimeoutSec') ?? 90;
  set establishTimeoutSec(int v) {
    _prefs.setInt('establishTimeoutSec', v.clamp(30, 600));
    notifyListeners();
  }

  int get localSocksPort => _prefs.getInt('localSocksPort') ?? 17888;
  set localSocksPort(int v) {
    _prefs.setInt('localSocksPort', _sanitizePort(v, 17888));
    notifyListeners();
  }

  int get localHttpPort => _prefs.getInt('localHttpPort') ?? 17889;
  set localHttpPort(int v) {
    _prefs.setInt('localHttpPort', _sanitizePort(v, 17889));
    notifyListeners();
  }

  /// mixed = SOCKS+HTTP (default), socks = SOCKS only, http = HTTP only.
  String get proxyListenMode => _prefs.getString('proxyListenMode') ?? 'mixed';
  set proxyListenMode(String v) {
    final n = switch (v.trim().toLowerCase()) {
      'socks' || 'socks5' => 'socks',
      'http' || 'https' => 'http',
      _ => 'mixed',
    };
    _prefs.setString('proxyListenMode', n);
    notifyListeners();
  }

  /// normal = current working defaults.
  /// stable = gentler timeouts for lossy links (not BBR — Psiphon has no BBR).
  String get connectionProfile => _prefs.getString('connectionProfile') ?? 'normal';
  set connectionProfile(String v) {
    final n = v.trim().toLowerCase() == 'stable' ? 'stable' : 'normal';
    _prefs.setString('connectionProfile', n);
    notifyListeners();
  }

  /// Run 2 tunnels when stable profile is on (failover / smoother browsing).
  bool get redundantTunnel => _prefs.getBool('redundantTunnel') ?? false;
  set redundantTunnel(bool v) {
    _prefs.setBool('redundantTunnel', v);
    notifyListeners();
  }

  /// Apps that should not use the proxy (exclude list).
  List<String> get excludedApps => blockedApps;
  set excludedApps(List<String> apps) => blockedApps = apps;

  /// Exe names that should bypass proxy once TUN routing lands (e.g. photoshop.exe).
  List<String> get blockedApps {
    final raw = _prefs.getString('blockedAppsJson');
    if (raw == null || raw.isEmpty) return [];
    try {
      return (jsonDecode(raw) as List).map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  set blockedApps(List<String> apps) {
    final cleaned = apps
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .map((e) => e.toLowerCase().endsWith('.exe') ? e : '$e.exe')
        .toSet()
        .toList()
      ..sort();
    _prefs.setString('blockedAppsJson', jsonEncode(cleaned));
    notifyListeners();
  }

  List<IpGroup> get ipGroups {
    final raw = _prefs.getString('ipGroupsJson');
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .whereType<Map>()
          .map((m) => IpGroup.fromJson(Map<String, dynamic>.from(m)))
          .where((g) => g.name.trim().isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  void saveIpGroups(List<IpGroup> groups) {
    _prefs.setString(
      'ipGroupsJson',
      jsonEncode(groups.map((g) => g.toJson()).toList()),
    );
    notifyListeners();
  }

  void upsertIpGroup(IpGroup group) {
    final list = ipGroups;
    final i = list.indexWhere((g) => g.name.toLowerCase() == group.name.toLowerCase());
    if (i >= 0) {
      list[i] = group.sortedBySpeed();
    } else {
      list.add(group.sortedBySpeed());
    }
    saveIpGroups(list);
  }

  void deleteIpGroup(String name) {
    saveIpGroups(ipGroups.where((g) => g.name.toLowerCase() != name.toLowerCase()).toList());
  }

  void applyIpGroup(IpGroup group) {
    final sorted = group.sortedBySpeed();
    customIps = sorted.ipsText;
    customSnis = sorted.snisText;
    cdnProvider = 'cloudflare'; // v2.2 always prefer CF for whitelist groups
    protocolMode = 'cdn_fronting';
    autoFindIpAndSni = sorted.keepDefaults;
    activeGroupName = sorted.name;
    if (sorted.snisText.trim().isNotEmpty) {
      sniOverrideEnabled = true;
    }
  }

  void applyIranQuickConnect() {
    protocolMode = 'cdn_fronting';
    egressRegion = 'auto';
    autoFindIpAndSni = true;
    cdnProvider = 'cloudflare';
    beastMode = false;
    upstreamProxyUrl = '';
    // Keep known-working list if present; don't wipe user's CF whitelist.
    if (customIps.trim().isEmpty) {
      customSnis = 'www.cloudflare.com\ncdnjs.cloudflare.com';
    }
    sniOverrideEnabled = true;
  }

  /// Build UpstreamProxyUrl for tunnel-core (empty if unset).
  String buildUpstreamProxyUrl() {
    final raw = upstreamProxyUrl.trim();
    if (raw.isEmpty) return '';
    var url = raw;
    if (!url.contains('://')) url = 'http://$url';
    final user = upstreamProxyUser.trim();
    final pass = upstreamProxyPass;
    if (user.isEmpty) return url;
    final uri = Uri.tryParse(url);
    if (uri == null) return url;
    return uri.replace(userInfo: '$user:${Uri.encodeComponent(pass)}').toString();
  }

  static int _sanitizePort(int v, int fallback) {
    if (v < 0 || v > 65535) return fallback;
    return v;
  }
}

class IpEntry {
  IpEntry({required this.ip, this.latencyMs = 0, this.sni = ''});

  final String ip;
  final int latencyMs;
  final String sni;

  Map<String, dynamic> toJson() => {
        'ip': ip,
        'latencyMs': latencyMs,
        'sni': sni,
      };

  factory IpEntry.fromJson(Map<String, dynamic> j) => IpEntry(
        ip: j['ip']?.toString() ?? '',
        latencyMs: (j['latencyMs'] as num?)?.toInt() ?? 0,
        sni: j['sni']?.toString() ?? '',
      );
}

class IpGroup {
  IpGroup({
    required this.name,
    required this.ips,
    required this.snis,
    required this.provider,
    this.keepDefaults = true,
    List<IpEntry>? entries,
  }) : entries = entries ?? _entriesFromText(ips, snis);

  final String name;
  final String ips;
  final String snis;
  final String provider;
  final bool keepDefaults;
  final List<IpEntry> entries;

  String get ipsText {
    if (entries.isNotEmpty) return entries.map((e) => e.ip).join('\n');
    return ips;
  }

  String get snisText {
    final fromEntries = entries.map((e) => e.sni).where((s) => s.isNotEmpty).toSet().toList();
    if (fromEntries.isNotEmpty) return fromEntries.join('\n');
    return snis;
  }

  IpGroup sortedBySpeed() {
    final sorted = [...entries]..sort((a, b) {
        final la = a.latencyMs <= 0 ? 1 << 30 : a.latencyMs;
        final lb = b.latencyMs <= 0 ? 1 << 30 : b.latencyMs;
        return la.compareTo(lb);
      });
    return IpGroup(
      name: name,
      ips: sorted.map((e) => e.ip).join('\n'),
      snis: snis,
      provider: provider,
      keepDefaults: keepDefaults,
      entries: sorted,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'ips': ipsText,
        'snis': snisText,
        'provider': provider,
        'keepDefaults': keepDefaults,
        'entries': entries.map((e) => e.toJson()).toList(),
      };

  factory IpGroup.fromJson(Map<String, dynamic> j) {
    final entriesRaw = j['entries'];
    List<IpEntry>? entries;
    if (entriesRaw is List) {
      entries = entriesRaw
          .whereType<Map>()
          .map((m) => IpEntry.fromJson(Map<String, dynamic>.from(m)))
          .where((e) => e.ip.isNotEmpty)
          .toList();
    }
    return IpGroup(
      name: j['name']?.toString() ?? '',
      ips: j['ips']?.toString() ?? '',
      snis: j['snis']?.toString() ?? '',
      provider: j['provider']?.toString() ?? 'cloudflare',
      keepDefaults: j['keepDefaults'] != false,
      entries: entries,
    ).sortedBySpeed();
  }

  static List<IpEntry> _entriesFromText(String ips, String snis) {
    final ipList = ips.split(RegExp(r'[\s,;]+')).where((e) => e.trim().isNotEmpty).toList();
    final sniList = snis.split(RegExp(r'[\s,;]+')).where((e) => e.trim().isNotEmpty).toList();
    return [
      for (var i = 0; i < ipList.length; i++)
        IpEntry(
          ip: ipList[i],
          sni: sniList.isEmpty ? '' : sniList[i % sniList.length],
        ),
    ];
  }
}
