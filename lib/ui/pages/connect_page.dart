import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/strings.dart';
import '../../services/egress_regions.dart';
import '../../services/tunnel_engine.dart';
import '../../theme/guru_theme.dart';

class ConnectPage extends StatelessWidget {
  const ConnectPage({super.key});

  bool get _compact =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

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

    final hero = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SpeedChip(icon: Icons.arrow_upward, label: tunnel.uploadLabel, color: const Color(0xFF7DCFB6)),
            const SizedBox(width: 20),
            Material(
              color: Colors.transparent,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () async {
                  await tunnel.toggle();
                  if (!context.mounted) return;
                  _toastConnectResult(context, tunnel, s);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Image.asset(
                    iconAsset,
                    width: _compact ? 112 : 120,
                    height: _compact ? 112 : 120,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (_, __, ___) => Icon(
                      on ? Icons.link : Icons.link_off,
                      size: 96,
                      color: GuruTheme.sand,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 20),
            _SpeedChip(icon: Icons.arrow_downward, label: tunnel.downloadLabel, color: GuruTheme.sand),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          on ? s.disconnect : s.connect,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
            fontSize: 13,
            color: Color(0xFFB7C4C7),
          ),
        ),
      ],
    );

    final regionField = DropdownButtonFormField<String>(
      initialValue: EgressRegions.choices.any((e) => e.$1 == regionValue)
          ? regionValue
          : EgressRegions.auto,
      decoration: InputDecoration(
        labelText: s.region,
        isDense: true,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: [
        for (final e in EgressRegions.choices)
          DropdownMenuItem(value: e.$1, child: Text(e.$2, style: const TextStyle(fontSize: 13))),
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
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonal(
          onPressed: () async {
            state.settings.applyIranQuickConnect();
            await tunnel.start();
            if (!context.mounted) return;
            _toastConnectResult(context, tunnel, s);
          },
          child: Text(s.iranQuick),
        ),
        OutlinedButton(
          onPressed: () => state.go(AppSection.whiteIp),
          child: Text(s.menuWhiteIp),
        ),
        if (tunnel.isActive)
          OutlinedButton(
            onPressed: () => tunnel.stop(),
            child: Text(s.stopConn),
          ),
      ],
    );

    final status = _StatusPanel(s: s, state: state, regionValue: regionValue);

    if (_compact) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            s.tagline,
            style: const TextStyle(color: Color(0xFFB7C4C7), fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 16),
          regionField,
          const SizedBox(height: 28),
          hero,
          const SizedBox(height: 20),
          actions,
          const SizedBox(height: 20),
          status,
        ],
      );
    }

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
                SizedBox(width: 280, child: regionField),
                const Spacer(),
                Center(child: hero),
                const Spacer(),
                actions,
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: status),
        ],
      ),
    );
  }
}

void _toastConnectResult(BuildContext context, TunnelEngine tunnel, S s) {
  final msg = switch (tunnel.state) {
    TunnelState.connecting => s.connecting,
    TunnelState.connected => s.connected,
    TunnelState.error => tunnel.lastError.isEmpty ? 'Connect failed — check Log tab' : tunnel.lastError,
    TunnelState.disconnected => s.disconnected,
    TunnelState.disconnecting => 'Stopping…',
  };
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(msg),
      duration: Duration(seconds: tunnel.state == TunnelState.error ? 6 : 2),
      backgroundColor: tunnel.state == TunnelState.error ? Colors.red.shade800 : null,
    ),
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.s, required this.state, required this.regionValue});
  final S s;
  final AppState state;
  final String regionValue;

  @override
  Widget build(BuildContext context) {
    final tunnel = state.tunnel;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: GuruTheme.line),
        color: GuruTheme.panel,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(s.status, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const Spacer(),
                _LiveBadge(state: tunnel.state),
              ],
            ),
            const SizedBox(height: 10),
            _kv(
              s.region,
              tunnel.connectedRegion.isEmpty
                  ? EgressRegions.labelFor(regionValue)
                  : '${tunnel.connectedRegion} (exit)',
            ),
            _kv(
              'Whitelist',
              state.settings.activeGroupName.trim().isEmpty
                  ? '(none / custom)'
                  : state.settings.activeGroupName,
            ),
            _kv(
              s.protocols,
              state.settings.autoProtocol
                  ? s.autoProtocolOn
                  : '${state.settings.resolveTunnelProtocols().length} selected',
            ),
            _kv('Listen', switch (state.settings.proxyListenMode) {
              'socks' => 'SOCKS only',
              'http' => 'HTTP only',
              _ => 'Mixed SOCKS+HTTP',
            }),
            if (state.settings.proxyListenMode != 'http')
              _kv(s.socks, tunnel.socksPort == 0 ? '${state.settings.localSocksPort}' : '${tunnel.socksPort}'),
            if (state.settings.proxyListenMode != 'socks')
              _kv(s.http, tunnel.httpPort == 0 ? '${state.settings.localHttpPort}' : '${tunnel.httpPort}'),
            _kv(
              'Profile',
              state.settings.connectionProfile == 'stable'
                  ? (state.settings.redundantTunnel ? 'Stable + 2 tunnels' : 'Stable')
                  : 'Normal',
            ),
            if (tunnel.routeIp.isNotEmpty)
              _kv('Edge', '${tunnel.routeIp}${tunnel.routeSni.isNotEmpty ? " · ${tunnel.routeSni}" : ""}'),
            const SizedBox(height: 10),
            Text(s.nowDoing, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            const SizedBox(height: 4),
            if (tunnel.statusHint.isNotEmpty)
              Text(tunnel.statusHint, style: const TextStyle(fontSize: 12.5, color: GuruTheme.sand)),
            const SizedBox(height: 6),
            if (tunnel.shortActivity.isEmpty)
              Text(s.nowDoingIdle, style: const TextStyle(fontSize: 11, color: Color(0xFF8FA3A7)))
            else
              ...[
                for (var i = 0; i < tunnel.shortActivity.length && i < 6; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '· ${tunnel.shortActivity[tunnel.shortActivity.length - 1 - i]}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: i == 0 ? const Color(0xFFF4F1EA) : const Color(0xFF8FA3A7),
                      ),
                    ),
                  ),
              ],
            if (tunnel.lastError.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(tunnel.lastError, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 88, child: Text(k, style: const TextStyle(color: Color(0xFF8FA3A7), fontSize: 12))),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 12.5))),
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
      width: 84,
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
