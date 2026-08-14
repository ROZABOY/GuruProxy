import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'asset_bootstrap.dart';
import 'egress_regions.dart';
import 'fronting_dial.dart';
import 'network_credentials.dart';
import 'settings_store.dart';

enum TunnelState { disconnected, connecting, connected, disconnecting, error }

class DialAttempt {
  DialAttempt({
    required this.ip,
    required this.sni,
    required this.protocol,
    required this.overrideId,
    required this.at,
    this.result = 'trying',
  });

  final String ip;
  final String sni;
  final String protocol;
  final String overrideId;
  final DateTime at;
  String result; // trying | ok | fail
}

class TunnelEngine extends ChangeNotifier {
  TunnelEngine({required this.settings, required this.bootstrap});

  final SettingsStore settings;
  final AssetBootstrap bootstrap;

  TunnelState state = TunnelState.disconnected;
  int socksPort = 0;
  int httpPort = 0;
  String connectedRegion = '';
  String routeIp = '';
  String routeSni = '';
  String routeProtocol = '';
  String routeOverrideId = '';
  String lastError = '';
  String statusHint = '';

  int bytesSent = 0;
  int bytesReceived = 0;
  double uploadBps = 0;
  double downloadBps = 0;
  DateTime? _lastByteSampleAt;
  int _lastSentSample = 0;
  int _lastRecvSample = 0;
  Timer? _rateTimer;

  final List<String> _activity = [];
  List<String> get shortActivity => List.unmodifiable(_activity);

  final List<String> availableRegions = [];

  final List<String> _log = [];
  List<String> get recentLog => List.unmodifiable(_log);

  final List<DialAttempt> _attempts = [];
  List<DialAttempt> get recentAttempts => List.unmodifiable(_attempts);

  /// Edges from settings that will be injected into dial overrides this session.
  List<String> get configuredEdgeIps => FrontingDialBuilder.parseIps(settings.customIps);

  bool get usingBuiltInDefaults =>
      settings.autoFindIpAndSni || settings.customIps.trim().isEmpty;

  String get uploadLabel => _formatRate(uploadBps);
  String get downloadLabel => _formatRate(downloadBps);

  Process? _process;
  StreamSubscription<String>? _outSub;
  StreamSubscription<String>? _errSub;
  bool _userWants = false;
  Timer? _establishTimer;
  Directory? _workDir;
  int _generation = 0;

  bool get isActive =>
      state == TunnelState.connected ||
      state == TunnelState.connecting ||
      state == TunnelState.disconnecting;

  void _note(String line) {
    statusHint = line;
    _activity.add(line);
    if (_activity.length > 8) _activity.removeAt(0);
  }

