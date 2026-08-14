import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/strings.dart';
import '../../services/protocol_catalog.dart';
import '../../theme/guru_theme.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late TextEditingController _ips;
  late TextEditingController _snis;
  late TextEditingController _region;
  late TextEditingController _socks;
  late TextEditingController _http;
  late TextEditingController _timeout;
  late TextEditingController _upstream;
  late TextEditingController _upstreamUser;
  late TextEditingController _upstreamPass;
  late TextEditingController _blockedApps;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().settings;
    _ips = TextEditingController(text: settings.customIps);
    _snis = TextEditingController(text: settings.customSnis);
    _region = TextEditingController(text: settings.egressRegion);
    _socks = TextEditingController(text: '${settings.localSocksPort}');
    _http = TextEditingController(text: '${settings.localHttpPort}');
    _timeout = TextEditingController(text: '${settings.establishTimeoutSec}');
    _upstream = TextEditingController(text: settings.upstreamProxyUrl);
    _upstreamUser = TextEditingController(text: settings.upstreamProxyUser);
    _upstreamPass = TextEditingController(text: settings.upstreamProxyPass);
    _blockedApps = TextEditingController(text: settings.blockedApps.join('\n'));
  }

  @override
  void dispose() {
    _ips.dispose();
    _snis.dispose();
    _region.dispose();
    _socks.dispose();
    _http.dispose();
    _timeout.dispose();
    _upstream.dispose();
    _upstreamUser.dispose();
    _upstreamPass.dispose();
    _blockedApps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final settings = state.settings;
    final s = S(state.locale.languageCode == 'fa');
    final isCdn = settings.protocolMode == 'cdn_fronting';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(s.menuSettings, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: settings.protocolMode,
          decoration: InputDecoration(labelText: s.mode, border: const OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'cdn_fronting', child: Text('CDN Fronting')),
            DropdownMenuItem(value: 'direct', child: Text('Direct / mixed')),
            DropdownMenuItem(value: 'auto', child: Text('Auto')),
          ],
          onChanged: (v) {
            if (v != null) setState(() => settings.protocolMode = v);
          },
        ),
        const SizedBox(height: 12),
        Text(s.protocols, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.autoProtocol),
          subtitle: Text(s.autoProtocolHint, style: const TextStyle(fontSize: 11)),
          value: settings.autoProtocol,
          activeThumbColor: GuruTheme.sand,
          onChanged: (v) => setState(() => settings.autoProtocol = v),
        ),
        Text(s.protocolChecksHint, style: const TextStyle(fontSize: 11, color: Color(0xFF8FA3A7))),
        const SizedBox(height: 4),
        ...ProtocolCatalog.options.map((opt) {
          final on = settings.enabledProtocols.contains(opt.id);
          return CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: on,
            enabled: !settings.autoProtocol,
            activeColor: GuruTheme.sand,
            title: Text(opt.label, style: const TextStyle(fontSize: 13)),
            subtitle: Text(opt.hint, style: const TextStyle(fontSize: 10.5, color: Color(0xFF8FA3A7))),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: settings.autoProtocol
                ? null
                : (v) => setState(() => settings.setProtocolEnabled(opt.id, v ?? false)),
          );
        }),
        if (settings.autoProtocol)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '${s.autoProtocolOn}: ${settings.resolveTunnelProtocols().join(', ')}',
              style: const TextStyle(fontSize: 10.5, color: Color(0xFF7DCFB6)),
            ),
          ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: settings.cdnProvider,
          decoration: InputDecoration(labelText: s.provider, border: const OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'cloudflare', child: Text('Cloudflare (1st)')),
            DropdownMenuItem(value: 'google', child: Text('Google CDN (2nd)')),
            DropdownMenuItem(value: 'akamai', child: Text('Akamai (3rd)')),
            DropdownMenuItem(value: 'fastly', child: Text('Fastly')),
          ],
          onChanged: (v) {
            if (v != null) settings.cdnProvider = v;
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _region,
          decoration: InputDecoration(
            labelText: '${s.region} (auto / US / DE / …)',
            hintText: 'auto',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: (() {
            final v = settings.egressRegion.trim().isEmpty ? 'auto' : settings.egressRegion;
            const known = {
              'auto', 'US', 'GB', 'DE', 'NL', 'FR', 'CA', 'JP', 'SG', 'IN', 'AU', 'BR', 'ES', 'IT', 'SE', 'CH'
            };
            return known.contains(v) ? v : 'auto';
          })(),
          decoration: InputDecoration(labelText: s.region, border: const OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Auto (best available)')),
            DropdownMenuItem(value: 'US', child: Text('United States')),
            DropdownMenuItem(value: 'GB', child: Text('United Kingdom')),
            DropdownMenuItem(value: 'DE', child: Text('Germany')),
            DropdownMenuItem(value: 'NL', child: Text('Netherlands')),
            DropdownMenuItem(value: 'FR', child: Text('France')),
            DropdownMenuItem(value: 'CA', child: Text('Canada')),
            DropdownMenuItem(value: 'JP', child: Text('Japan')),
            DropdownMenuItem(value: 'SG', child: Text('Singapore')),
            DropdownMenuItem(value: 'IN', child: Text('India')),
            DropdownMenuItem(value: 'AU', child: Text('Australia')),
            DropdownMenuItem(value: 'BR', child: Text('Brazil')),
            DropdownMenuItem(value: 'ES', child: Text('Spain')),
            DropdownMenuItem(value: 'IT', child: Text('Italy')),
            DropdownMenuItem(value: 'SE', child: Text('Sweden')),
            DropdownMenuItem(value: 'CH', child: Text('Switzerland')),
          ],
          onChanged: (v) {
            if (v == null) return;
            settings.egressRegion = v;
            _region.text = v;
          },
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: settings.proxyListenMode,
          decoration: InputDecoration(labelText: s.proxyListenMode, border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: 'mixed', child: Text(s.proxyListenMixed)),
            DropdownMenuItem(value: 'socks', child: Text(s.proxyListenSocks)),
            DropdownMenuItem(value: 'http', child: Text(s.proxyListenHttp)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => settings.proxyListenMode = v);
          },
        ),
        const SizedBox(height: 4),
        Text(s.proxyListenHint, style: const TextStyle(fontSize: 11, color: Color(0xFF8FA3A7))),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _socks,
                keyboardType: TextInputType.number,
                enabled: settings.proxyListenMode != 'http',
                decoration: InputDecoration(labelText: s.socksPort, border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _http,
                keyboardType: TextInputType.number,
                enabled: settings.proxyListenMode != 'socks',
                decoration: InputDecoration(labelText: s.httpPort, border: const OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: settings.connectionProfile,
          decoration: InputDecoration(labelText: s.connectionProfile, border: const OutlineInputBorder()),
          items: [
            DropdownMenuItem(value: 'normal', child: Text(s.connectionNormal)),
            DropdownMenuItem(value: 'stable', child: Text(s.connectionStable)),
          ],
          onChanged: (v) {
            if (v != null) setState(() => settings.connectionProfile = v);
          },
        ),
        const SizedBox(height: 4),
        Text(s.connectionProfileHint, style: const TextStyle(fontSize: 11, color: Color(0xFF8FA3A7))),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.redundantTunnel),
          subtitle: Text(s.redundantTunnelHint, style: const TextStyle(fontSize: 11)),
          value: settings.redundantTunnel,
          activeThumbColor: GuruTheme.sand,
          onChanged: settings.connectionProfile == 'stable'
              ? (v) => settings.redundantTunnel = v
              : null,
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _timeout,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: s.timeoutSec, border: const OutlineInputBorder()),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.autoFind),
          subtitle: Text(s.autoFindHint, style: const TextStyle(fontSize: 11)),
          value: settings.autoFindIpAndSni,
          activeThumbColor: GuruTheme.sand,
          onChanged: (v) => settings.autoFindIpAndSni = v,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.sniOverride),
          subtitle: Text(s.sniOverrideHint, style: const TextStyle(fontSize: 11)),
          value: settings.sniOverrideEnabled,
          activeThumbColor: GuruTheme.sand,
          onChanged: (v) => settings.sniOverrideEnabled = v,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(s.beastMode),
          subtitle: Text(s.beastModeHint, style: const TextStyle(fontSize: 11)),
          value: settings.beastMode,
          activeThumbColor: GuruTheme.sand,
          onChanged: (v) => settings.beastMode = v,
        ),
        const SizedBox(height: 6),
        Text(s.upstreamProxy, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(
          isCdn ? s.upstreamIgnoredCdn : s.upstreamHint,
          style: TextStyle(fontSize: 11, color: isCdn ? Colors.orangeAccent : const Color(0xFF8FA3A7)),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _upstream,
          enabled: !isCdn,
          decoration: InputDecoration(
            labelText: s.upstreamUrl,
            hintText: 'http://127.0.0.1:7890',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _upstreamUser,
                enabled: !isCdn,
                decoration: InputDecoration(labelText: s.upstreamUser, border: const OutlineInputBorder()),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _upstreamPass,
                enabled: !isCdn,
                obscureText: true,
                decoration: InputDecoration(labelText: s.upstreamPass, border: const OutlineInputBorder()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ips,
          maxLines: 4,
          decoration: InputDecoration(labelText: s.customIps, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _snis,
          maxLines: 2,
          enabled: settings.sniOverrideEnabled,
          decoration: InputDecoration(labelText: s.sniOverrideList, border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 14),
        Text(s.blockedApps, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        Text(s.blockedAppsHint, style: const TextStyle(fontSize: 11, color: Color(0xFF8FA3A7))),
        const SizedBox(height: 6),
        TextField(
          controller: _blockedApps,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: s.blockedAppsList,
            hintText: 'photoshop.exe\ncoreldraw.exe\nsteam.exe',
            border: const OutlineInputBorder(),
            helperText: 'Saved exclude list (SOCKS cannot force it — same limit as Se7en)',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final name in const ['photoshop.exe', 'steam.exe', 'discord.exe', 'spotify.exe'])
              ActionChip(
                label: Text(name, style: const TextStyle(fontSize: 11)),
                onPressed: () {
                  final cur = _blockedApps.text.trim();
                  if (cur.toLowerCase().contains(name)) return;
                  _blockedApps.text = cur.isEmpty ? name : '$cur\n$name';
                  setState(() {});
                },
              ),
          ],
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () {
              settings.customIps = _ips.text;
              settings.customSnis = _snis.text;
              settings.egressRegion = _region.text.trim().isEmpty ? 'US' : _region.text.trim();
              settings.localSocksPort = int.tryParse(_socks.text.trim()) ?? 17888;
              settings.localHttpPort = int.tryParse(_http.text.trim()) ?? 17889;
              settings.establishTimeoutSec = int.tryParse(_timeout.text.trim()) ?? 120;
              settings.upstreamProxyUrl = _upstream.text;
              settings.upstreamProxyUser = _upstreamUser.text;
              settings.upstreamProxyPass = _upstreamPass.text;
              settings.blockedApps = _blockedApps.text
                  .split(RegExp(r'[\s,;]+'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList();
              _socks.text = '${settings.localSocksPort}';
              _http.text = '${settings.localHttpPort}';
              _timeout.text = '${settings.establishTimeoutSec}';
              _blockedApps.text = settings.blockedApps.join('\n');
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.save)));
            },
            style: FilledButton.styleFrom(
              backgroundColor: GuruTheme.sand,
              foregroundColor: GuruTheme.ink,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            ),
            child: Text(s.save),
          ),
        ),
      ],
    );
  }
}
