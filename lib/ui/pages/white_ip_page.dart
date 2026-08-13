import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/strings.dart';
import '../../services/edge_scanner.dart';
import '../../services/ip_list_csv.dart';
import '../../services/settings_store.dart';
import '../../theme/guru_theme.dart';

class WhiteIpPage extends StatefulWidget {
  const WhiteIpPage({super.key});

  @override
  State<WhiteIpPage> createState() => _WhiteIpPageState();
}

class _WhiteIpPageState extends State<WhiteIpPage> {
  late final EdgeScanner _scanner;
  String _provider = 'cloudflare';
  ScanMethod _method = ScanMethod.tlsSni;
  bool _keepDefaults = true;
  bool _scanRanges = true;
  bool _sniOverride = true;
  String? _expandedGroup;

  final _sniCtrl = TextEditingController(text: 'www.cloudflare.com\ncdnjs.cloudflare.com');
  final _manualCtrl = TextEditingController();
  final _groupNameCtrl = TextEditingController();
  final _maxCtrl = TextEditingController(text: '200');
  final _concCtrl = TextEditingController(text: '16');
  final _timeoutCtrl = TextEditingController(text: '4000');
  final _perCidrCtrl = TextEditingController(text: '6');

  @override
  void initState() {
    super.initState();
    _scanner = EdgeScanner();
    _scanner.addListener(_onScan);
    final settings = context.read<AppState>().settings;
    if (settings.customIps.trim().isNotEmpty) {
      _manualCtrl.text = settings.customIps;
    }
    if (settings.customSnis.trim().isNotEmpty) {
      _sniCtrl.text = settings.customSnis;
    }
    _provider = settings.cdnProvider;
    _keepDefaults = settings.autoFindIpAndSni;
    _sniOverride = settings.sniOverrideEnabled;
  }

