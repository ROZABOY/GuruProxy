import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import '../../l10n/strings.dart';
import '../../services/diagnostics_export.dart';
import '../../theme/guru_theme.dart';

class LogPage extends StatelessWidget {
  const LogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = S(state.locale.languageCode == 'fa');
    final lines = state.tunnel.recentLog;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(s.menuLog, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: lines.isEmpty
                    ? null
                    : () async {
                        await DiagnosticsExport.shareSession(state.tunnel);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.diagnosticsShared)),
                          );
                        }
                      },
                child: Text(s.exportDiagnostics),
              ),
              TextButton(
                onPressed: lines.isEmpty
                    ? null
                    : () async {
                        // Copy oldest→newest (natural reading order).
                        final text = lines.join('\n');
                        await Clipboard.setData(ClipboardData(text: text));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(s.logCopied)),
                          );
                        }
                      },
                child: Text(s.copyLog),
              ),
              TextButton(
                onPressed: state.tunnel.clearLog,
                child: Text(s.clearLog),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: GuruTheme.panel,
                border: Border.all(color: GuruTheme.line),
              ),
              child: SelectionArea(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: lines.length,
                  itemBuilder: (context, i) {
                    final idx = lines.length - 1 - i;
                    final text = lines[idx];
                    final isDivider = text.contains('════') || text.startsWith('══');
                    final isTry = text.startsWith('──');
                    final isErr = text.startsWith('!!');
                    return Padding(
                      padding: EdgeInsets.only(bottom: isTry || isDivider ? 8 : 3, top: isDivider ? 6 : 0),
                      child: Text(
                        text,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: isDivider ? 11.5 : 11,
                          height: 1.35,
                          fontWeight: isDivider ? FontWeight.w700 : FontWeight.w400,
                          color: isErr
                              ? Colors.orangeAccent
                              : isDivider
                                  ? GuruTheme.sand
                                  : isTry
                                      ? const Color(0xFFE8F0F2)
                                      : const Color(0xFF9BB0B4),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