  static String _formatRate(double bps) {
    if (bps < 1024) return '${bps.toStringAsFixed(0)} B/s';
    if (bps < 1024 * 1024) return '${(bps / 1024).toStringAsFixed(1)} KB/s';
    return '${(bps / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }

  Future<void> start() async {
    if (!Platform.isWindows) {
      _append('Tunnel core is currently Windows-only in GuruProxy_v2.');
      state = TunnelState.error;
      notifyListeners();
      return;
    }

    _userWants = true;
    if (_process != null) return;

    final gen = ++_generation;
    state = TunnelState.connecting;
    lastError = '';
    connectedRegion = '';
    routeIp = '';
    routeSni = '';
    routeProtocol = '';
    routeOverrideId = '';
    socksPort = 0;
    httpPort = 0;
    bytesSent = 0;
    bytesReceived = 0;
    uploadBps = 0;
    downloadBps = 0;
    _lastByteSampleAt = null;
    _lastSentSample = 0;
    _lastRecvSample = 0;
    _attempts.clear();
    _activity.clear();
    _note('Starting tunnel…');
    notifyListeners();
    _append('Starting tunnel...');
    _rateTimer?.cancel();
    _rateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state != TunnelState.connected) {
        if (uploadBps != 0 || downloadBps != 0) {
          uploadBps = 0;
          downloadBps = 0;
          notifyListeners();
        }
        return;
      }
      uploadBps *= 0.55;
      downloadBps *= 0.55;
      if (uploadBps < 32) uploadBps = 0;
      if (downloadBps < 32) downloadBps = 0;
      notifyListeners();
    });

    try {
      await bootstrap.ensureReady();
      final exe = bootstrap.tunnelExe;
      if (exe == null || !await exe.exists()) {
        throw Exception('psiphon-tunnel-core.exe missing. Rebuild with assets/bin.');
      }

      final local = Platform.environment['LOCALAPPDATA'] ??
          '${Platform.environment['USERPROFILE']}\\AppData\\Local';
      _workDir = Directory('$local${Platform.pathSeparator}GuruProxy${Platform.pathSeparator}tunnel-core');
      await _workDir!.create(recursive: true);

      final socks = settings.localSocksPort;
      final http = settings.localHttpPort;
      if (socks == 8088 || http == 8089 || socks == 8089 || http == 8088) {
        _append('Ports $socks/$http collide with Se7en Pro defaults — switching to 17888/17889.');
        settings.localSocksPort = 17888;
        settings.localHttpPort = 17889;
      }
      _append('Local proxies: SOCKS=${settings.localSocksPort} HTTP=${settings.localHttpPort}');

      final configPath = File('${_workDir!.path}${Platform.pathSeparator}config.json');
      await configPath.writeAsString(_buildConfigJson());

      final serverList = bootstrap.serverEntries;
      final args = <String>['--config', configPath.path];
      if (serverList != null && await serverList.exists()) {
        final dest = File('${_workDir!.path}${Platform.pathSeparator}server_entries.txt');
        await serverList.copy(dest.path);
        args.addAll(['--serverList', dest.path]);
      }

      final cachedExe = File('${_workDir!.path}${Platform.pathSeparator}GuruProxy.Tunnel.exe');
      if (!await cachedExe.exists() || await cachedExe.length() != await exe.length()) {
        await exe.copy(cachedExe.path);
      }

      _process = await Process.start(
        cachedExe.path,
        args,
        workingDirectory: _workDir!.path,
        mode: ProcessStartMode.normal,
      );

      await _outSub?.cancel();
      await _errSub?.cancel();
      _outSub = _process!.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen(_onLine);
      _errSub = _process!.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen(_onLine);

      final timeoutSec = settings.establishTimeoutSec.clamp(30, 600);
      _establishTimer?.cancel();
      _establishTimer = Timer(Duration(seconds: timeoutSec), () {
        if (gen != _generation) return;
        if (state == TunnelState.connecting && _userWants) {
          _append(
            'Could not establish a tunnel in time. '
            'TLS-ok White IPs are not always Psiphon fronts (403). '
            'Try Iran Quick Connect or an Akamai group with Keep defaults.',
          );
          lastError = 'establish timeout';
          stop();
        }
      });

      _append('psiphon-tunnel-core started (pid ${_process!.pid})');
      unawaited(_process!.exitCode.then((code) {
        if (gen != _generation) return;
        _append('Tunnel exited ($code)');
        _process = null;
        if (_userWants) {
          state = TunnelState.connecting;
          _append('Auto-retrying in 5s...');
          notifyListeners();
          Future.delayed(const Duration(seconds: 5), () {
            if (gen != _generation) return;
            if (_userWants && _process == null) start();
          });
        } else {
          state = TunnelState.disconnected;
          notifyListeners();
        }
      }));
    } catch (e) {
      _append('Failed to start: $e');
      lastError = e.toString();
      state = TunnelState.error;
      _process = null;
      notifyListeners();
    }
  }

  Future<void> stop() async {
    _userWants = false;
    _generation++;
    _establishTimer?.cancel();
    _rateTimer?.cancel();
    uploadBps = 0;
    downloadBps = 0;
    final proc = _process;
    if (proc == null) {
      state = TunnelState.disconnected;
      _note('Disconnected');
      notifyListeners();
      return;
    }
    state = TunnelState.disconnecting;
    _note('Stopping…');
    _append('Stopping tunnel...');
    notifyListeners();
    await _outSub?.cancel();
    await _errSub?.cancel();
    _outSub = null;
    _errSub = null;
    try {
      proc.kill();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 250));
    try {
      proc.kill();
    } catch (_) {}
    _process = null;
    state = TunnelState.disconnected;
    _note('Disconnected');
    notifyListeners();
  }

  Future<void> toggle() async {
    if (state == TunnelState.connected ||
        state == TunnelState.connecting ||
        state == TunnelState.disconnecting) {
      await stop();
    } else {
      await start();
    }
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
  }

  void _append(String line) {
    final scrubbed = line
        .replaceAll(RegExp(r'PropagationChannelId":\s*"[^"]+"'), 'PropagationChannelId":"[redacted]"')
        .replaceAll(RegExp(r'SponsorId":\s*"[^"]+"'), 'SponsorId":"[redacted]"');
    final pretty = _prettyLogLine(scrubbed);
    if (pretty.trim().isEmpty) return;
    _log.add(pretty);
    if (_log.length > 4000) {
      _log.removeRange(0, _log.length - 4000);
    }
    notifyListeners();
  }

  String _prettyLogLine(String line) {
    try {
      final obj = jsonDecode(line) as Map<String, dynamic>;
      final type = obj['noticeType']?.toString() ?? '';
      final data = obj['data'];
      final rawTs = obj['timestamp']?.toString() ?? '';
      final ts = rawTs.length >= 19 ? rawTs.substring(11, 19) : rawTs;

      if (type == 'ConnectingServer' && data is Map) {
        final dial = data['meekDialAddress'] ?? data['dialAddress'] ?? '';
        final sni = data['meekSNIServerName'] ?? '';
        final proto = data['protocol'] ?? '';
        final region = data['region'] ?? '';
        final overrideId = data['meekFrontingDialOverrideID'] ?? '';
        return '── $ts  TRY  $dial'
            '${sni.toString().isNotEmpty ? "\n         SNI $sni" : ""}'
            '${overrideId.toString().isNotEmpty ? "\n         override $overrideId" : ""}'
            '\n         $proto · $region';
      }
      if (type == 'ConnectedServer' && data is Map) {
        final dial = data['meekDialAddress'] ?? '';
        final region = data['region'] ?? '';
        return '── $ts  REACH  $dial · $region';
      }
      if (type == 'Tunnels' && data is Map) {
        return '══ $ts  TUNNEL  count=${data['count']}';
      }
      if (type == 'ListeningSocksProxyPort' && data is Map) {
        return '·· $ts  SOCKS  :${data['port']}';
      }
      if (type == 'ListeningHttpProxyPort' && data is Map) {
        return '·· $ts  HTTP   :${data['port']}';
      }
      if (type == 'ConnectedServerRegion' && data is Map) {
        return '·· $ts  REGION ${data['region']}';
      }
      if (type == 'BytesTransferred') {
        return ''; // too noisy for log view
      }
      if ((type == 'Info' || type == 'Warning' || type == 'Error') && data is Map) {
        final msg = data['message']?.toString() ?? '';
        if (msg.isEmpty) return '· $ts  $type';
        if (msg.startsWith('Memory metrics') || msg.startsWith('Datastore metrics') || msg.startsWith('DNS metrics')) {
          return '';
        }
        final mark = type == 'Error'
            ? '!!'
            : type == 'Warning'
                ? '!!'
                : '·';
        return '$mark $ts  $msg';
      }
      if (type.isEmpty) return line;
      return '· $ts  $type';
    } catch (_) {
      if (line.startsWith('Starting tunnel') || line.startsWith('Stopping tunnel')) {
        return '\n════ $line ════';
      }
      return '· $line';
    }
  }

  void _onLine(String line) {
    if (line.trim().isEmpty) return;
    _append(line);
    try {
      final obj = jsonDecode(line) as Map<String, dynamic>;
      final type = obj['noticeType']?.toString();
      final data = obj['data'];
      if (type == null) return;
      switch (type) {
        case 'Tunnels':
          final count = data is Map ? data['count'] : null;
          if (count is num && count > 0) {
            state = TunnelState.connected;
            _establishTimer?.cancel();
            if (_attempts.isNotEmpty && _attempts.last.result == 'trying') {
              _attempts.last.result = 'ok';
            }
            _note(connectedRegion.isEmpty
                ? 'Connected — measuring best path'
                : 'Connected · $connectedRegion');
            notifyListeners();
          } else if (state == TunnelState.connected) {
            state = TunnelState.connecting;
            _note('Connection dropped — reconnecting…');
            notifyListeners();
          }
          break;
        case 'ListeningSocksProxyPort':
          if (data is Map && data['port'] is num) {
            socksPort = (data['port'] as num).toInt();
            _note('Local SOCKS ready · $socksPort');
            notifyListeners();
          }
          break;
        case 'ListeningHttpProxyPort':
          if (data is Map && data['port'] is num) {
            httpPort = (data['port'] as num).toInt();
            notifyListeners();
          }
          break;
        case 'ConnectedServerRegion':
          if (data is Map) {
            connectedRegion = data['region']?.toString() ?? '';
            if (state == TunnelState.connected && connectedRegion.isNotEmpty) {
              _note('Exit region · $connectedRegion');
            }
            notifyListeners();
          }
          break;
        case 'AvailableEgressRegions':
          if (data is Map && data['regions'] is List) {
            availableRegions
              ..clear()
              ..addAll((data['regions'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty));
            notifyListeners();
          }
          break;
        case 'BytesTransferred':
          if (data is Map) {
            final sent = data['sent'];
            final recv = data['received'];
            final now = DateTime.now();
            var changed = false;
            if (sent is num && sent > 0) {
              bytesSent += sent.toInt();
              changed = true;
            }
            if (recv is num && recv > 0) {
              bytesReceived += recv.toInt();
              changed = true;
            }
            if (changed) {
              if (_lastByteSampleAt != null) {
                final dt = now.difference(_lastByteSampleAt!).inMilliseconds / 1000.0;
                if (dt > 0.05) {
                  final dSent = bytesSent - _lastSentSample;
                  final dRecv = bytesReceived - _lastRecvSample;
                  if (dSent > 0) uploadBps = dSent / dt;
                  if (dRecv > 0) downloadBps = dRecv / dt;
                }
              }
              _lastByteSampleAt = now;
              _lastSentSample = bytesSent;
              _lastRecvSample = bytesReceived;
              notifyListeners();
            }
          }
          break;
        case 'ConnectingServer':
          if (data is Map) {
            final dial = data['meekDialAddress']?.toString() ??
                data['dialAddress']?.toString() ??
                '';
            final sni = data['meekSNIServerName']?.toString() ?? '';
            final overrideId = data['meekFrontingDialOverrideID']?.toString() ?? '';
            final protocol = data['protocol']?.toString() ?? '';
            final region = data['region']?.toString() ?? '';
            final ip = dial.contains(':') ? dial.split(':').first : dial;
            if (ip.isNotEmpty) routeIp = ip;
            if (sni.isNotEmpty) routeSni = sni;
            if (protocol.isNotEmpty) routeProtocol = protocol;
            if (overrideId.isNotEmpty) routeOverrideId = overrideId;

            if (_attempts.isNotEmpty && _attempts.last.result == 'trying') {
              _attempts.last.result = 'fail';
            }
            _attempts.add(DialAttempt(
              ip: ip.isEmpty ? dial : ip,
              sni: sni,
              protocol: protocol,
              overrideId: overrideId,
              at: DateTime.now(),
            ));
            if (_attempts.length > 12) {
              _attempts.removeRange(0, _attempts.length - 12);
            }
            final shortProto = protocol.replaceAll('FRONTED-MEEK-', '').replaceAll('-OSSH', '');
            _note([
              if (ip.isNotEmpty) 'Trying $ip',
              if (region.isNotEmpty) region,
              if (shortProto.isNotEmpty) shortProto,
            ].join(' · '));
            if (overrideId.isNotEmpty) {
              _append('Trying override $overrideId → $dial SNI=$sni');
            }
            notifyListeners();
          }
          break;
        case 'Warning':
        case 'Info':
          if (data is Map) {
            final msg = data['message']?.toString() ?? '';
            if (msg.contains('unexpected status code: 403') ||
                msg.contains('unexpected status code: 404')) {
              _note('Edge rejected — next candidate…');
              if (_attempts.isNotEmpty && _attempts.last.result == 'trying') {
                _attempts.last.result = 'fail';
              }
              notifyListeners();
            }
          }
          break;
        default:
          break;
      }
    } catch (_) {}
  }

  String _buildConfigJson() {
    final net = NetworkCredentials.resolve();
    if (!NetworkCredentials.hasUsableNetworkConfig()) {
      _append(
        'Network credentials missing. Run official Psiphon once, or place network_config.json in %LOCALAPPDATA%\\GuruProxy\\',
      );
    } else {
      _append('Network config source: ${net.source}');
    }

    final dataRoot = Directory('${_workDir!.path}${Platform.pathSeparator}data');
    dataRoot.createSync(recursive: true);

    final mode = settings.protocolMode;
    final socks = settings.localSocksPort;
    final http = settings.localHttpPort;

    final cfg = <String, dynamic>{
      'ClientPlatform': '${net.clientPlatform}_${Platform.operatingSystemVersion}',
      'ClientVersion': net.clientVersion,
      'PropagationChannelId': net.propagationChannelId,
      'SponsorId': net.sponsorId,
      'RemoteServerListURLs': jsonDecode(net.remoteServerListUrlsJson),
      'ObfuscatedServerListRootURLs': jsonDecode(net.obfuscatedServerListRootUrlsJson),
      'RemoteServerListSignaturePublicKey': net.remoteServerListSignaturePublicKey,
      'ServerEntrySignaturePublicKey': net.serverEntrySignaturePublicKey,
      'DataRootDirectory': dataRoot.path,
      'MigrateDataStoreDirectory': dataRoot.path,
      'UseIndistinguishableTLS': true,
      'EmitDiagnosticNotices': true,
      'EmitDiagnosticNetworkParameters': true,
      'EmitServerAlerts': true,
      'EmitBytesTransferred': true,
      'FeedbackUploadURLs': jsonDecode(net.feedbackUploadUrlsJson),
      'FeedbackEncryptionPublicKey': net.feedbackEncryptionPublicKey,
      'EnableFeedbackUpload': true,
      'EstablishTunnelTimeoutSeconds': settings.establishTimeoutSec,
      'LocalHttpProxyPort': http,
      'LocalSocksProxyPort': socks,
    };

    // Local listen mode — does NOT touch CDN dial overrides.
    final listen = settings.proxyListenMode;
    if (listen == 'socks') {
      cfg['DisableLocalHTTPProxy'] = true;
      cfg['DisableLocalSocksProxy'] = false;
      _append('Proxy listen: SOCKS only (:$socks)');
    } else if (listen == 'http') {
      cfg['DisableLocalSocksProxy'] = true;
      cfg['DisableLocalHTTPProxy'] = false;
      _append('Proxy listen: HTTP only (:$http)');
    } else {
      cfg['DisableLocalSocksProxy'] = false;
      cfg['DisableLocalHTTPProxy'] = false;
      _append('Proxy listen: mixed SOCKS :$socks + HTTP :$http');
    }

    // Stability profile — safe knobs only (no dial/protocol changes).
    if (settings.connectionProfile == 'stable') {
      // Longer network timeouts help on lossy IR links. Not BBR.
      cfg['NetworkLatencyMultiplier'] = 1.5;
      _append('Connection profile: stable (latency multiplier 1.5)');
      if (settings.redundantTunnel) {
        cfg['TunnelPoolSize'] = 2;
        _append('Redundant tunnel pool: 2');
      }
    } else {
      _append('Connection profile: normal');
    }

    // Match Se7en ClientPlatform style: Windows_<osVersion>
    final osVer = Platform.operatingSystemVersion;
    final m = RegExp(r'(\d+\.\d+)').firstMatch(osVer);
    cfg['ClientPlatform'] = 'Windows_${m?.group(1) ?? '10.0'}';

    final egress = EgressRegions.toConfigValue(settings.egressRegion);
    if (egress.isNotEmpty) {
      cfg['EgressRegion'] = egress;
      _append('Egress region: $egress');
      _note('Region preference · $egress');
    } else {
      _append('Egress region: Auto (fastest/stable available)');
      _note('Region · Auto (best available)');
    }

    if (settings.beastMode) {
      cfg['AggressiveEstablishment'] = true;
      _append('Beast mode: AggressiveEstablishment on');
    }

    final upstream = settings.buildUpstreamProxyUrl();
    if (mode.toLowerCase() == 'cdn_fronting') {
      _append('CDN Fronting: dialing CDN directly (system/upstream proxy ignored).');
      if (upstream.isNotEmpty) {
        _append('Note: upstream proxy is set but ignored in CDN Fronting mode.');
      }
    } else if (upstream.isNotEmpty) {
      cfg['UpstreamProxyUrl'] = upstream;
      _append('Using upstream proxy: ${upstream.replaceAll(RegExp(r':[^:@/]+@'), ':***@')}');
    }

    final protocols = settings.resolveTunnelProtocols();
    cfg['LimitTunnelProtocols'] = protocols;
    cfg['DisableTactics'] = true;
    _append(
      'Protocols (${settings.autoProtocol ? "auto" : "manual"}): ${protocols.join(", ")}',
    );

    if (mode == 'cdn_fronting') {
      // Dial overrides still follow Se7en-identical catch-all edges.

      // Se7en: when Auto, force US for CDN-dense exits.
      if (egress.isEmpty) {
        cfg['EgressRegion'] = 'US';
        _append('Egress region: US (CDN Auto → US, same as Se7en)');
        _note('Region · US (CDN)');
      }

      // Always enable aggressive establish for CDN (Se7en beast path).
      cfg['AggressiveEstablishment'] = true;
      if (!settings.beastMode) {
        _append('CDN: AggressiveEstablishment forced on (Se7en-compatible)');
      }

      final hasUserIps = settings.customIps.trim().isNotEmpty;
      // Always merge Se7en Akamai catch-alls unless user explicitly CF-only.
      final includeDefaults = settings.autoFindIpAndSni || !hasUserIps;
      final sniOverride = settings.sniOverrideEnabled ? settings.customSnis : '';
      // Default CDN provider for Se7en-compatible OSSH: still prefer CF list for
      // Cloudflare dials, but Akamai catch-alls always use Akamai SNI.
      final preferred = FrontingDialBuilder.normalizeProvider(
        settings.cdnProvider.trim().isEmpty ? 'cloudflare' : settings.cdnProvider,
      );

      _append('Dial overrides: Se7en-identical catch-all edges (.*)');
      _append('Active whitelist group: ${settings.activeGroupName.isEmpty ? "(custom/none)" : settings.activeGroupName}');
      _note('CDN · Se7en dials · ${settings.activeGroupName.isEmpty ? "-" : settings.activeGroupName}');
      if (settings.sniOverrideEnabled && settings.customSnis.trim().isNotEmpty) {
        _append('SNI override on');
      }
      if (hasUserIps && !includeDefaults) {
        _append('Custom IPs only (Auto-find off) — Se7en same rule.');
      } else if (hasUserIps) {
        _append('Custom IPs as catch-all .* + Se7en Akamai edges (same as working Se7en).');
      } else {
        _append('Built-in Se7en Akamai edges only.');
      }

      final overrides = FrontingDialBuilder.buildDialOverrides(
        customIpList: settings.customIps,
        customSni: sniOverride,
        includeBuiltInDefaults: includeDefaults,
        providerId: preferred,
      );
      cfg['FrontedMeekDialOverrides'] = overrides;
      cfg['FrontedMeekDialOverridesProbability'] = 1.0;
      final firstId = overrides.isEmpty ? '-' : overrides.first['OverrideID'];
      String? catchAllId;
      Object? catchAllDial;
      Object? catchAllSni;
      for (final o in overrides) {
        final m = o['MatchDialAddressRegexes'];
        if (m is List && m.contains('.*')) {
          catchAllId = o['OverrideID']?.toString();
          catchAllDial = o['DialAddresses'];
          catchAllSni = o['SNIServerName'];
          break;
        }
      }
      _append('Dial overrides: ${overrides.length} · first=$firstId');
      if (catchAllId != null) {
        _append('First catch-all: $catchAllId → $catchAllDial SNI=$catchAllSni');
      }
      if (hasUserIps) {
        final ips = FrontingDialBuilder.parseIps(settings.customIps).take(5).join(', ');
        _append('Whitelist IPs (catch-all): $ips');
      }
    } else if (mode == 'direct') {
      // LimitTunnelProtocols already set from checkbox/auto resolve above.
      _append('Direct/mixed mode — dial overrides not injected');
    }

    if (settings.blockedApps.isNotEmpty) {
      _append(
        'Exclude apps saved (${settings.blockedApps.length}): '
        '${settings.blockedApps.take(5).join(", ")}'
        '${settings.blockedApps.length > 5 ? "…" : ""}. '
        'SOCKS/HTTP cannot force process bypass (same as Se7en without TUN).',
      );
    }

    return const JsonEncoder.withIndent('  ').convert(cfg);
  }

  @override
  void dispose() {
    _generation++;
    _establishTimer?.cancel();
    _rateTimer?.cancel();
    _outSub?.cancel();
    _errSub?.cancel();
    _process?.kill();
    super.dispose();
  }
}