  void _onScan() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _scanner.removeListener(_onScan);
    _scanner.dispose();
    _sniCtrl.dispose();
    _manualCtrl.dispose();
    _groupNameCtrl.dispose();
    _maxCtrl.dispose();
    _concCtrl.dispose();
    _timeoutCtrl.dispose();
    _perCidrCtrl.dispose();
    super.dispose();
  }

  List<String> get _snis =>
      _sniCtrl.text.split(RegExp(r'[\s,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<String> get _manualIps =>
      _manualCtrl.text.split(RegExp(r'[\s,;]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  List<IpEntry> _entriesFromHealthy() {
    return _scanner.healthy
        .take(32)
        .map((h) => IpEntry(ip: h.ip, latencyMs: h.latencyMs, sni: h.sni.isNotEmpty ? h.sni : (_snis.isNotEmpty ? _snis.first : '')))
        .toList()
      ..sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
  }

  Future<void> _startScan() async {
    final max = int.tryParse(_maxCtrl.text) ?? 200;
    final conc = int.tryParse(_concCtrl.text) ?? 16;
    final timeout = int.tryParse(_timeoutCtrl.text) ?? 4000;
    final perCidr = int.tryParse(_perCidrCtrl.text) ?? 6;

    if (!_scanRanges && _manualIps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paste IPs first, or enable “Also scan CDN ranges”.')),
      );
      return;
    }

    if (!_scanRanges) {
      await _scanner.scanManualOnly(
        ips: _manualIps,
        snis: _snis,
        method: _method,
        concurrency: conc,
        timeoutMs: timeout,
      );
      return;
    }

    await _scanner.scan(
      provider: _provider,
      snis: _snis,
      method: _method,
      manualIps: _manualIps,
      maxCandidates: max.clamp(10, 2000),
      concurrency: conc.clamp(1, 64),
      perCidr: perCidr.clamp(1, 32),
      timeoutMs: timeout.clamp(500, 15000),
    );
  }

  Future<void> _runAutoFind() async {
    final state = context.read<AppState>();
    setState(() {
      _method = ScanMethod.tlsSni;
      _scanRanges = true;
      _keepDefaults = true;
      _provider = state.settings.cdnProvider;
      _sniCtrl.text = switch (_provider) {
        'cloudflare' => 'www.cloudflare.com\ncdnjs.cloudflare.com',
        'google' => 'www.gstatic.com\nfonts.googleapis.com',
        'fastly' => 'pypi.org\nwww.python.org',
        _ => 'a248.e.akamai.net\na.akamaized.net\na.akamaihd.net',
      };
    });
    await _scanner.scan(
      provider: _provider,
      snis: _snis,
      method: ScanMethod.tlsSni,
      maxCandidates: 120,
      concurrency: 20,
      perCidr: 5,
      timeoutMs: 3500,
    );
    if (!mounted) return;
    if (_scanner.healthy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Auto-find found no healthy edges. Try again or use Iran Quick.')),
      );
      return;
    }
    _applyHealthy(toGroup: false);
    state.settings.autoFindIpAndSni = true;
  }

  Future<void> _recheckGroup(IpGroup group) async {
    final conc = int.tryParse(_concCtrl.text) ?? 16;
    final timeout = int.tryParse(_timeoutCtrl.text) ?? 4000;
    final snis = group.snisText.split(RegExp(r'[\s,;]+')).where((e) => e.isNotEmpty).toList();
    if (snis.isEmpty) snis.addAll(_snis);
    await _scanner.scanManualOnly(
      ips: group.ipsText.split(RegExp(r'[\s,;]+')).where((e) => e.isNotEmpty).toList(),
      snis: snis,
      method: _method,
      concurrency: conc,
      timeoutMs: timeout,
    );
    if (!mounted || _scanner.healthy.isEmpty) return;
    final entries = _entriesFromHealthy();
    final updated = IpGroup(
      name: group.name,
      ips: entries.map((e) => e.ip).join('\n'),
      snis: group.snisText,
      provider: group.provider,
      keepDefaults: group.keepDefaults,
      entries: entries,
    ).sortedBySpeed();
    context.read<AppState>().settings.upsertIpGroup(updated);
    _manualCtrl.text = updated.ipsText;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rechecked “${group.name}” — sorted by speed')),
    );
  }

  void _applyHealthy({required bool toGroup}) {
    final state = context.read<AppState>();
    final entries = _entriesFromHealthy();
    if (entries.isEmpty && _manualIps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No IPs to apply.')));
      return;
    }
    final useEntries = entries.isNotEmpty
        ? entries
        : _manualIps
            .map((ip) => IpEntry(ip: ip, sni: _snis.isNotEmpty ? _snis.first : ''))
            .toList();
    final ipText = useEntries.map((e) => e.ip).join('\n');
    final snis = _sniOverride ? _snis.join('\n') : '';

    state.settings.customIps = ipText;
    state.settings.customSnis = snis;
    state.settings.cdnProvider = 'cloudflare';
    state.settings.protocolMode = 'cdn_fronting';
    state.settings.autoFindIpAndSni = _keepDefaults;
    state.settings.sniOverrideEnabled = _sniOverride;

    if (toGroup) {
      final name = _groupNameCtrl.text.trim();
      if (name.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a group name (e.g. home, office).')),
        );
        return;
      }
      state.settings.upsertIpGroup(IpGroup(
        name: name,
        ips: ipText,
        snis: snis.isNotEmpty ? snis : _snis.join('\n'),
        provider: 'cloudflare',
        keepDefaults: _keepDefaults,
        entries: useEntries,
      ));
      state.settings.activeGroupName = name;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved group “$name” (speed-ordered).')));
    } else {
      state.settings.activeGroupName = state.settings.activeGroupName.isEmpty ? 'custom' : state.settings.activeGroupName;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Applied ${useEntries.length} Cloudflare IPs (fastest first). '
            'Ping/TLS-ok ≠ guaranteed Psiphon front.',
          ),
        ),
      );
    }
    state.go(AppSection.connect);
  }

  Future<void> _importCsv() async {
    final state = context.read<AppState>();
    String? raw;
    String sourceName = 'imported';

    if (Platform.isWindows) {
      final path = await _windowsPickOpenCsv();
      if (path == null || path.isEmpty) return;
      raw = await File(path).readAsString();
      sourceName = path.split(Platform.pathSeparator).last;
    } else {
      final pasted = await _pasteCsvDialog();
      if (pasted == null) return;
      raw = pasted;
      sourceName = 'pasted';
    }
    if (!mounted) return;
    final rows = IpListCsv.parse(raw);
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No IPs found in CSV (need header ip,latency_ms,ttl,message).')),
      );
      return;
    }

    final name = _groupNameCtrl.text.trim().isNotEmpty
        ? _groupNameCtrl.text.trim()
        : (sourceName.replaceAll(RegExp(r'\.(csv|txt)$', caseSensitive: false), '').trim().isEmpty
            ? 'imported'
            : sourceName.replaceAll(RegExp(r'\.(csv|txt)$', caseSensitive: false), ''));

    final entries = rows
        .map((r) => IpEntry(
              ip: r.ip,
              latencyMs: r.latencyMs,
              sni: _snis.isNotEmpty ? _snis.first : 'www.cloudflare.com',
            ))
        .toList();
    final ipText = entries.map((e) => e.ip).join('\n');
    final snis = _sniOverride ? _snis.join('\n') : 'www.cloudflare.com\ncdnjs.cloudflare.com';

    state.settings.upsertIpGroup(IpGroup(
      name: name,
      ips: ipText,
      snis: snis,
      provider: 'cloudflare',
      keepDefaults: _keepDefaults,
      entries: entries,
    ));
    state.settings.applyIpGroup(state.settings.ipGroups.firstWhere((g) => g.name == name));
    setState(() {
      _manualCtrl.text = ipText;
      _sniCtrl.text = snis;
      _provider = 'cloudflare';
      _groupNameCtrl.text = name;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Imported ${entries.length} IPs → group “$name” (active whitelist).')),
    );
  }

  Future<String?> _windowsPickOpenCsv() async {
    final ps = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        "Add-Type -AssemblyName System.Windows.Forms; "
            "\$f = New-Object System.Windows.Forms.OpenFileDialog; "
            "\$f.Filter = 'CSV (*.csv;*.txt)|*.csv;*.txt|All|*.*'; "
            "\$f.Title = 'Import IP list CSV'; "
            "if (\$f.ShowDialog() -eq 'OK') { \$f.FileName }",
      ],
      runInShell: true,
    );
    final out = (ps.stdout as String).trim();
    return out.isEmpty ? null : out;
  }

  Future<String?> _pasteCsvDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paste CSV'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'ip,latency_ms,ttl,message\n104.16.7.36,22,50,ping ok',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv() async {
    final state = context.read<AppState>();
    final groupName = state.settings.activeGroupName.trim();
    final groups = state.settings.ipGroups;

    List<ParsedIpRow> rows;
    IpGroup? active;
    if (groupName.isNotEmpty) {
      for (final g in groups) {
        if (g.name.toLowerCase() == groupName.toLowerCase()) {
          active = g;
          break;
        }
      }
    }
    if (active != null && active.entries.isNotEmpty) {
      rows = active.entries
          .map((e) => ParsedIpRow(ip: e.ip, latencyMs: e.latencyMs, ttl: 50, message: 'ping ok'))
          .toList();
    } else if (_scanner.healthy.isNotEmpty) {
      rows = _scanner.healthy
          .map((h) => ParsedIpRow(ip: h.ip, latencyMs: h.latencyMs, ttl: 50, message: h.message))
          .toList();
    } else {
      rows = _manualIps
          .map((ip) => ParsedIpRow(ip: ip, latencyMs: 0, ttl: null, message: 'exported'))
          .toList();
    }
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nothing to export.')));
      return;
    }

    final csv = IpListCsv.export(rows: rows);
    final suggested = '${groupName.isEmpty ? "guruproxy-ips" : groupName}.csv';

    String? out;
    if (Platform.isWindows) {
      out = await _windowsPickSaveCsv(suggested);
      if (out == null) return;
      if (!out.toLowerCase().endsWith('.csv')) out = '$out.csv';
    } else {
      final dir = await getApplicationDocumentsDirectory();
      out = '${dir.path}${Platform.pathSeparator}$suggested';
    }
    await File(out).writeAsString(csv);
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported ${rows.length} IPs → $out (also copied)')),
    );
  }

  Future<String?> _windowsPickSaveCsv(String fileName) async {
    final ps = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        "Add-Type -AssemblyName System.Windows.Forms; "
            "\$f = New-Object System.Windows.Forms.SaveFileDialog; "
            "\$f.Filter = 'CSV (*.csv)|*.csv'; "
            "\$f.FileName = '$fileName'; "
            "\$f.Title = 'Export IP list'; "
            "if (\$f.ShowDialog() -eq 'OK') { \$f.FileName }",
      ],
      runInShell: true,
    );
    final out = (ps.stdout as String).trim();
    return out.isEmpty ? null : out;
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.locale.languageCode == 'fa');
    final groups = state.settings.ipGroups;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: ListView(
              children: [
                Text(s.menuWhiteIp, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(s.helpScan, style: const TextStyle(fontSize: 11.5, color: Color(0xFF9BB0B4))),
                const SizedBox(height: 6),
                Text(
                  'Active whitelist: ${state.settings.activeGroupName.trim().isEmpty ? "(none)" : state.settings.activeGroupName}'
                  ' · CF scoped + Akamai OSSH fallback',
                  style: const TextStyle(fontSize: 12, color: GuruTheme.sand, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _scanner.running ? null : _importCsv,
                      style: _squareOut(),
                      icon: const Icon(Icons.upload_file, size: 16),
                      label: const Text('Import CSV'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: _scanner.running ? null : _exportCsv,
                      style: _squareOut(),
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export CSV'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _provider,
                        decoration: _dense(s.provider),
                        items: const [
                          DropdownMenuItem(value: 'cloudflare', child: Text('Cloudflare')),
                          DropdownMenuItem(value: 'google', child: Text('Google CDN')),
                          DropdownMenuItem(value: 'akamai', child: Text('Akamai')),
                          DropdownMenuItem(value: 'fastly', child: Text('Fastly')),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            _provider = v;
                            _sniCtrl.text = switch (v) {
                              'cloudflare' => 'www.cloudflare.com\ncdnjs.cloudflare.com',
                              'google' => 'www.gstatic.com\nfonts.googleapis.com',
                              'fastly' => 'pypi.org\nwww.python.org',
                              _ => 'a248.e.akamai.net\na.akamaized.net',
                            };
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<ScanMethod>(
                        initialValue: _method,
                        decoration: _dense(s.checkMethod),
                        items: [
                          DropdownMenuItem(value: ScanMethod.tlsSni, child: Text(s.methodTls)),
                          DropdownMenuItem(value: ScanMethod.tcp443, child: Text(s.methodTcp)),
                          DropdownMenuItem(value: ScanMethod.ping, child: Text(s.methodPing)),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _method = v);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sniCtrl,
                  maxLines: 2,
                  enabled: _sniOverride,
                  decoration: _dense(s.sniOverrideList),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _manualCtrl,
                  maxLines: 4,
                  decoration: _dense('${s.manualIps} — paste your own'),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: Text(s.scanRanges),
                      selected: _scanRanges,
                      onSelected: (v) => setState(() => _scanRanges = v),
                    ),
                    FilterChip(
                      label: Text(s.autoFind),
                      selected: _keepDefaults,
                      onSelected: (v) => setState(() => _keepDefaults = v),
                    ),
                    FilterChip(
                      label: Text(s.sniOverride),
                      selected: _sniOverride,
                      onSelected: (v) => setState(() => _sniOverride = v),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _numField(_maxCtrl, s.maxCandidates, 70),
                    const SizedBox(width: 6),
                    _numField(_concCtrl, s.concurrency, 70),
                    const SizedBox(width: 6),
                    _numField(_timeoutCtrl, s.timeoutMs, 80),
                    const SizedBox(width: 6),
                    _numField(_perCidrCtrl, s.perCidr, 70),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilledButton(
                      onPressed: _scanner.running ? null : _startScan,
                      style: _squareFill(GuruTheme.sand, GuruTheme.ink),
                      child: Text(s.scanStart),
                    ),
                    FilledButton(
                      onPressed: _scanner.running ? null : _runAutoFind,
                      style: _squareFill(GuruTheme.teal, const Color(0xFFF4F1EA)),
                      child: Text(s.autoFindNow),
                    ),
                    OutlinedButton(
                      onPressed: _scanner.running && !_scanner.paused ? _scanner.pause : null,
                      style: _squareOut(),
                      child: Text(s.scanPause),
                    ),
                    OutlinedButton(
                      onPressed: _scanner.running && _scanner.paused ? _scanner.resume : null,
                      style: _squareOut(),
                      child: Text(s.scanResume),
                    ),
                    OutlinedButton(
                      onPressed: _scanner.running ? _scanner.stop : null,
                      style: _squareOut(),
                      child: Text(s.scanStop),
                    ),
                    FilledButton(
                      onPressed: () => _applyHealthy(toGroup: false),
                      style: _squareFill(GuruTheme.teal, const Color(0xFFF4F1EA)),
                      child: Text(s.applyEdges),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(_scanner.status, style: const TextStyle(fontSize: 12, color: GuruTheme.sand)),
                const SizedBox(height: 10),
                Text(s.groups, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _groupNameCtrl,
                        decoration: _dense(s.groupName),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () => _applyHealthy(toGroup: true),
                      style: _squareFill(GuruTheme.sand, GuruTheme.ink),
                      child: Text(s.saveGroup),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (groups.isEmpty)
                  Text(s.noGroups, style: const TextStyle(fontSize: 12, color: Color(0xFF8FA3A7)))
                else
                  ...groups.map((g) => _groupTile(g, s, state)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: GuruTheme.line),
                color: GuruTheme.panel,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                    child: Row(
                      children: [
                        Text(
                          '${s.healthy}: ${_scanner.healthy.length}',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: _scanner.healthy.isEmpty
                              ? null
                              : () {
                                  _scanner.healthy.sort((a, b) => a.latencyMs.compareTo(b.latencyMs));
                                  setState(() {});
                                },
                          child: Text(s.sortBySpeed, style: const TextStyle(fontSize: 11)),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _scanner.healthy.length,
                      itemBuilder: (context, i) {
                        final hit = _scanner.healthy[i];
                        return ListTile(
                          dense: true,
                          leading: Text('#${i + 1}', style: const TextStyle(fontSize: 11, color: GuruTheme.sand)),
                          title: Text(hit.ip, style: const TextStyle(fontFamily: 'Consolas', fontSize: 13)),
                          subtitle: Text(
                            '${hit.latencyMs} ms · ${hit.message}'
                            '${hit.sni.isNotEmpty ? " · ${hit.sni}" : ""}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () {
                            final cur = _manualCtrl.text.trim();
                            if (!cur.contains(hit.ip)) {
                              _manualCtrl.text = cur.isEmpty ? hit.ip : '$cur\n${hit.ip}';
                              setState(() {});
                            }
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupTile(IpGroup g, S s, AppState state) {
    final sorted = g.sortedBySpeed();
    final open = _expandedGroup == g.name;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: GuruTheme.panel,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: GuruTheme.line),
      ),
      child: Column(
        children: [
          ListTile(
            dense: true,
            title: Text(sorted.name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
              '${sorted.provider} · ${sorted.entries.length} IPs'
              '${sorted.entries.isNotEmpty && sorted.entries.first.latencyMs > 0 ? " · best ${sorted.entries.first.latencyMs}ms" : ""}'
              '${sorted.keepDefaults ? " · auto-find" : ""}',
              style: const TextStyle(fontSize: 11),
            ),
            trailing: Wrap(
              spacing: 0,
              children: [
                IconButton(
                  tooltip: s.expandGroup,
                  icon: Icon(open ? Icons.expand_less : Icons.expand_more, size: 20),
                  onPressed: () => setState(() => _expandedGroup = open ? null : g.name),
                ),
                TextButton(
                  onPressed: _scanner.running ? null : () => _recheckGroup(g),
                  child: Text(s.recheckGroup, style: const TextStyle(fontSize: 11)),
                ),
                TextButton(
                  onPressed: () {
                    final ordered = g.sortedBySpeed();
                    state.settings.upsertIpGroup(ordered);
                    state.settings.applyIpGroup(ordered);
                    _manualCtrl.text = ordered.ipsText;
                    _sniCtrl.text = ordered.snisText;
                    setState(() {
                      _provider = ordered.provider;
                      _keepDefaults = ordered.keepDefaults;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${s.loadedGroup} “${ordered.name}” (${s.sortBySpeed})')),
                    );
                    state.go(AppSection.connect);
                  },
                  child: Text(s.useGroup),
                ),
                IconButton(
                  tooltip: s.deleteGroup,
                  onPressed: () => state.settings.deleteIpGroup(g.name),
                  icon: const Icon(Icons.delete_outline, size: 18),
                ),
              ],
            ),
          ),
          if (open)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: [
                  for (var i = 0; i < sorted.entries.length; i++)
                    Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text('#${i + 1}', style: const TextStyle(fontSize: 11, color: GuruTheme.sand)),
                        ),
                        Expanded(
                          child: Text(
                            sorted.entries[i].ip,
                            style: const TextStyle(fontFamily: 'Consolas', fontSize: 12),
                          ),
                        ),
                        Text(
                          sorted.entries[i].latencyMs > 0 ? '${sorted.entries[i].latencyMs} ms' : '—',
                          style: const TextStyle(fontSize: 11, color: Color(0xFF8FA3A7)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _numField(TextEditingController c, String label, double w) {
    return SizedBox(
      width: w,
      child: TextField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: _dense(label),
      ),
    );
  }

  InputDecoration _dense(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      );

  ButtonStyle _squareFill(Color bg, Color fg) => FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );

  ButtonStyle _squareOut() => OutlinedButton.styleFrom(
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      );
}
