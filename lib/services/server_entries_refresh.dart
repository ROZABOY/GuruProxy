import 'dart:io';

import 'asset_bootstrap.dart';
import 'network_credentials.dart';

/// Refresh bundled server list + clear stale tunnel-core datastore entries.
class ServerEntriesRefresh {
  ServerEntriesRefresh._();

  static Future<String> refresh(AssetBootstrap bootstrap) async {
    await bootstrap.ensureReady();
    final bundled = bootstrap.serverEntries;
    if (bundled == null || !await bundled.exists()) {
      return 'Bundled server_entries.txt missing — rebuild with assets/bin.';
    }

    final root = await NetworkCredentials.dataRoot();
    final tunnel = Directory('${root.path}${Platform.pathSeparator}tunnel-core');
    await tunnel.create(recursive: true);
    final dest = File('${tunnel.path}${Platform.pathSeparator}server_entries.txt');
    await bundled.copy(dest.path);

    // Clear datastore so next Start reloads entries (and remote list).
    final data = Directory('${tunnel.path}${Platform.pathSeparator}data');
    if (await data.exists()) {
      try {
        await data.delete(recursive: true);
      } catch (_) {}
    }
    await data.create(recursive: true);

    final bytes = await dest.length();
    return 'Server list refreshed ($bytes bytes). Datastore cleared for next connect.';
  }
}
