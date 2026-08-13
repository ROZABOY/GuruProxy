import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Extracts bundled tunnel binary + server list into app support once.
class AssetBootstrap {
  Directory? _root;
  File? tunnelExe;
  File? serverEntries;

  Future<void> ensureReady() async {
    final support = await getApplicationSupportDirectory();
    _root = Directory('${support.path}${Platform.pathSeparator}GuruProxy');
    if (!await _root!.exists()) {
      await _root!.create(recursive: true);
    }

    tunnelExe = File('${_root!.path}${Platform.pathSeparator}psiphon-tunnel-core.exe');
    serverEntries = File('${_root!.path}${Platform.pathSeparator}server_entries.txt');

    if (Platform.isWindows) {
      await _copyAssetIfNeeded('assets/bin/psiphon-tunnel-core.exe', tunnelExe!);
    }
    await _copyAssetIfNeeded('assets/bin/server_entries.txt', serverEntries!);

    for (final name in [
      'akamai_ip_ranges.txt',
      'cloudflare_ip_ranges.txt',
      'fastly_ip_ranges.txt',
      'akamai_seed_ips.txt',
    ]) {
      final dest = File('${_root!.path}${Platform.pathSeparator}$name');
      await _copyAssetIfNeeded('assets/ranges/$name', dest);
    }
  }

  Directory get dataDir => _root!;

  Future<void> _copyAssetIfNeeded(String asset, File dest) async {
    try {
      final data = await rootBundle.load(asset);
      final bytes = data.buffer.asUint8List();
      if (await dest.exists() && await dest.length() == bytes.length) {
        return;
      }
      await dest.writeAsBytes(bytes, flush: true);
    } catch (_) {
      // Asset may be missing in some builds; tunnel start will report clearly.
    }
  }
}
