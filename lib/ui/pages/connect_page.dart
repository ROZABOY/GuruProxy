import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/strings.dart';
import '../../services/egress_regions.dart';
import '../../services/tunnel_engine.dart';
import '../../theme/guru_theme.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tunnel = state.tunnel;
    final s = S(state.locale.languageCode == 'fa');
    final busy = tunnel.state == TunnelState.connecting || tunnel.state == TunnelState.disconnecting;
    final on = tunnel.state == TunnelState.connected || tunnel.state == TunnelState.connecting;
    final regionValue = EgressRegions.normalize(state.settings.egressRegion);

    final iconAsset = switch (tunnel.state) {
      TunnelState.connected => 'assets/brand/tray-connected.png',
      TunnelState.connecting || TunnelState.disconnecting => 'assets/brand/tray-connecting.png',
      _ => 'assets/brand/tray-disconnected.png',
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.appName,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: GuruTheme.sand,
                        fontSize: 26,
                      ),
                ),
                const SizedBox(height: 4),
                Text(s.tagline, style: const TextStyle(color: Color(0xFFB7C4C7), fontSize: 12.5)),
                const SizedBox(height: 12),
                SizedBox(
                  width: 280,
                  child: DropdownButtonFormField<String>(
                    initialValue: EgressRegions.choices.any((e) => e.$1 == regionValue)
                        ? regionValue
                        : EgressRegions.auto,
                    decoration: InputDecoration(
                      labelText: s.region,
                      isDense: true,
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [
                      for (final e in EgressRegions.choices)
                        DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(fontSize: 12.5))),
                    ],
                    onChanged: busy
                        ? null
                        : (v) {
                            if (v == null) return;
                            state.settings.egressRegion = v;
                            if (tunnel.state == TunnelState.connected) {
                              tunnel.stop().then((_) => tunnel.start());
                            }
                          },
                  ),
                ),
                const Spacer(),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SpeedChip(
                            icon: Icons.arrow_upward,
                            label: tunnel.uploadLabel,
                            color: const Color(0xFF7DCFB6),
                          ),
                          const SizedBox(width: 28),
                          GestureDetector(
                            onTap: () => tunnel.toggle(),
                            child: Image.asset(
                              iconAsset,
                              width: 120,
                              height: 120,
                              filterQuality: FilterQuality.high,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                on ? Icons.link : Icons.link_off,
                                size: 96,
                                color: GuruTheme.sand,
                              ),
                            ),
                          ),
                          const SizedBox(width: 28),
                          _SpeedChip(
                            icon: Icons.arrow_downward,
                            label: tunnel.downloadLabel,
                            color: GuruTheme.sand,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        on ? s.disconnect : s.connect,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                          fontSize: 12,
                          color: Color(0xFFB7C4C7),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        state.settings.applyIranQuickConnect();
                        tunnel.start();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GuruTheme.sand,
                        side: const BorderSide(color: GuruTheme.sand),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(s.iranQuick, style: const TextStyle(fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => state.go(AppSection.whiteIp),
                      child: Text(s.menuWhiteIp, style: const TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: GuruTheme.line),
                color: GuruTheme.panel,
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(s.status, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        const Spacer(),
                        _LiveBadge(state: tunnel.state),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _kv(s.region, tunnel.connectedRegion.isEmpty
                        ? EgressRegions.labelFor(regionValue)
                        : '${tunnel.connectedRegion} (exit)'),
                    _kv(
                      'Whitelist',
                      state.settings.activeGroupName.trim().isEmpty
                          ? '(none / custom)'
                          : state.settings.activeGroupName,
                    ),
                    _kv('CDN', 'CF scoped · Akamai OSSH (Se7en)'),
                    _kv(s.socks, tunnel.socksPort == 0 ? '${state.settings.localSocksPort}' : '${tunnel.socksPort}'),
                    _kv(s.http, tunnel.httpPort == 0 ? '${state.settings.localHttpPort}' : '${tunnel.httpPort}'),
                    if (tunnel.routeIp.isNotEmpty)
                      _kv('Edge', '${tunnel.routeIp}${tunnel.routeSni.isNotEmpty ? " · ${tunnel.routeSni}" : ""}'),
                    const SizedBox(height: 8),
                    Text(s.nowDoing, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                    const SizedBox(height: 4),
                    if (tunnel.statusHint.isNotEmpty)
                      Text(tunnel.statusHint, style: const TextStyle(fontSize: 12.5, color: GuruTheme.sand)),
                    const SizedBox(height: 6),
                    Expanded(
                      child: tunnel.shortActivity.isEmpty
                          ? Text(
                              s.nowDoingIdle,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF8FA3A7)),
                            )
                          : ListView.builder(
                              itemCount: tunnel.shortActivity.length,
                              itemBuilder: (context, i) {
                                final idx = tunnel.shortActivity.length - 1 - i;
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 3),
                                  child: Text(
                                    '· ${tunnel.shortActivity[idx]}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: i == 0 ? const Color(0xFFF4F1EA) : const Color(0xFF8FA3A7),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    if (tunnel.lastError.isNotEmpty)
                      Text(tunnel.lastError, style: const TextStyle(color: Colors.orangeAccent, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(width: 72, child: Text(k, style: const TextStyle(color: Color(0xFF8FA3A7), fontSize: 11.5))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }
}

class _SpeedChip extends StatelessWidget {
  const _SpeedChip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFamily: 'Consolas'),
          ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.state});
  final TunnelState state;

  @override
  Widget build(BuildContext context) {
    final (color, text, spin) = switch (state) {
      TunnelState.connected => (Colors.lightGreenAccent, 'LIVE', false),
      TunnelState.connecting => (GuruTheme.sand, 'WORKING', true),
      TunnelState.disconnecting => (Colors.orangeAccent, 'STOP', true),
      TunnelState.error => (Colors.redAccent, 'ERR', false),
      TunnelState.disconnected => (const Color(0xFF6A7A7E), 'IDLE', false),
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (spin)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 1.6, color: color),
          )
        else
          Icon(Icons.circle, size: 8, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.6)),
      ],
    );
  }
}
