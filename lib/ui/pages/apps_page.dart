import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/strings.dart';
import '../../services/installed_apps_bridge.dart';
import '../../theme/guru_theme.dart';

class AppsPage extends StatefulWidget {
  const AppsPage({super.key});

  @override
  State<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends State<AppsPage> {
  List<InstalledAppInfo> _apps = const [];
  bool _loading = true;
  String _filter = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await InstalledAppsBridge.instance.listLaunchable();
      if (!mounted) return;
      setState(() {
        _apps = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.locale.languageCode == 'fa');
    final settings = state.settings;
    final selected = settings.vpnAppPackages.toSet();
    final q = _filter.trim().toLowerCase();
    final filtered = _apps.where((a) {
      if (q.isEmpty) return true;
      return a.label.toLowerCase().contains(q) || a.packageName.toLowerCase().contains(q);
    }).toList();

    final isAndroid = !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(s.vpnAppsTitle, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            isAndroid ? s.vpnAppsHintAndroid : s.vpnAppsHintDesktop,
            style: const TextStyle(fontSize: 12, color: Color(0xFF8FA3A7)),
          ),
          const SizedBox(height: 10),
          if (isAndroid) ...[
            DropdownButtonFormField<String>(
              initialValue: settings.vpnAppMode,
              decoration: InputDecoration(
                labelText: s.vpnAppMode,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                DropdownMenuItem(value: 'all', child: Text(s.vpnModeAll)),
                DropdownMenuItem(value: 'exclude', child: Text(s.vpnModeExclude)),
                DropdownMenuItem(value: 'include', child: Text(s.vpnModeInclude)),
              ],
              onChanged: (v) {
                if (v != null) settings.vpnAppMode = v;
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: InputDecoration(
                labelText: s.searchApps,
                border: const OutlineInputBorder(),
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 18),
              ),
              onChanged: (v) => setState(() => _filter = v),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(child: Center(child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))))
            else
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: GuruTheme.panel,
                    border: Border.all(color: GuruTheme.line),
                  ),
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final app = filtered[i];
                      final on = selected.contains(app.packageName);
                      final enableChecks = settings.vpnAppMode != 'all';
                      return CheckboxListTile(
                        dense: true,
                        value: on,
                        onChanged: enableChecks
                            ? (v) {
                                final next = selected.toList();
                                if (v == true) {
                                  next.add(app.packageName);
                                } else {
                                  next.remove(app.packageName);
                                }
                                settings.vpnAppPackages = next;
                              }
                            : null,
                        title: Text(app.label, style: const TextStyle(fontSize: 13)),
                        subtitle: Text(
                          app.packageName,
                          style: const TextStyle(fontSize: 10, color: Color(0xFF8FA3A7)),
                        ),
                      );
                    },
                  ),
                ),
              ),
          ] else ...[
            Expanded(
              child: TextField(
                controller: TextEditingController(text: settings.blockedApps.join('\n')),
                maxLines: null,
                expands: true,
                decoration: InputDecoration(
                  labelText: s.blockedAppsList,
                  alignLabelWithHint: true,
                  border: const OutlineInputBorder(),
                ),
                onChanged: (v) {
                  settings.blockedApps = v
                      .split(RegExp(r'\r?\n'))
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
