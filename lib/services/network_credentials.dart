import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class NetworkSnapshot {
  const NetworkSnapshot({
    required this.propagationChannelId,
    required this.sponsorId,
    required this.clientVersion,
    required this.clientPlatform,
    required this.remoteServerListSignaturePublicKey,
    required this.serverEntrySignaturePublicKey,
    required this.feedbackEncryptionPublicKey,
    required this.remoteServerListUrlsJson,
    required this.obfuscatedServerListRootUrlsJson,
    required this.feedbackUploadUrlsJson,
    required this.source,
  });

  final String propagationChannelId;
  final String sponsorId;
  final String clientVersion;
  final String clientPlatform;
  final String remoteServerListSignaturePublicKey;
  final String serverEntrySignaturePublicKey;
  final String feedbackEncryptionPublicKey;
  final String remoteServerListUrlsJson;
  final String obfuscatedServerListRootUrlsJson;
  final String feedbackUploadUrlsJson;
  final String source;
}

class NetworkCredentials {
  static NetworkSnapshot? _cached;

  static String get appDataConfigPath {
    final local = Platform.environment['LOCALAPPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Local';
    return '$local${Platform.pathSeparator}GuruProxy${Platform.pathSeparator}network_config.json';
  }

  static String get tunnelCoreConfigPath {
    final local = Platform.environment['LOCALAPPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Local';
    return '$local${Platform.pathSeparator}Psiphon${Platform.pathSeparator}tunnel-core${Platform.pathSeparator}config.json';
  }

  static String get legacyUiConfigPath {
    final local = Platform.environment['LOCALAPPDATA'] ??
        '${Platform.environment['USERPROFILE']}\\AppData\\Local';
    return '$local${Platform.pathSeparator}PsiphonUI${Platform.pathSeparator}network_config.json';
  }

  static bool isPlaceholder(String? value) {
    if (value == null || value.trim().isEmpty) return true;
    final v = value.trim();
    return v.contains('PROPAGATION_CHANNEL_ID') ||
        v.contains('SPONSOR_ID') ||
        v.contains('REMOTE_SERVER_LIST_') ||
        v.contains('SERVER_ENTRY_SIGNATURE_') ||
        v.contains('FEEDBACK_') ||
        v.contains('OBFUSCATED_SERVER_LIST_') ||
        v == '0' ||
        v == '0000000000000000';
  }

  static NetworkSnapshot resolve({bool forceReload = false}) {
    if (!forceReload && _cached != null) return _cached!;

    for (final entry in [
      (appDataConfigPath, 'GuruProxy network_config.json'),
      (legacyUiConfigPath, 'legacy PsiphonUI network_config.json'),
      (tunnelCoreConfigPath, 'existing tunnel-core config.json'),
    ]) {
      final snap = _tryFromJsonFile(entry.$1, entry.$2);
      if (snap != null) {
        if (entry.$1 != appDataConfigPath) {
          _tryPersist(snap);
        }
        _cached = snap;
        return snap;
      }
    }

    _cached = _placeholders();
    return _cached!;
  }

  static bool hasUsableNetworkConfig() {
    final s = resolve();
    return !isPlaceholder(s.propagationChannelId) &&
        !isPlaceholder(s.sponsorId) &&
        !isPlaceholder(s.remoteServerListSignaturePublicKey) &&
        !isPlaceholder(s.remoteServerListUrlsJson);
  }

  static NetworkSnapshot _placeholders() => const NetworkSnapshot(
        propagationChannelId: 'PROPAGATION_CHANNEL_ID',
        sponsorId: 'SPONSOR_ID',
        clientVersion: '1',
        clientPlatform: 'Windows',
        remoteServerListSignaturePublicKey: 'REMOTE_SERVER_LIST_SIGNATURE_PUBLIC_KEY',
        serverEntrySignaturePublicKey: 'SERVER_ENTRY_SIGNATURE_PUBLIC_KEY',
        feedbackEncryptionPublicKey: 'FEEDBACK_ENCRYPTION_PUBLIC_KEY',
        remoteServerListUrlsJson: '[]',
        obfuscatedServerListRootUrlsJson: '[]',
        feedbackUploadUrlsJson: '[]',
        source: 'placeholders',
      );

  static NetworkSnapshot? _tryFromJsonFile(String path, String sourceLabel) {
    try {
      final file = File(path);
      if (!file.existsSync()) return null;
      final root = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      final channel = _str(root, 'PropagationChannelId');
      final sponsor = _str(root, 'SponsorId');
      final remoteKey = _str(root, 'RemoteServerListSignaturePublicKey');
      if (isPlaceholder(channel) || isPlaceholder(sponsor) || isPlaceholder(remoteKey)) {
        return null;
      }
      final remoteUrls = _jsonArrayOrString(root, 'RemoteServerListURLs', 'RemoteServerListUrlsJson');
      final osl = _jsonArrayOrString(root, 'ObfuscatedServerListRootURLs', 'ObfuscatedServerListRootUrlsJson');
      final feedback = _jsonArrayOrString(root, 'FeedbackUploadURLs', 'FeedbackUploadUrlsJson');
      if (isPlaceholder(remoteUrls)) return null;

      return NetworkSnapshot(
        propagationChannelId: channel!,
        sponsorId: sponsor!,
        clientVersion: _str(root, 'ClientVersion') ?? '1',
        clientPlatform: _str(root, 'ClientPlatform') ?? 'Windows',
        remoteServerListSignaturePublicKey: remoteKey!,
        serverEntrySignaturePublicKey:
            _str(root, 'ServerEntrySignaturePublicKey') ?? 'SERVER_ENTRY_SIGNATURE_PUBLIC_KEY',
        feedbackEncryptionPublicKey:
            _str(root, 'FeedbackEncryptionPublicKey') ?? 'FEEDBACK_ENCRYPTION_PUBLIC_KEY',
        remoteServerListUrlsJson: remoteUrls!,
        obfuscatedServerListRootUrlsJson: osl ?? '[]',
        feedbackUploadUrlsJson: feedback ?? '[]',
        source: sourceLabel,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _tryPersist(NetworkSnapshot s) async {
    try {
      final path = appDataConfigPath;
      final file = File(path);
      if (await file.exists()) return;
      await file.parent.create(recursive: true);
      final obj = {
        'PropagationChannelId': s.propagationChannelId,
        'SponsorId': s.sponsorId,
        'ClientVersion': s.clientVersion,
        'ClientPlatform': 'Windows',
        'RemoteServerListSignaturePublicKey': s.remoteServerListSignaturePublicKey,
        'ServerEntrySignaturePublicKey': s.serverEntrySignaturePublicKey,
        'FeedbackEncryptionPublicKey': s.feedbackEncryptionPublicKey,
        'RemoteServerListURLs': jsonDecode(s.remoteServerListUrlsJson),
        'ObfuscatedServerListRootURLs': jsonDecode(s.obfuscatedServerListRootUrlsJson),
        'FeedbackUploadURLs': jsonDecode(s.feedbackUploadUrlsJson),
      };
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(obj));
    } catch (_) {}
  }

  static String? _str(Map<String, dynamic> root, String name) {
    final v = root[name];
    if (v == null) return null;
    return v.toString();
  }

  static String? _jsonArrayOrString(
    Map<String, dynamic> root,
    String arrayName,
    String altStringName,
  ) {
    final arr = root[arrayName];
    if (arr is List) return jsonEncode(arr);
    final s = root[altStringName];
    if (s is String) return s;
    return null;
  }

  static Future<Directory> dataRoot() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}${Platform.pathSeparator}GuruProxy');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }
}
